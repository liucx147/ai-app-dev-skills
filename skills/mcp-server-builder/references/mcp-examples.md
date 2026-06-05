# MCP Examples

> Reference companion to `../SKILL.md` and `mcp-protocol-spec.md`. Five production-style examples covering the common cases. Copy the closest one, edit, ship.

## 1. Minimal stdio server (TypeScript)

A single-tool server. The smallest possible MCP server that does something useful.

```typescript
// src/index.ts
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";

const server = new Server(
  { name: "echo-server", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [{
    name: "echo",
    description: "Echoes the input back. Use for connectivity testing.",
    inputSchema: {
      type: "object",
      properties: { message: { type: "string", description: "Text to echo." } },
      required: ["message"],
    },
    annotations: { readOnlyHint: true, idempotentHint: true, openWorldHint: false },
  }],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  if (request.params.name !== "echo") {
    return { content: [{ type: "text", text: `Unknown tool: ${request.params.name}` }], isError: true };
  }
  const { message } = request.params.arguments as { message: string };
  return { content: [{ type: "text", text: message }], isError: false };
});

const transport = new StdioServerTransport();
await server.connect(transport);
```

```json
// examples/claude_desktop_config.json
{
  "mcpServers": {
    "echo": {
      "command": "npx",
      "args": ["-y", "echo-server"]
    }
  }
}
```

## 2. Python FastMCP server with all three primitives

```python
# src/server.py
from mcp.server.fastmcp import FastMCP
from pydantic import BaseModel, Field

mcp = FastMCP("docs-server")

# ---- TOOL ----
class SearchInput(BaseModel):
    query: str = Field(..., description="Natural-language search query.")
    top_k: int = Field(5, ge=1, le=20, description="Number of results to return.")

@mcp.tool(
    name="search_documents",
    description=(
        "Search the corporate knowledge base. Use when the user asks a question "
        "that could be answered by an internal doc. Returns ranked results with "
        "stable ids. Example: search_documents(query='SSO setup steps')."
    ),
)
def search_documents(params: SearchInput) -> list[dict]:
    # Replace with real backend.
    return [{"id": "doc42", "title": "SSO setup", "snippet": "...", "score": 0.92}]

# ---- RESOURCE ----
@mcp.resource("docs://{doc_id}", mime_type="text/markdown")
def read_document(doc_id: str) -> str:
    if doc_id not in KNOWN_IDS:
        raise ValueError(f"Unknown document: {doc_id}")
    return fetch_document(doc_id)

# ---- PROMPT ----
@mcp.prompt(
    name="summarize-document",
    description="Summarize a document by id. User-invocable.",
)
def summarize_document(document_id: str) -> str:
    return (
        f"Please summarize the following document in 3 bullet points:\n\n"
        f"<document id=\"{document_id}\">\n...</document>"
    )

if __name__ == "__main__":
    mcp.run()  # stdio by default; pass transport="http" for Streamable HTTP
```

## 3. Side-effecting tool with annotation honesty

A tool that creates a ticket. The `destructiveHint: false` is correct — creating a ticket is non-destructive (recoverable, reversible by deleting). The `idempotentHint: true` is correct — the same `idempotency_key` returns the same ticket id. The `openWorldHint: true` is correct — the tool talks to an external ticketing system.

```typescript
{
  name: "create_ticket",
  description:
    "Create a support ticket. ALWAYS confirm the title, body, and assignee with " +
    "the user before invoking. Use the user's own words for the body; do not " +
    "paraphrase. Example: create_ticket(title='Cannot log in', body='...', " +
    "idempotency_key='cli-2026-06-05-abc').",
  inputSchema: {
    type: "object",
    properties: {
      title:           { type: "string",  description: "Short ticket title, ≤ 80 chars." },
      body:            { type: "string",  description: "Full ticket body, markdown allowed." },
      assignee_email:  { type: "string",  description: "Optional, defaults to round-robin." },
      idempotency_key: { type: "string",  description: "Caller-supplied key; same key returns same ticket." },
    },
    required: ["title", "body", "idempotency_key"],
  },
  annotations: {
    readOnlyHint: false,
    destructiveHint: false,    // creating ≠ deleting
    idempotentHint: true,      // same key → same effect
    openWorldHint: true,       // talks to external ticketing system
  },
}
```

The handler:

