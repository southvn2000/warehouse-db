#!/usr/bin/env python3
"""Local RAG for SQL repository using SQLite FTS5.

This script builds and queries a full-text index over SQL objects in this repo.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import mimetypes
import os
import re
import sqlite3
import threading
import time
import urllib.error
import urllib.request
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Iterable, List, Sequence
from urllib.parse import parse_qs, urlparse


REPO_ROOT = Path(__file__).resolve().parents[1]
INDEX_DIR = REPO_ROOT / ".rag"
INDEX_DB = INDEX_DIR / "sql_index.db"
WEB_DIR = Path(__file__).resolve().parent / "web"

SESSION_LOCK = threading.Lock()
SESSION_MEMORY: dict[str, List[dict]] = {}
SESSION_LLM_CONFIG: dict[str, dict] = {}
SESSION_MAX_TURNS = 20

SCAN_DIRS = [
    "Functions",
    "StoreProcedures",
    "LogStoreProcedures",
    "Tables",
    "LogTables",
    "Types",
]


@dataclass
class SqlDoc:
    path: str
    object_name: str
    object_type: str
    content: str
    content_hash: str
    updated_at: str


def discover_sql_files(root: Path) -> Iterable[Path]:
    for rel in SCAN_DIRS:
        base = root / rel
        if not base.exists():
            continue
        for p in base.rglob("*.sql"):
            if p.is_file():
                yield p


def infer_object_name(file_path: Path) -> str:
    name = file_path.name
    parts = name.split(".")
    if len(parts) >= 2:
        return ".".join(parts[:2])
    return file_path.stem


def infer_object_type(file_path: Path) -> str:
    n = file_path.name.lower()
    if ".storedprocedure." in n:
        return "stored_procedure"
    if ".table." in n:
        return "table"
    if ".userdefinedfunction." in n:
        return "function"
    if ".userdefinedtabletype." in n:
        return "type"
    parent = file_path.parent.name.lower()
    if "procedure" in parent:
        return "stored_procedure"
    if "table" in parent:
        return "table"
    if "function" in parent:
        return "function"
    if "type" in parent:
        return "type"
    return "sql_object"


def read_sql_text(file_path: Path) -> str:
    raw = file_path.read_bytes()

    # Most SQL Server scripted objects here are UTF-16 LE with BOM.
    if raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"):
        return raw.decode("utf-16")

    if raw.startswith(b"\xef\xbb\xbf"):
        return raw.decode("utf-8-sig")

    for enc in ("utf-8", "utf-16", "cp1252"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue

    return raw.decode("utf-8", errors="replace")


def to_doc(file_path: Path) -> SqlDoc:
    content = read_sql_text(file_path)
    rel_path = file_path.relative_to(REPO_ROOT).as_posix()
    digest = hashlib.sha256(content.encode("utf-8")).hexdigest()
    updated = datetime.fromtimestamp(file_path.stat().st_mtime, tz=timezone.utc).isoformat()
    return SqlDoc(
        path=rel_path,
        object_name=infer_object_name(file_path),
        object_type=infer_object_type(file_path),
        content=content,
        content_hash=digest,
        updated_at=updated,
    )


def open_db(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn


def init_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        PRAGMA journal_mode=WAL;

        DROP TABLE IF EXISTS documents;
        DROP TABLE IF EXISTS docs_fts;

        CREATE TABLE documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT NOT NULL UNIQUE,
            object_name TEXT NOT NULL,
            object_type TEXT NOT NULL,
            content TEXT NOT NULL,
            content_hash TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );

        CREATE VIRTUAL TABLE docs_fts USING fts5(
            object_name,
            object_type,
            path,
            content,
            tokenize = 'porter unicode61'
        );
        """
    )


