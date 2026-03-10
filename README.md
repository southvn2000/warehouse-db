# warehouse-db

Database-first SQL Server backend for Australia Logistic.

## Repository Layout

- `StoreProcedures/`: Main business logic procedures.
- `LogStoreProcedures/`: Logging procedure set.
- `Tables/`: Core application tables.
- `LogTables/`: Logging tables.
- `Functions/`: User-defined helper functions.
- `Types/`: User-defined table types (TVPs).

## Local RAG For SQL Objects

A local Retrieval-Augmented Generation helper is available in `rag/`.

### Build Index

```bash
python rag/sql_rag.py build
```

### Query Index

```bash
python rag/sql_rag.py query "order insert and wave start flow" -k 5
```

### Generate Context Prompt For LLMs

```bash
python rag/sql_rag.py prompt "How does stock on hand get calculated?" -k 6 -o rag/context_prompt.txt
```

The index is written to `.rag/sql_index.db` and should be rebuilt when SQL files change.

### Run Local Chat UI

```bash
python rag/sql_rag.py serve --host 127.0.0.1 --port 8787
```

Then open `http://127.0.0.1:8787/` in your browser.