```typescript
async function create_ticket(args: { title: string; body: string; assignee_email?: string; idempotency_key: string }) {
  // 1. Idempotency check.
  const existing = await idempotencyStore.get(args.idempotency_key);
  if (existing) return existing;

  // 2. Validate.
  if (args.title.length > 80) {
    return { content: [{ type: "text", text: "Title exceeds 80 chars" }], isError: true };
  }

  // 3. Call backend with a hard timeout.
  const result = await withTimeout(ticketingApi.create(args), 10_000, "create_ticket");

  // 4. Store the idempotency record.
  await idempotencyStore.put(args.idempotency_key, result);

  return { content: [{ type: "text", text: `Created ticket ${result.id}` }], isError: false };
}
```

## 4. Resource with templated URI

```typescript
server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  const { uri } = request.params;

  // Templated URI: docs://{doc_id}
  const match = uri.match(/^docs:\/\/([a-zA-Z0-9_-]+)$/);
  if (!match) {
    return { contents: [], _meta: { error: `Invalid URI: ${uri}` } };
  }
  const docId = match[1];

  const doc = await docStore.get(docId);
  if (!doc) {
    // Errors here are protocol-level: return a JSON-RPC error.
    throw new McpError(ErrorCode.InvalidParams, `No such document: ${docId}`);
  }

  return { contents: [{ uri, mimeType: "text/markdown", text: doc.body }] };
});
```

Notice the two-layer error handling:
- **Invalid URI format** → return empty contents with error metadata (the call was syntactically valid).
- **Unknown id** → throw a JSON-RPC error (`InvalidParams`). The client knows the call was malformed in spirit.

## 5. Streamable HTTP transport (TypeScript)

For a remote server that multiple clients can connect to:

```typescript
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import express from "express";
import { randomUUID } from "node:crypto";

const server = new Server({ name: "docs-server-http", version: "1.0.0" }, { capabilities: { tools: {} } });

// ... register handlers same as above ...

const app = express();
app.use(express.json());

// Session management: one transport per client session.
const transports: Record<string, StreamableHTTPServerTransport> = {};

app.post("/mcp", async (req, res) => {
  const sessionId = req.headers["mcp-session-id"] as string | undefined;
  let transport: StreamableHTTPServerTransport;

  if (sessionId && transports[sessionId]) {
    transport = transports[sessionId];
  } else {
    transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: () => randomUUID(),
      onsessioninitialized: (sid) => { transports[sid] = transport; },
    });
    transport.onclose = () => { delete transports[transport.sessionId!]; };
    await server.connect(transport);
  }

  await transport.handleRequest(req, res, req.body);
});

app.listen(3000, () => console.error("MCP HTTP server on :3000"));
```

```json
// examples/claude_desktop_config.json (HTTP variant)
{
  "mcpServers": {
    "docs-remote": {
      "url": "http://localhost:3000/mcp"
    }
  }
}
```

## 6. Testing with the MCP Inspector

The **MCP Inspector** is the official debug UI. Use it during Phase 4.

```bash
# TypeScript
npx @modelcontextprotocol/inspector node dist/index.js

# Python
mcp dev src/server.py
```

It opens a browser UI. From there:

1. **Connect** to your server (stdio launches it; HTTP just connects).
2. **List Tools / Resources / Prompts** — verify the registered names, descriptions, and schemas.
3. **Call a tool** with a small JSON payload — verify the response shape and `isError` flag.
4. **Read a resource** with a templated URI — verify the URI substitution works.
5. **Get a prompt** with arguments — verify the rendered messages look right.
6. **History tab** — inspect the raw JSON-RPC frames. This is the single best way to debug framing bugs.

A test script that drives the Inspector headlessly:

```python
# tests/integration/test_inspector.py
import subprocess, json, time

def test_search_tool():
    proc = subprocess.Popen(["mcp", "dev", "src/server.py"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    initialize = {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "0"}}}
    call = {"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "search_documents", "arguments": {"query": "SSO"}}}
    proc.stdin.write(json.dumps(initialize) + "\n")
    proc.stdin.write(json.dumps(call) + "\n")
    proc.stdin.flush()
    # Read two responses.
    r1 = json.loads(proc.stdout.readline())
    r2 = json.loads(proc.stdout.readline())
    assert "result" in r2 and not r2["result"].get("isError"), r2
    proc.terminate()
```

## Cross-Cutting Tips

- **Log to stderr, not stdout**, in stdio mode. Stdout is the protocol channel. A stray `console.log` in your server corrupts the JSON-RPC stream and the client silently fails.
- **Keep the server stateless when possible**. State (sessions, idempotency records) belongs in a store, not in module-level globals.
- **Validate every argument** against the schema. A client bug that sends `arguments: null` should produce a typed error, not a stack trace.
- **Test failure paths**. Most MCP servers are tested for the happy path; production breaks on the 1 % that the schema didn't anticipate.