def build_index() -> None:
    docs = [to_doc(p) for p in discover_sql_files(REPO_ROOT)]
    conn = open_db(INDEX_DB)
    try:
        init_schema(conn)
        conn.executemany(
            """
            INSERT INTO documents(path, object_name, object_type, content, content_hash, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            [
                (d.path, d.object_name, d.object_type, d.content, d.content_hash, d.updated_at)
                for d in docs
            ],
        )

        conn.execute(
            """
            INSERT INTO docs_fts(rowid, object_name, object_type, path, content)
            SELECT id, object_name, object_type, path, content
            FROM documents
            """
        )
        conn.commit()
    finally:
        conn.close()

    print(f"Indexed {len(docs)} SQL files into {INDEX_DB}")


def normalize_query(user_query: str) -> str:
    tokens = re.findall(r"[A-Za-z0-9_]+", user_query)
    if not tokens:
        return ""
    # Prefix matching helps with SQL object-name style queries.
    return " OR ".join(f"{t}*" for t in tokens)


def is_object_lookup_query(user_query: str) -> bool:
    # Heuristic: direct object-name lookups like dbo.OrderPackingResultType.
    q = user_query.strip()
    if not q or len(q) > 120:
        return False
    return bool(re.fullmatch(r"[A-Za-z0-9_\.\[\]]+", q))


def query_exact_object(conn: sqlite3.Connection, user_query: str, top_k: int) -> Sequence[sqlite3.Row]:
    normalized = user_query.strip().lower().replace("[", "").replace("]", "")
    like_q = f"%{normalized}%"
    return conn.execute(
        """
        SELECT
            path,
            object_name,
            object_type,
            -1000.0 AS score,
            substr(replace(content, char(10), ' '), 1, 240) AS snippet,
            content
        FROM documents
        WHERE lower(replace(replace(object_name, '[', ''), ']', '')) LIKE ?
        ORDER BY CASE
            WHEN lower(replace(replace(object_name, '[', ''), ']', '')) = ? THEN 0
            ELSE 1
        END, object_name
        LIMIT ?
        """,
        (like_q, normalized, top_k),
    ).fetchall()


def query_index(user_query: str, top_k: int) -> Sequence[sqlite3.Row]:
    conn = open_db(INDEX_DB)
    try:
        if is_object_lookup_query(user_query):
            exact_rows = query_exact_object(conn, user_query, top_k)
            if exact_rows:
                return exact_rows

        fts_query = normalize_query(user_query)
        if not fts_query:
            return []

        rows = conn.execute(
            """
            SELECT
                d.path,
                d.object_name,
                d.object_type,
                bm25(docs_fts, 3.0, 1.0, 0.5, 1.5) AS score,
                snippet(docs_fts, 3, '[', ']', ' ... ', 24) AS snippet,
                d.content
            FROM docs_fts
            JOIN documents d ON d.id = docs_fts.rowid
            WHERE docs_fts MATCH ?
            ORDER BY score
            LIMIT ?
            """,
            (fts_query, top_k),
        ).fetchall()

        if rows:
            return rows

        # Fallback for unusual punctuation-heavy queries.
        like_q = f"%{user_query}%"
        return conn.execute(
            """
            SELECT
                path,
                object_name,
                object_type,
                9999.0 AS score,
                substr(replace(content, char(10), ' '), 1, 240) AS snippet,
                content
            FROM documents
            WHERE content LIKE ? OR object_name LIKE ?
            LIMIT ?
            """,
            (like_q, like_q, top_k),
        ).fetchall()
    finally:
        conn.close()


def render_results(rows: Sequence[sqlite3.Row]) -> str:
    if not rows:
        return "No matches found. Try a broader query or rebuild the index."

    lines: List[str] = []
    for i, r in enumerate(rows, start=1):
        lines.append(f"{i}. {r['object_name']} ({r['object_type']})")
        lines.append(f"   path: {r['path']}")
        lines.append(f"   score: {r['score']:.4f}")
        lines.append(f"   snippet: {r['snippet']}")
    return "\n".join(lines)


def rows_to_payload(rows: Sequence[sqlite3.Row]) -> List[dict]:
    payload: List[dict] = []
    for r in rows:
        payload.append(
            {
                "path": r["path"],
                "object_name": r["object_name"],
                "object_type": r["object_type"],
                "score": float(r["score"]),
                "snippet": r["snippet"],
            }
        )
    return payload


def get_or_create_session(session_id: str | None) -> str:
    sid = (session_id or "").strip() or str(uuid.uuid4())
    with SESSION_LOCK:
        SESSION_MEMORY.setdefault(sid, [])
    return sid


def append_session_message(session_id: str, role: str, content: str) -> None:
    with SESSION_LOCK:
        history = SESSION_MEMORY.setdefault(session_id, [])
        history.append(
            {
                "role": role,
                "content": content,
                "ts": datetime.now(timezone.utc).isoformat(),
            }
        )
        # Keep only the latest bounded number of messages.
        SESSION_MEMORY[session_id] = history[-SESSION_MAX_TURNS:]


def get_session_history(session_id: str, max_items: int = 8) -> List[dict]:
    with SESSION_LOCK:
        return list(SESSION_MEMORY.get(session_id, []))[-max_items:]


def clear_session(session_id: str) -> None:
    with SESSION_LOCK:
        SESSION_MEMORY[session_id] = []
        SESSION_LLM_CONFIG.pop(session_id, None)


def sanitize_llm_config(cfg: dict | None) -> dict:
    if not isinstance(cfg, dict):
        return {}
    return {
        "enabled": bool(cfg.get("enabled", False)),
        "provider": str(cfg.get("provider", "custom"))[:40],
        "base_url": str(cfg.get("base_url", "")).strip(),
        "api_key": str(cfg.get("api_key", "")).strip(),
        "model": str(cfg.get("model", "")).strip(),
        "timeout_seconds": int(cfg.get("timeout_seconds", 45) or 45),
    }


def set_session_llm_config(session_id: str, cfg: dict | None) -> None:
    normalized = sanitize_llm_config(cfg)
    with SESSION_LOCK:
        SESSION_LLM_CONFIG[session_id] = normalized


def get_session_llm_config(session_id: str) -> dict:
    with SESSION_LOCK:
        return dict(SESSION_LLM_CONFIG.get(session_id, {}))


def llm_presets() -> List[dict]:
    return [
        {
            "id": "copilot",
            "label": "Copilot (GitHub Models)",
            "base_url": "https://models.inference.ai.azure.com/v1",
            "model": "gpt-4o-mini",
            "timeout_seconds": 45,
            "requires_api_key": True,
            "api_key_hint": "Use a GitHub token with Models access.",
        },
        {
            "id": "ollama",
            "label": "Ollama (local)",
            "base_url": "http://127.0.0.1:11434/v1",
            "model": "llama3:latest",
            "timeout_seconds": 120,
            "requires_api_key": False,
            "api_key_hint": "Usually empty for local Ollama.",
        },
    ]


def strip_snippet_markup(text: str) -> str:
    # Remove snippet markers and collapse whitespace for clean answers.
    cleaned = text.replace("[", "").replace("]", "").replace("...", " ")
    return " ".join(cleaned.split())


def extract_sql_excerpt(sql_content: str, user_query: str, max_chars: int = 1800) -> str:
    lines = sql_content.splitlines()
    if not lines:
        return ""

    tokens = [t.lower() for t in re.findall(r"[A-Za-z0-9_]+", user_query) if len(t) >= 3]

    hit_indexes: List[int] = []
    if tokens:
        for idx, line in enumerate(lines):
            ll = line.lower()
            if any(t in ll for t in tokens):
                hit_indexes.append(idx)

    selected: List[int] = []
    if hit_indexes:
        for center in hit_indexes[:3]:
            start = max(0, center - 6)
            end = min(len(lines), center + 7)
            selected.extend(range(start, end))
    else:
        selected.extend(range(0, min(len(lines), 40)))

    deduped: List[int] = []
    seen: set[int] = set()
    for i in selected:
        if i not in seen:
            seen.add(i)
            deduped.append(i)

    excerpt_lines = [lines[i] for i in deduped]
    excerpt = "\n".join(excerpt_lines).strip()
    if len(excerpt) > max_chars:
        return excerpt[: max_chars - 32].rstrip() + "\n... [truncated]"
    return excerpt


def parse_procedure_parameters(sql_content: str) -> List[str]:
    lines = sql_content.splitlines()
    params: List[str] = []
    for line in lines:
        stripped = line.strip()
        if re.match(r"^(AS|BEGIN)\b", stripped, flags=re.IGNORECASE):
            break
        if "@" not in stripped:
            continue
        m = re.search(
            r"(@[A-Za-z0-9_]+)\s+([A-Za-z0-9_\[\]]+(?:\([0-9,\s]+\))?)(?:\s*=\s*([^,\n]+))?",
            stripped,
            flags=re.IGNORECASE,
        )
        if not m:
            continue
        name = m.group(1)
        data_type = m.group(2)
        default = (m.group(3) or "").strip()
        if default:
            params.append(f"{name} {data_type} (default {default})")
        else:
            params.append(f"{name} {data_type}")
    return params


def parse_procedure_steps(sql_content: str, max_steps: int = 10) -> List[str]:
    steps: List[str] = []
    for raw_line in sql_content.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("--"):
            continue
        if re.match(
            r"^(IF|ELSE\s+IF|BEGIN\s+TRAN|COMMIT|ROLLBACK|INSERT\s+INTO|UPDATE\s+|DELETE\s+FROM|MERGE\s+|SELECT\s+|EXEC\s+|RETURN\b|THROW\b|RAISERROR\b)",
            line,
            flags=re.IGNORECASE,
        ):
            normalized = re.sub(r"\s+", " ", line)
            steps.append(normalized[:160])
        if len(steps) >= max_steps:
            break
    return steps


def is_deep_explain_query(user_query: str) -> bool:
    q = user_query.lower()
    explain_terms = (
        "explain",
        "logic",
        "flow",
        "walkthrough",
        "step by step",
        "how does",
        "what does",
    )
    object_terms = (
        "store procedure",
        "stored procedure",
        "sp_",
        "dbo.",
        "procedure",
    )
    return any(t in q for t in explain_terms) and any(t in q for t in object_terms)


def summarize_purpose(sql_content: str) -> str | None:
    for line in sql_content.splitlines()[:80]:
        m = re.search(r"description\s*:\s*<?([^>]+)>?", line, flags=re.IGNORECASE)
        if m:
            text = " ".join(m.group(1).split())
            if text:
                return text
    return None


def extract_called_objects(sql_content: str, max_items: int = 10) -> List[str]:
    names: List[str] = []
    seen: set[str] = set()
    skip_words = {"as", "the", "for", "to", "on", "off", "with", "at", "by"}
    pattern = re.compile(
        r"\bEXEC(?:UTE)?\s+([A-Za-z0-9_\[\]\.]+)",
        flags=re.IGNORECASE,
    )
    for line in sql_content.splitlines():
        m = pattern.search(line)
        if not m:
            continue
        obj = m.group(1).strip()
        if obj.startswith("@"):  # Dynamic exec variable, not object name.
            continue
        normalized = obj.replace("[", "").replace("]", "")
        if normalized.lower() in skip_words:
            continue
        # Keep likely object names only.
        if "." not in normalized and not normalized.lower().startswith(("sp_", "usp_", "fn_")):
            continue
        key = normalized.lower()
        if key in seen:
            continue
        seen.add(key)
        names.append(normalized)
        if len(names) >= max_items:
            break
    return names


def extract_table_mutations(sql_content: str, max_items: int = 12) -> List[str]:
    mutations: List[str] = []
    seen: set[str] = set()
    patterns = [
        re.compile(r"\bINSERT\s+INTO\s+([A-Za-z0-9_\[\]\.]+)", flags=re.IGNORECASE),
        re.compile(r"\bUPDATE\s+([A-Za-z0-9_\[\]\.]+)", flags=re.IGNORECASE),
        re.compile(r"\bDELETE\s+FROM\s+([A-Za-z0-9_\[\]\.]+)", flags=re.IGNORECASE),
        re.compile(r"\bMERGE\s+([A-Za-z0-9_\[\]\.]+)", flags=re.IGNORECASE),
    ]

    for line in sql_content.splitlines():
        for pat in patterns:
            m = pat.search(line)
            if not m:
                continue
            table_name = m.group(1).replace("[", "").replace("]", "")
            key = table_name.lower()
            if key in seen:
                continue
            seen.add(key)
            mutations.append(table_name)
            if len(mutations) >= max_items:
                return mutations
    return mutations


def build_deep_procedure_explain(user_query: str, primary: sqlite3.Row, related_rows: Sequence[sqlite3.Row]) -> str:
    content = primary["content"]
    purpose = summarize_purpose(content)
    params = parse_procedure_parameters(content)
    steps = parse_procedure_steps(content, max_steps=16)
    writes = extract_table_mutations(content, max_items=16)
    calls = extract_called_objects(content, max_items=12)
    excerpt = extract_sql_excerpt(content, user_query, max_chars=2200)

    lines: List[str] = []
    lines.append(f"Procedure: {primary['object_name']}")
    lines.append(f"Source: {primary['path']}")
    lines.append("")

    lines.append("Purpose:")
    if purpose:
        lines.append(purpose)
    else:
        lines.append("No explicit description comment found. Inferred from SQL statements below.")
    lines.append("")

    lines.append("Inputs:")
    if params:
        for p in params[:30]:
            lines.append(f"- {p}")
    else:
        lines.append("- No clear parameters parsed.")
    lines.append("")

    lines.append("Control Flow:")
    if steps:
        for i, step in enumerate(steps, start=1):
            lines.append(f"{i}. {step}")
    else:
        lines.append("1. Could not infer flow from keyword patterns; inspect full SQL body in source.")
    lines.append("")

    lines.append("Data Changes:")
    if writes:
        for table_name in writes:
            lines.append(f"- Writes to: {table_name}")
    else:
        lines.append("- No obvious INSERT/UPDATE/DELETE/MERGE target detected.")
    lines.append("")

    lines.append("Dependencies:")
    if calls:
        for call in calls:
            lines.append(f"- Calls: {call}")
    else:
        lines.append("- No explicit EXEC target detected.")
    lines.append("")

    if related_rows:
        lines.append("Related Objects:")
        for r in related_rows[:3]:
            if r["path"] == primary["path"]:
                continue
            lines.append(f"- {r['object_name']} ({r['object_type']}) in {r['path']}")
        lines.append("")

    if excerpt:
        lines.append("Key SQL Excerpt:")
        lines.append(excerpt)
        lines.append("")

    lines.append("Open the source path for exact branches, dynamic SQL details, and edge-case handling.")
    return "\n".join(lines)


def parse_type_columns(sql_content: str) -> List[str]:
    columns: List[str] = []
    for line in sql_content.splitlines():
        m = re.search(
            r"\[([^\]]+)\]\s+\[([^\]]+)\](?:\(([^\)]+)\))?\s+(NULL|NOT NULL)",
            line,
            flags=re.IGNORECASE,
        )
        if not m:
            continue
        col_name = m.group(1)
        sql_type = m.group(2)
        sql_len = m.group(3)
        nullability = m.group(4).upper()
        type_part = f"{sql_type}({sql_len})" if sql_len else sql_type
        columns.append(f"{col_name}: {type_part} {nullability}")
    return columns


def get_llm_config(override: dict | None = None) -> dict | None:
    ov = sanitize_llm_config(override)
    if ov.get("enabled"):
        base_url = ov.get("base_url") or os.environ.get("RAG_LLM_BASE_URL", "")
        model = ov.get("model") or os.environ.get("RAG_LLM_MODEL", "gpt-4o-mini")
        api_key = ov.get("api_key") or os.environ.get("RAG_LLM_API_KEY") or os.environ.get("OPENAI_API_KEY", "")
        if base_url and model:
            return {
                "base_url": base_url,
                "api_key": api_key,
                "model": model,
                "timeout_seconds": int(ov.get("timeout_seconds") or os.environ.get("RAG_LLM_TIMEOUT", "45")),
            }

    api_key = os.environ.get("RAG_LLM_API_KEY") or os.environ.get("OPENAI_API_KEY")
    if not api_key:
        return None

    return {
        "base_url": os.environ.get("RAG_LLM_BASE_URL", "https://api.openai.com/v1"),
        "api_key": api_key,
        "model": os.environ.get("RAG_LLM_MODEL", "gpt-4o-mini"),
        "timeout_seconds": int(os.environ.get("RAG_LLM_TIMEOUT", "45")),
    }


def build_grounded_messages(
    user_query: str,
    rows: Sequence[sqlite3.Row],
    history: Sequence[dict],
    force_deep_explain: bool = False,
) -> List[dict]:
    context_lines: List[str] = []
    for idx, r in enumerate(rows[:6], start=1):
        context_lines.append(f"[{idx}] {r['object_name']} ({r['object_type']})")
        context_lines.append(f"Path: {r['path']}")
        context_lines.append(f"Snippet: {strip_snippet_markup(r['snippet'])}")
        excerpt = extract_sql_excerpt(r["content"], user_query, max_chars=1400)
        if excerpt:
            context_lines.append("SQL excerpt:")
            context_lines.append(excerpt)
        if r["object_type"] == "stored_procedure":
            params = parse_procedure_parameters(r["content"])
            if params:
                context_lines.append("Parameters:")
                for p in params[:20]:
                    context_lines.append(f"- {p}")
        context_lines.append("")

    context_blob = "\n".join(context_lines)
    prompt_messages: List[dict] = [
        {
            "role": "system",
            "content": (
                "You are a SQL codebase assistant. Answer only from provided sources. "
                "If unsure, say what is missing. Cite source object names in plain text. "
                "When user asks to explain logic, provide detailed step-by-step flow, key conditions, data changes, and outputs."
            ),
        },
        {
            "role": "system",
            "content": f"Retrieved SQL context:\n{context_blob}",
        },
    ]

    if force_deep_explain:
        prompt_messages.append(
            {
                "role": "system",
                "content": (
                    "Use this response format: Purpose, Inputs, Control Flow, Data Changes, "
                    "Dependencies, Related Objects, Key SQL Excerpt."
                ),
            }
        )

    for h in history[-6:]:
        if h.get("role") in ("user", "assistant") and h.get("content"):
            prompt_messages.append({"role": h["role"], "content": h["content"]})

    prompt_messages.append({"role": "user", "content": user_query})
    return prompt_messages


def generate_llm_answer(
    user_query: str,
    rows: Sequence[sqlite3.Row],
    history: Sequence[dict],
    llm_override: dict | None = None,
    force_deep_explain: bool = False,
) -> tuple[str | None, str | None]:
    cfg = get_llm_config(llm_override)
    if cfg is None:
        return None, "llm config missing or disabled"

    messages = build_grounded_messages(user_query, rows, history, force_deep_explain)
    body = {
        "model": cfg["model"],
        "messages": messages,
        "temperature": 0.1,
    }

    endpoint = cfg["base_url"].rstrip("/") + "/chat/completions"
    headers = {"Content-Type": "application/json"}
    if cfg.get("api_key"):
        headers["Authorization"] = f"Bearer {cfg['api_key']}"

    req = urllib.request.Request(
        endpoint,
        data=json.dumps(body).encode("utf-8"),
        headers=headers,
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=cfg["timeout_seconds"]) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        try:
            body = exc.read().decode("utf-8", errors="replace")[:240]
        except Exception:
            body = ""
        return None, f"http {exc.code}: {body}" if body else f"http {exc.code}"
    except urllib.error.URLError as exc:
        return None, f"url error: {exc.reason}"
    except TimeoutError:
        return None, "timeout"
    except (json.JSONDecodeError, KeyError) as exc:
        return None, f"invalid response: {type(exc).__name__}"

    choices = payload.get("choices") or []
    if not choices:
        return None, "no choices in response"
    message = choices[0].get("message") or {}
    content = message.get("content")
    if isinstance(content, str) and content.strip():
        return content.strip(), None
    return None, "empty content in response"


def build_fallback_answer(
    user_query: str,
    rows: Sequence[sqlite3.Row],
    force_deep_explain: bool = False,
) -> str:
    if not rows:
        return "I could not find a strong match in the SQL index. Try a more specific query with object names, business flow names, or table/procedure keywords."

    top = rows[:3]
    names = ", ".join(r["object_name"] for r in top)
    primary = top[0]

    if primary["object_type"] == "stored_procedure" and (force_deep_explain or is_deep_explain_query(user_query)):
        return build_deep_procedure_explain(user_query, primary, top)

    lines = [
        f"Best matches for '{user_query}' are: {names}.",
        "",
        "What I found:",
    ]

    for r in top[:2]:
        lines.append(f"- {r['object_name']} ({r['object_type']}) in {r['path']}")
        lines.append(f"  Evidence: {strip_snippet_markup(r['snippet'])}")

    if primary["object_type"] == "stored_procedure":
        params = parse_procedure_parameters(primary["content"])
        steps = parse_procedure_steps(primary["content"], max_steps=12)
        excerpt = extract_sql_excerpt(primary["content"], user_query, max_chars=1800)

        lines.append("")
        lines.append(f"Detailed logic walkthrough for {primary['object_name']}:")

        if params:
            lines.append("Parameters:")
            for p in params[:25]:
                lines.append(f"- {p}")

        if steps:
            lines.append("Likely execution flow:")
            for i, step in enumerate(steps, start=1):
                lines.append(f"{i}. {step}")

        if excerpt:
            lines.append("Key SQL excerpt:")
            lines.append(excerpt)

    if primary["object_type"] == "type":
        type_cols = parse_type_columns(primary["content"])
        if type_cols:
            lines.append("")
            lines.append(f"{primary['object_name']} columns:")
            for col in type_cols[:20]:
                lines.append(f"- {col}")

    lines.append("")
    lines.append("Use the sources below to open the full SQL object for exact logic and edge cases.")
    return "\n".join(lines)


def resolve_answer(
    user_query: str,
    rows: Sequence[sqlite3.Row],
    session_history: Sequence[dict] | None = None,
    llm_override: dict | None = None,
    force_deep_explain: bool = False,
) -> dict:
    history = session_history or []
    llm_cfg = get_llm_config(llm_override)

    llm_answer = None
    llm_error = None
    if llm_cfg is not None:
        llm_answer, llm_error = generate_llm_answer(user_query, rows, history, llm_override, force_deep_explain)

    if llm_answer:
        return {
            "answer": llm_answer,
            "llm": {
                "requested": True,
                "used": True,
                "mode": "external",
                "provider": (sanitize_llm_config(llm_override).get("provider") if llm_override else "env"),
                "model": llm_cfg.get("model", ""),
            },
        }

    return {
        "answer": build_fallback_answer(user_query, rows, force_deep_explain),
        "llm": {
            "requested": llm_cfg is not None,
            "used": False,
            "mode": "built_in",
            "provider": "built_in",
            "model": "deterministic",
            "error": llm_error,
        },
    }


def build_prompt_pack(user_query: str, rows: Sequence[sqlite3.Row]) -> str:
    header = [
        "You are answering questions about a SQL Server codebase.",
        f"User question: {user_query}",
        "Use only the provided context. If uncertain, say what is missing.",
        "",
        "Context:",
    ]
    body: List[str] = []
    for idx, r in enumerate(rows, start=1):
        body.append(f"[{idx}] {r['object_name']} ({r['object_type']})")
        body.append(f"Path: {r['path']}")
        body.append(f"Snippet: {r['snippet']}")
        body.append("")
    return "\n".join(header + body)


def ensure_index_exists() -> None:
    if not INDEX_DB.exists():
        raise SystemExit(
            f"Index not found at {INDEX_DB}. Run: python rag/sql_rag.py build"
        )


def cmd_build(_: argparse.Namespace) -> None:
    build_index()


def cmd_query(args: argparse.Namespace) -> None:
    ensure_index_exists()
    rows = query_index(args.query, args.k)
    print(render_results(rows))


def cmd_prompt(args: argparse.Namespace) -> None:
    ensure_index_exists()
    rows = query_index(args.query, args.k)
    prompt = build_prompt_pack(args.query, rows)

    if args.output:
        out = Path(args.output)
        if not out.is_absolute():
            out = REPO_ROOT / out
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(prompt, encoding="utf-8")
        print(f"Wrote prompt context to {out}")
    else:
        print(prompt)


def make_handler(default_k: int) -> type[BaseHTTPRequestHandler]:
    class RagHandler(BaseHTTPRequestHandler):
        server_version = "SqlRagServer/1.0"

        def _send_json(self, code: int, body: dict) -> None:
            data = json.dumps(body, ensure_ascii=True).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def _send_sse(self, event: str, data: dict) -> None:
            payload = json.dumps(data, ensure_ascii=True)
            chunk = f"event: {event}\ndata: {payload}\n\n".encode("utf-8")
            self.wfile.write(chunk)
            self.wfile.flush()

        def _parse_k(self, value: str | None) -> int:
            if value is None:
                return default_k
            try:
                k = int(value)
            except ValueError:
                return default_k
            return min(max(k, 1), 50)

        def _parse_bool(self, value: object, default: bool = False) -> bool:
            if value is None:
                return default
            if isinstance(value, bool):
                return value
            text = str(value).strip().lower()
            if text in ("1", "true", "yes", "on"):
                return True
            if text in ("0", "false", "no", "off"):
                return False
            return default

        def _serve_static_file(self, relative_path: str) -> None:
            path = (WEB_DIR / relative_path).resolve()
            if not str(path).startswith(str(WEB_DIR.resolve())) or not path.exists() or not path.is_file():
                self._send_json(404, {"error": "Static file not found"})
                return

            content = path.read_bytes()
            mime, _ = mimetypes.guess_type(str(path))
            if mime is None:
                mime = "application/octet-stream"

            self.send_response(200)
            self.send_header("Content-Type", f"{mime}; charset=utf-8")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)

        def _query_response(self, q: str, k: int) -> None:
            if not q.strip():
                self._send_json(400, {"error": "Missing query. Provide q (GET) or query (POST)."})
                return
            rows = query_index(q, k)
            self._send_json(
                200,
                {
                    "query": q,
                    "k": k,
                    "count": len(rows),
                    "results": rows_to_payload(rows),
                },
            )

        def _ask_response(
            self,
            q: str,
            k: int,
            session_id: str | None = None,
            llm_override: dict | None = None,
            deep_explain: bool = False,
        ) -> None:
            if not q.strip():
                self._send_json(400, {"error": "Missing query. Provide q (GET) or query (POST)."})
                return

            sid = get_or_create_session(session_id)
            append_session_message(sid, "user", q)
            rows = query_index(q, k)
            effective_llm = llm_override if llm_override is not None else get_session_llm_config(sid)
            resolved = resolve_answer(q, rows, get_session_history(sid), effective_llm, deep_explain)
            answer = resolved["answer"]
            append_session_message(sid, "assistant", answer)
            self._send_json(
                200,
                {
                    "session_id": sid,
                    "query": q,
                    "k": k,
                    "answer": answer,
                    "llm": resolved["llm"],
                    "deep_explain": deep_explain,
                    "count": len(rows),
                    "sources": rows_to_payload(rows),
                },
            )

        def _ask_stream_response(self, q: str, k: int, session_id: str | None = None, deep_explain: bool = False) -> None:
            if not q.strip():
                self._send_json(400, {"error": "Missing query. Provide q query string."})
                return

            sid = get_or_create_session(session_id)
            append_session_message(sid, "user", q)
            rows = query_index(q, k)
            resolved = resolve_answer(q, rows, get_session_history(sid), get_session_llm_config(sid), deep_explain)
            answer = resolved["answer"]
            append_session_message(sid, "assistant", answer)

            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream; charset=utf-8")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "close")
            self.end_headers()

            self._send_sse("session", {"session_id": sid})
            token_parts = answer.split(" ")
            assembled = ""
            for part in token_parts:
                assembled = (assembled + " " + part).strip()
                self._send_sse("delta", {"text": assembled})
                time.sleep(0.015)

            self._send_sse(
                "done",
                {
                    "session_id": sid,
                    "query": q,
                    "k": k,
                    "answer": answer,
                    "llm": resolved["llm"],
                    "deep_explain": deep_explain,
                    "count": len(rows),
                    "sources": rows_to_payload(rows),
                },
            )
            self.close_connection = True

        def do_GET(self) -> None:  # noqa: N802
            parsed = urlparse(self.path)
            if parsed.path in ("/", "/chat"):
                self._serve_static_file("index.html")
                return

            if parsed.path == "/static/style.css":
                self._serve_static_file("style.css")
                return

            if parsed.path == "/static/app.js":
                self._serve_static_file("app.js")
                return

            if parsed.path == "/health":
                self._send_json(200, {"status": "ok", "index": str(INDEX_DB)})
                return

            if parsed.path == "/query":
                qs = parse_qs(parsed.query)
                q = qs.get("q", [""])[0]
                k = self._parse_k(qs.get("k", [None])[0])
                self._query_response(q, k)
                return

            if parsed.path == "/ask":
                qs = parse_qs(parsed.query)
                q = qs.get("q", [""])[0]
                k = self._parse_k(qs.get("k", [None])[0])
                sid = qs.get("session_id", [""])[0] or None
                deep_explain = self._parse_bool(qs.get("deep_explain", [None])[0], default=False)
                self._ask_response(q, k, sid, deep_explain=deep_explain)
                return

            if parsed.path == "/session/history":
                qs = parse_qs(parsed.query)
                sid = get_or_create_session(qs.get("session_id", [""])[0] or None)
                self._send_json(200, {"session_id": sid, "history": get_session_history(sid, max_items=SESSION_MAX_TURNS)})
                return

            if parsed.path == "/llm/presets":
                self._send_json(200, {"presets": llm_presets()})
                return

            if parsed.path == "/session/llm-config":
                qs = parse_qs(parsed.query)
                sid = get_or_create_session(qs.get("session_id", [""])[0] or None)
                cfg = get_session_llm_config(sid)
                cfg.pop("api_key", None)
                self._send_json(200, {"session_id": sid, "llm": cfg, "has_api_key": bool(get_session_llm_config(sid).get("api_key"))})
                return

            if parsed.path == "/ask/stream":
                qs = parse_qs(parsed.query)
                q = qs.get("q", [""])[0]
                k = self._parse_k(qs.get("k", [None])[0])
                sid = qs.get("session_id", [""])[0] or None
                deep_explain = self._parse_bool(qs.get("deep_explain", [None])[0], default=False)
                self._ask_stream_response(q, k, sid, deep_explain)
                return

            self._send_json(
                404,
                {
                    "error": "Not found",
                    "paths": [
                        "/",
                        "/chat",
                        "/health",
                        "/query",
                        "/ask",
                        "/ask/stream",
                        "/session/history",
                        "/llm/presets",
                        "/session/llm-config",
                        "/static/style.css",
                        "/static/app.js",
                    ],
                },
            )

        def do_POST(self) -> None:  # noqa: N802
            parsed = urlparse(self.path)
            if parsed.path not in ("/query", "/ask", "/session/clear", "/session/llm-config"):
                self._send_json(
                    404,
                    {
                        "error": "Not found",
                        "paths": [
                            "/health",
                            "/query",
                            "/ask",
                            "/ask/stream",
                            "/session/history",
                            "/llm/presets",
                            "/session/llm-config",
                            "/session/clear",
                        ],
                    },
                )
                return

            content_length = int(self.headers.get("Content-Length", "0"))
            body_raw = self.rfile.read(content_length) if content_length > 0 else b"{}"
            try:
                body = json.loads(body_raw.decode("utf-8"))
            except json.JSONDecodeError:
                self._send_json(400, {"error": "Invalid JSON body"})
                return

            if parsed.path == "/session/clear":
                sid = get_or_create_session(str(body.get("session_id", "")) or None)
                clear_session(sid)
                self._send_json(200, {"session_id": sid, "status": "cleared"})
                return

            if parsed.path == "/session/llm-config":
                sid = get_or_create_session(str(body.get("session_id", "")) or None)
                cfg = body.get("llm", {})
                set_session_llm_config(sid, cfg)
                safe_cfg = get_session_llm_config(sid)
                safe_cfg.pop("api_key", None)
                self._send_json(200, {"session_id": sid, "status": "updated", "llm": safe_cfg})
                return

            q = str(body.get("query", ""))
            k = self._parse_k(str(body.get("k")) if body.get("k") is not None else None)
            sid = str(body.get("session_id", "")) or None
            deep_explain = self._parse_bool(body.get("deep_explain"), default=False)
            if parsed.path == "/query":
                self._query_response(q, k)
            else:
                self._ask_response(q, k, sid, body.get("llm"), deep_explain)

        def log_message(self, fmt: str, *args: object) -> None:
            # Keep server output clean; only startup/shutdown is printed.
            return

    return RagHandler


def cmd_serve(args: argparse.Namespace) -> None:
    ensure_index_exists()
    server = ThreadingHTTPServer((args.host, args.port), make_handler(args.k))
    print(f"SQL RAG server listening on http://{args.host}:{args.port}")
    print("Chat UI: GET / or /chat")
    print("APIs: GET /health, GET/POST /query, GET/POST /ask, GET /ask/stream, GET /session/history, GET /llm/presets, GET/POST /session/llm-config, POST /session/clear")
    if get_llm_config() is None:
        print("LLM backend: disabled (set RAG_LLM_API_KEY or OPENAI_API_KEY to enable)")
    else:
        print("LLM backend: enabled")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down SQL RAG server...")
    finally:
        server.server_close()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="SQL RAG helper for this repository")
    sub = parser.add_subparsers(dest="command", required=True)

    p_build = sub.add_parser("build", help="Build/rebuild the local FTS index")
    p_build.set_defaults(func=cmd_build)

    p_query = sub.add_parser("query", help="Run retrieval query")
    p_query.add_argument("query", help="Natural language or keyword query")
    p_query.add_argument("-k", type=int, default=5, help="Top K results (default: 5)")
    p_query.set_defaults(func=cmd_query)

    p_prompt = sub.add_parser("prompt", help="Generate LLM prompt context from query")
    p_prompt.add_argument("query", help="User question/query")
    p_prompt.add_argument("-k", type=int, default=6, help="Top K results (default: 6)")
    p_prompt.add_argument(
        "-o",
        "--output",
        help="Optional output file path (relative to repo root if not absolute)",
    )
    p_prompt.set_defaults(func=cmd_prompt)

    p_serve = sub.add_parser("serve", help="Start local HTTP query server")
    p_serve.add_argument("--host", default="127.0.0.1", help="Bind host (default: 127.0.0.1)")
    p_serve.add_argument("--port", type=int, default=8787, help="Bind port (default: 8787)")
    p_serve.add_argument("-k", type=int, default=5, help="Default top K for query endpoint")
    p_serve.set_defaults(func=cmd_serve)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
