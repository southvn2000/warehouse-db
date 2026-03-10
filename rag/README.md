# SQL RAG Toolkit

This folder contains a lightweight Retrieval-Augmented Generation (RAG) setup for this SQL Server repository.

It indexes SQL files from:
- `Functions/`
- `StoreProcedures/`
- `LogStoreProcedures/`
- `Tables/`
- `LogTables/`
- `Types/`

## Quick start

Run from repository root:

```bash
python rag/sql_rag.py build
python rag/sql_rag.py query "wave start request status transition" -k 5
```

To generate a context prompt file for an external LLM:

```bash
python rag/sql_rag.py prompt "how does order to wave flow work" -k 6 -o rag/context_prompt.txt
```

## Commands

- `build`: rebuild local SQLite FTS index (stored in `.rag/sql_index.db`).
- `query`: search indexed SQL objects and print ranked matches with snippets.
- `prompt`: create a RAG context pack suitable to paste into an LLM prompt.
- `serve`: start a local HTTP server for query APIs.

## Query server

Start server:

```bash
python rag/sql_rag.py serve --host 127.0.0.1 --port 8787
```

Open chat UI in browser:

- `http://127.0.0.1:8787/`
- `http://127.0.0.1:8787/chat`

In the UI, click `LLM Settings` to configure external LLM usage.
The header shows `Current LLM` so you can always see which model mode is active.
Each assistant response also indicates if external LLM was actually used or if built-in grounded fallback handled it.

Endpoints:

- `GET /health`
- `GET /query?q=wave+start+request&k=5`
- `POST /query` with JSON body: `{"query": "wave start request", "k": 5}`
- `GET /ask?q=wave+start+request&k=5`
- `POST /ask` with JSON body: `{"query": "wave start request", "k": 5}`
- `GET /ask/stream?q=wave+start+request&k=5&session_id=<id>` (SSE typing stream)
- `GET /session/history?session_id=<id>`
- `GET /llm/presets`
- `GET /session/llm-config?session_id=<id>`
- `POST /session/llm-config` with JSON body: `{"session_id": "<id>", "llm": {...}}`
- `POST /session/clear` with JSON body: `{"session_id": "<id>"}`

`/ask` returns:
- a text `answer` synthesized from top retrieved SQL snippets
- `sources` with object names and file paths
- `llm` metadata showing whether external LLM was actually used (`used: true`) or built-in fallback answered (`used: false`)

## Conversation memory

- Memory is stored in-process by `session_id`.
- The chat UI auto-generates and persists `session_id` in local storage.
- `POST /session/clear` clears server memory for that session.

## Optional LLM backend (grounded answers)

If configured, `/ask` and `/ask/stream` use an LLM for richer natural language answers while grounding on retrieved SQL context and source snippets.

Environment variables:

- `RAG_LLM_API_KEY` (or `OPENAI_API_KEY`)
- `RAG_LLM_BASE_URL` (optional, default `https://api.openai.com/v1`)
- `RAG_LLM_MODEL` (optional, default `gpt-4o-mini`)
- `RAG_LLM_TIMEOUT` seconds (optional, default `45`)

If no API key is set, the server uses built-in deterministic answer generation.

UI presets:

- `Copilot (GitHub Models)` preset
- `Ollama (local)` preset

You can start from a preset and then edit URL/model/key manually.

## Notes

- Uses only Python standard library (no extra dependencies).
- Re-run `build` when SQL files change.
- Retrieval uses SQLite FTS5 + BM25 ranking.
