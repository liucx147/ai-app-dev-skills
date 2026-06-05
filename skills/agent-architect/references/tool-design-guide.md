# Tool Design Guide

> Reference companion to `../SKILL.md` Phase 3. The single biggest determinant of agent quality is tool design. This guide is the playbook; the 10 templates at the bottom are starting points for the most common cases.

## The 7 Rules of Tool Design

1. **Name = action verb + object.** `search_documents`, not `docs`. `create_ticket`, not `tickets`. The agent reads the name first; it must be a verb.
2. **Description = mini-SOP.** Write as if for a junior engineer who has never seen your system. When to use, when NOT to use, input semantics, output shape, error contract. Include 1–2 in-description examples — Claude mimics them faithfully.
3. **Required-only schemas.** Optional sprawl is the #1 source of hallucinated arguments. Make parameters required when they actually are; collapse near-always-required fields.
4. **Structured results.** Stable field names. Avoid free-form prose unless the next step is reading. For long outputs, return a summary + a handle (id, path, URL) the agent can fetch on demand.
5. **Errors are part of the tool.** Return `{ok: false, error: "...", retryable: bool}`. Never throw across the tool boundary; the agent must be able to decide retry vs. change-tactic vs. escalate.
6. **Side effects declared up front.** A tool that writes must declare `requires_approval: bool`. A tool that runs code must declare `sandbox: bool`. A tool that spends must declare `cost_hint: float`.
7. **Idempotency is a feature.** When a write is naturally non-idempotent, expose an idempotency-key parameter and document it. Agents retry more than you think.

---

## Anatomy of a Production-Ready Tool

```python
from pydantic import BaseModel, Field
from typing import Literal

class SearchDocumentsInput(BaseModel):
    query: str = Field(..., description="Natural-language search query. "
                        "Use the same vocabulary the user used. "
                        "Example: 'error when uploading a CSV'.")
    top_k: int = Field(5, ge=1, le=20, description="Number of results. "
                       "Use ≤ 5 for chat, ≤ 20 for batch research.")
    filter_source: str | None = Field(None, description="Optional source filter, "
                                      "e.g. 'docs.acme.com'. Use to scope the search.")

class SearchDocumentsOutput(BaseModel):
    ok: bool
    results: list[dict] = Field(default_factory=list)  # {id, title, snippet, score}
    error: str | None = None
    retryable: bool = False

TOOL_SEARCH_DOCUMENTS = {
    "name": "search_documents",
    "description": """Search the corporate knowledge base for documents matching a query.

Use when:
  - The user asks a question that could be answered by an internal doc.
  - You need a citation to back up a claim.

Do NOT use when:
  - The user asks for a single known item by name (use `read_file` instead).
  - The corpus is external (use `http_get` instead).

Returns up to `top_k` results, each with an `id` you can pass to `read_file`
or `cite_document`. Example call: search_documents(query='SSO setup steps').
""",
    "input_schema": SearchDocumentsInput.model_json_schema(),
    "requires_approval": False,
    "sandbox": False,
    "cost_hint": 0.001,
}
```

---

## The 10 Production Templates

### 1. `search_documents` — read-only search

```yaml
name: search_documents
description: |
  Search the knowledge base. Use when the user asks a question that could be
  answered by an internal doc. Returns ranked results with stable ids.
input_schema:
  type: object
  required: [query]
  properties:
    query:        { type: string,  description: "Natural-language query." }
    top_k:        { type: integer, default: 5, minimum: 1, maximum: 20 }
    filter_source: { type: string,  description: "Optional source scope." }
returns: { ok: bool, results: [{id, title, snippet, score}], error?: string }
error_contract:
  - { code: "empty_query",   retryable: false }
  - { code: "rate_limited",  retryable: true,  retry_after_s: 5 }
  - { code: "backend_down",  retryable: true,  retry_after_s: 30 }
```

### 2. `read_file` — fetch a document by id

```yaml
name: read_file
description: |
  Fetch a single document's full text by id. Use after search_documents returns
  a promising id. Returns up to 8 KB of text; for longer docs the response
  includes a `truncated: true` flag and a `next_chunk` cursor.
input_schema:
  type: object
  required: [file_id]
  properties:
    file_id:      { type: string, description: "Id from search_documents." }
    cursor:       { type: integer, default: 0, description: "Byte offset for pagination." }
returns: { ok: bool, text: string, truncated: bool, next_cursor?: int }
error_contract:
  - { code: "not_found",     retryable: false }
  - { code: "too_large",     retryable: false, hint: "Re-call with cursor > 0" }
```

