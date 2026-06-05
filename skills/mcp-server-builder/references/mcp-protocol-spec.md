# MCP Protocol Spec

> Reference companion to `../SKILL.md`. The protocol at a glance — enough to design a server correctly. For exhaustive detail, always defer to the official spec at modelcontextprotocol.io.

## What MCP Is

The **Model Context Protocol (MCP)** is a JSON-RPC 2.0-based protocol that lets LLM clients (Claude Desktop, IDEs, custom apps) talk to **servers** that expose three kinds of capability:

| Primitive | Direction | Purpose |
| --- | --- | --- |
| **Tools** | client → server → client | Model-invoked actions (`search`, `create_ticket`, `run_sql`) |
| **Resources** | client → server → client | Model- or user-fetched read-only context (`docs://...`, `file://...`) |
| **Prompts** | client → server → client | User-invoked prompt templates with arguments |

A single MCP server can expose any combination. Clients discover capabilities via the `initialize` → `tools/list`, `resources/list`, `prompts/list` handshake.

## Transports

| Transport | Use when | Mechanism |
| --- | --- | --- |
| **stdio** | Local integrations (Claude Desktop, IDE plugins) | The client launches the server as a subprocess. Server reads JSON-RPC frames from stdin, writes to stdout. |
| **Streamable HTTP** | Remote / multi-client / stateless servers | The client sends `POST` with JSON-RPC; the server can respond with either a single JSON reply or an SSE stream of progress + final result. |

The two transports speak the same protocol at the JSON-RPC layer; only the framing and lifecycle differ. Servers usually pick one at startup.

## Lifecycle

```text
client                                 server
  │                                       │
  │── initialize (capabilities, version)─►│
  │◄── initialize result (capabilities)───│
  │                                       │
  │── notifications/initialized ─────────►│   (one-shot)
  │                                       │
  │── tools/list ────────────────────────►│
  │◄── tools (list) ──────────────────────│
  │                                       │
  │── tools/call (name, arguments) ──────►│
  │◄── result OR error ───────────────────│
  │                                       │
  │── resources/list ────────────────────►│
  │◄── resources (list) ──────────────────│
  │                                       │
  │── resources/read (uri) ──────────────►│
  │◄── contents (text / blob) ───────────│
  │                                       │
  │── prompts/list ──────────────────────►│
  │◄── prompts (list) ────────────────────│
  │                                       │
  │── prompts/get (name, args) ─────────►│
  │◄── messages (template rendered) ──────│
  │                                       │
  │── ping ──────────────────────────────►│   (keep-alive)
  │◄── empty result ──────────────────────│
```

### The `initialize` handshake

The first frame on every connection. The client sends its `protocolVersion`, `capabilities`, and `clientInfo`; the server replies with its own.

```json
// client → server
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": { "sampling": {}, "roots": { "listChanged": true } },
    "clientInfo": { "name": "claude-desktop", "version": "1.0.0" }
  }
}
```

```json
// server → client
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": { "tools": {}, "resources": {}, "prompts": {} },
    "serverInfo": { "name": "docs-server", "version": "1.0.0" }
  }
}
```

After `initialize`, the client sends `notifications/initialized` (no `id`, no response expected) to confirm readiness.

## Tool Spec

### `tools/list` response

```json
{
  "tools": [
    {
      "name": "search_documents",
      "description": "Search the knowledge base ...",
      "inputSchema": { "type": "object", "properties": { ... }, "required": [...] },
      "annotations": {
        "readOnlyHint": true,
        "destructiveHint": false,
        "idempotentHint": true,
        "openWorldHint": false
      }
    }
  ]
}
```

### `tools/call` request

```json
{
  "method": "tools/call",
  "params": {
    "name": "search_documents",
    "arguments": { "query": "SSO setup steps", "top_k": 5 }
  }
}
```

### `tools/call` success response

```json
{
  "content": [
    { "type": "text", "text": "Found 5 results:\n1. ..." },
    { "type": "resource", "resource": { "uri": "docs://abc123", "mimeType": "text/markdown" } }
  ],
  "isError": false
}
```

### `tools/call` error response

```json
{
  "content": [
    { "type": "text", "text": "Tool failed: backend timeout after 10s (retryable)" }
  ],
  "isError": true
}
```

Note: **errors come back in the success envelope with `isError: true`**, not as a JSON-RPC error. Reserve JSON-RPC errors for protocol-level failures (method not found, invalid params).

## Resource Spec

### `resources/list` response

```json
{
  "resources": [
    { "uri": "docs://index",          "name": "Doc index",      "mimeType": "application/json" },
    { "uri": "docs://{id}",           "name": "Document by id", "mimeType": "text/markdown",
      "description": "Read a document by its stable id." }
  ]
}
```

`{id}` in a URI marks a **templated resource** — the client fills it in to call `resources/read`.

### `resources/read` request

```json
{ "method": "resources/read", "params": { "uri": "docs://abc123" } }
```

### `resources/read` response

```json
{
  "contents": [
    { "uri": "docs://abc123", "mimeType": "text/markdown", "text": "..." }
  ]
}
```

For binary content, use `blob` (base64) instead of `text`.

## Prompt Spec

### `prompts/list` response

```json
{
  "prompts": [
    {
      "name": "summarize-document",
      "description": "Summarize a document by id.",
      "arguments": [
        { "name": "document_id", "description": "From search_documents.", "required": true }
      ]
    }
  ]
}
```

### `prompts/get` request

```json
{ "method": "prompts/get",
  "params": { "name": "summarize-document", "arguments": { "document_id": "abc123" } } }
```

### `prompts/get` response

```json
{
  "description": "Summarize a document by id.",
  "messages": [
    { "role": "user",
      "content": { "type": "text",
        "text": "Please summarize the following document:\n\n<document id=\"abc123\">\n...\n</document>" } }
  ]
}
```

The client renders the messages; the user sees exactly what will be sent. **Prompts are not magic** — they are templates with full transparency.

## Annotations — the safety contract

Every tool can declare four hints. Clients use them to gate dangerous actions.

| Hint | Meaning | When true |
| --- | --- | --- |
| `readOnlyHint` | Tool does not modify state | `true` for searches, reads, computations |
| `destructiveHint` | Tool may irreversibly modify state | `true` for deletes, drops, payments |
| `idempotentHint` | Same args → same effect (safe to retry) | `true` for reads, sets; `false` for appends |
| `openWorldHint` | Tool talks to an open-world resource (e.g. web) | `true` for HTTP calls to arbitrary URLs |

A `destructiveHint: true` tool is a signal to the client to require user confirmation before invoking. **Never mislabel these.** A delete tool that says `destructiveHint: false` is a safety incident waiting to happen.

## JSON-RPC framing

All frames are newline-delimited JSON. Each frame is one JSON object.

- **Request**: has `id` (number or string) and `method`. Server must reply.
- **Notification**: has `method` but no `id`. No reply expected.
- **Response (success)**: has matching `id` and `result`.
- **Response (error)**: has matching `id` and `error` with `code` and `message`.

Standard JSON-RPC error codes: `-32700` (parse error), `-32600` (invalid request), `-32601` (method not found), `-32602` (invalid params), `-32603` (internal error). Use MCP-specific codes for protocol-level failures (see the spec for the registry).

## Versioning

The `initialize` frame includes `protocolVersion`. Servers and clients negotiate to a mutually supported version. Bump your server's version when you change capability shapes; never silently change the schema of an existing tool.

## When to read more

For the exhaustive spec — including the full list of methods, error codes, capability negotiation, sampling / elicitation, and roots — go to the official MCP spec. Treat this document as a **design checklist**, not a substitute.