### 3. `write_file` — local file write (HITL)

```yaml
name: write_file
description: |
  Write text to a local file. ALWAYS requires human approval.
  Use when the user explicitly asks to save / create / export a file.
input_schema:
  type: object
  required: [path, content]
  properties:
    path:     { type: string, description: "Relative path, e.g. 'reports/q3.md'." }
    content:  { type: string, description: "UTF-8 content to write." }
    overwrite: { type: boolean, default: false, description: "If false, fails on existing file." }
returns: { ok: bool, bytes_written: int, error?: string }
requires_approval: true
error_contract:
  - { code: "exists_no_overwrite", retryable: false }
  - { code: "path_traversal",      retryable: false }   # SECURITY: always reject
```

### 4. `run_sql_query` — read-only DB query

```yaml
name: run_sql_query
description: |
  Run a read-only SQL query against the analytics warehouse. Use for any
  numeric or aggregate question. Returns up to 1000 rows; for more, page with
  cursor.
input_schema:
  type: object
  required: [sql]
  properties:
    sql:    { type: string, description: "Single SELECT statement. No DDL, no writes." }
    params: { type: array,  description: "Bound parameters, e.g. ['2026-01-01']." }
returns: { ok: bool, rows: array, columns: [string], truncated: bool, error?: string }
constraints:
  - Single statement only; parser rejects semicolons.
  - 30-second statement timeout.
  - No SELECT * on tables > 1M rows; require explicit column list.
```

### 5. `mutate_database` — write query (HITL)

```yaml
name: mutate_database
description: |
  Run an INSERT / UPDATE / DELETE against the production database. ALWAYS
  requires human approval. Wraps the call in a transaction; the approval UI
  shows the affected-row estimate before approve.
input_schema:
  type: object
  required: [sql, params]
  properties:
    sql:    { type: string }
    params: { type: array }
    dry_run: { type: boolean, default: true, description: "Default true: estimate rows first." }
returns: { ok: bool, rows_affected: int, transaction_id: string, error?: string }
requires_approval: true
error_contract:
  - { code: "dry_run_required_first", retryable: false }
  - { code: "constraint_violation",   retryable: false }
```

### 6. `http_get` — external API read

```yaml
name: http_get
description: |
  Fetch a URL (HTML, JSON, or text). Use for external documentation, public
  APIs, or any web resource the user names. 10-second timeout; max 2 MB.
input_schema:
  type: object
  required: [url]
  properties:
    url:    { type: string, format: "uri" }
    headers: { type: object, additionalProperties: { type: string } }
returns: { ok: bool, status: int, body: string, content_type: string, error?: string }
constraints:
  - SSRF guard: reject private IP ranges.
  - 10-second connect + read timeout.
error_contract:
  - { code: "non_2xx",       retryable: false }
  - { code: "timeout",       retryable: true }
  - { code: "too_large",     retryable: false }
  - { code: "ssrf_blocked",  retryable: false }
```

### 7. `http_post` — external API write (HITL)

```yaml
name: http_post
description: |
  Send a POST to an external API. ALWAYS requires human approval if the URL
  is not on the allowlist. Returns the parsed JSON response.
input_schema:
  type: object
  required: [url, body]
  properties:
    url:     { type: string, format: "uri" }
    body:    { type: object }
    headers: { type: object, additionalProperties: { type: string } }
returns: { ok: bool, status: int, response: object, error?: string }
requires_approval: true
error_contract:
  - { code: "non_2xx",        retryable: false }
  - { code: "idempotency_required", retryable: false,
      hint: "Retry with the same Idempotency-Key header." }
```

### 8. `execute_python` — sandboxed code run

```yaml
name: execute_python
description: |
  Run a Python snippet in a locked-down sandbox (no network, no filesystem
  write, 5-second timeout, 256 MB memory cap). Use for any computation the
  agent can do in code — math, data manipulation, regex — rather than asking
  the LLM to compute it.
input_schema:
  type: object
  required: [code]
  properties:
    code: { type: string, description: "Python source. Use stdlib + numpy + pandas only." }
returns: { ok: bool, stdout: string, stderr: string, result?: any, error?: string }
constraints:
  - No network (egress blocked at the container level).
  - No filesystem writes.
  - 5-second wall clock, 256 MB memory, 1 CPU.
  - Pre-imported: numpy, pandas, math, re, json, datetime.
error_contract:
  - { code: "timeout",   retryable: true }
  - { code: "oom",       retryable: false }
  - { code: "imports_blocked", retryable: false,
      hint: "Only numpy, pandas, math, re, json, datetime are available." }
```

### 9. `remember_fact` — long-term memory write

```yaml
name: remember_fact
description: |
  Store a fact about the user or domain for future conversations. The fact is
  embedded and stored; retrieved on every future call when relevant. Use
  sparingly — only for facts the user has stated or that are domain-critical.
input_schema:
  type: object
  required: [key, value]
  properties:
    key:        { type: string, description: "Short stable key, e.g. 'user.timezone'." }
    value:      { type: string, description: "The fact itself, in natural language." }
    ttl_days:   { type: integer, default: 365, description: "Days until automatic forget." }
    scope:      { type: string, enum: ["user", "domain", "global"], default: "user" }
returns: { ok: bool, memory_id: string, error?: string }
constraints:
  - One fact per call. Do not store paragraphs.
  - Total per-user memory cap: 500 facts. Older facts auto-GC'd by score.
```

### 10. `request_human_approval` — explicit HITL gate

```yaml
name: request_human_approval
description: |
  Pause the agent and ask a human to approve, reject, or modify a proposed
  action. Use this whenever you are about to do something the user might not
  want. The action is described in natural language; the human's response
  becomes a tool result you can act on.
input_schema:
  type: object
  required: [action_summary, why, proposed_payload]
  properties:
    action_summary: { type: string, description: "One-line human-readable summary." }
    why:            { type: string, description: "Why the agent is asking." }
    proposed_payload: { type: object, description: "What the agent would do if approved." }
    timeout_minutes: { type: integer, default: 60 }
returns: { ok: bool, decision: "approved" | "rejected" | "modified",
          modified_payload?: object, reason?: string, error?: string }
behavior:
  - On timeout: default to "rejected" with reason "approval timeout".
  - On "rejected": treat as permanent failure; do not re-ask in the same session.
  - On "modified": replace the proposed_payload with the human's version, then proceed.
```

---

## Composition Patterns

### Chain (A → B)

Pre-validate the shape at composition time. A schema mismatch here is a silent bug in production.

```python
search_results = await search_documents(query=q, top_k=5)
assert all("id" in r for r in search_results["results"])
doc = await read_file(file_id=search_results["results"][0]["id"])
```

### Parallel (A || B || C)

Use aggressively for independent calls. Bound the parallelism (5–10 concurrent) and the total timeout.

```python
results = await asyncio.gather(
    search_documents(query=q1),
    search_documents(query=q2),
    search_documents(query=q3),
)
```

### Conditional (guard → A)

Always default-deny. The agent must explicitly pass the guard.

```python
if state["user_role"] != "admin":
    return {"ok": False, "error": "admin_only"}
return await run_sql_query(sql=state["proposed_sql"])
```

---

## Testing Tools

Every production tool ships with three test classes:

1. **Schema test** — Pydantic (or equivalent) rejects malformed inputs; accepts well-formed.
2. **Mock backend test** — with a stub backend, the tool returns the right shape on success / known failure / timeout.
3. **Live smoke test** — gated on `--with-smoke`; hits the real backend with a single, harmless request. Used in CI nightly, not every commit.

The biggest ROI is a test that asserts **the description is unchanged** for 30 days — a quiet description change is the most common cause of silent agent regression.

---

## Anti-Patterns

- **Tool names that are categories** (`docs`, `tickets`, `db`). The agent will not know when to call them.
- **Free-form prose in tool output**. The next tool — or the LLM — needs a stable shape.
- **Throwing across the boundary**. Use the `{ok, error, retryable}` contract instead.
- **Optional params for things that are always required**. The agent will invent defaults.
- **Side effects with no declaration**. A `write_file` tool without `requires_approval: true` is a foot-gun.
- **Idempotency ignored**. Agents retry. Your tool must survive that.
