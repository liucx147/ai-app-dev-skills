<div align="center">

# 🧠 ai-app-dev-skills

### The definitive Claude Code Skill Pack for building production-grade AI applications

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Skills](https://img.shields.io/badge/Skills-4-blueviolet.svg)](skills/)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Compatible-blue.svg)](#-compatibility)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](docs/CONTRIBUTING.md)

**Production-grade Skills for RAG · Agents · Prompt Engineering · MCP Servers — plug into Claude Code and ship.**

</div>

---

> Replace `liucx147` below with your GitHub organization (or username) before running.

```bash
curl -fsSL https://raw.githubusercontent.com/liucx147/ai-app-dev-skills/main/scripts/install.sh | bash
```

---

## 🤔 Why ai-app-dev-skills?

AI applications are easy to demo, brutally hard to ship. The gap between "works on my machine" and "production" is filled with eval frameworks, retrieval tuning, agent guardrails, and protocol specs nobody has time to learn. This pack closes that gap with Skills that walk Claude through the entire delivery lifecycle — from requirements to architecture, runnable code, optimization, and evaluation.

| Without Skills | With ai-app-dev-skills |
| --- | --- |
| *"Build me a RAG app"* → 300 lines of glue code | *Same prompt* → production architecture, eval framework, deployment-ready project |
| Agent loops forever, burns tokens, hallucinates | Hard turn caps, retry policies, human-in-the-loop gates, observability |
| Prompts are written by vibes, results vary by run | 25 engineered patterns, versioned prompts, A/B test harness |
| MCP servers reverse-engineered from the spec | 5-minute scaffold of a compliant server with Tool/Resource/Prompt registration |
| "I don't know how to start" | 6-phase workflows with decision trees, templates, and self-validating scripts |

> **Stop reinventing. Start shipping.**

---

## ✨ The Skill Pack

### Quick Index

<!-- SKILL_INDEX:START -->
| Skill | Description |
| --- | --- |
| [`agent-architect`](skills/agent-architect/SKILL.md) | Use when building an AI agent, designing agent architecture, implementing tool use, creating multi-agent systems, building autonomous workflows, or adding agent memory and planning. Covers ReAct, Plan-and-Execute, LATS, multi-agent patterns, and agent evaluation. |
| [`mcp-server-builder`](skills/mcp-server-builder/SKILL.md) | Use when creating an MCP server, implementing MCP tools, building MCP resources, adding MCP prompts, or integrating MCP into existing apps. Covers TypeScript/Python SDK, transport layers, tool registration, and MCP best practices. |
| [`prompt-engineering-expert`](skills/prompt-engineering-expert/SKILL.md) | Use when writing system prompts, designing prompt chains, optimizing prompt performance, building prompt templates, implementing structured output, or creating evaluation datasets. Covers Chain-of-Thought, Few-shot, Constitutional AI, prompt versioning, and A/B testing. |
| [`rag-pipeline-builder`](skills/rag-pipeline-builder/SKILL.md) | Use when building, designing, or optimizing a RAG system, vector search pipeline, document ingestion pipeline, knowledge base, or retrieval-augmented app. Covers chunking, vector DB and embedding selection, hybrid retrieval, reranking, and evaluation. |
<!-- SKILL_INDEX:END -->

---

### 🔄 `rag-pipeline-builder` — Production RAG Systems

Design, build, and optimize retrieval-augmented generation pipelines from chunking strategy to evaluation.

**Triggers on:** `build a RAG system` · `vector search pipeline` · `document ingestion` · `knowledge base` · `retrieval-augmented app`

- 5-phase workflow: requirements → architecture → code → optimization → evaluation
- Compares 9 vector databases across 8 dimensions (Pinecone, Weaviate, Qdrant, Milvus, Chroma, pgvector, Vespa, LanceDB, Elasticsearch)
- 6 chunking strategies with Python recipes, hybrid search, reranking, and RAGAS evaluation
- Generates runnable project skeletons with `.env.example`, README, and a self-validating script

### 🤖 `agent-architect` — AI Agent Systems

Architect, prototype, and ship agent systems that don't loop forever or destroy data.

**Triggers on:** `build an AI agent` · `design agent architecture` · `implement tool use` · `create multi-agent system` · `autonomous workflow`

- 6-phase workflow: requirements → pattern selection → tool design → memory → code → evaluation
- 7 agent patterns (ReAct, ReAct+Router, Plan-and-Execute, LATS, Reflexion, Debate, Hierarchical) with an ASCII decision tree
- 10 production tool templates with explicit error contracts, sandbox flags, and human-in-the-loop gates
- Cross-framework guidance for LangGraph, CrewAI, AutoGen, Semantic Kernel, OpenAI Agents SDK

### ✍️ `prompt-engineering-expert` — Engineered Prompts

Craft, optimize, and systematize prompts that produce consistent, measurable, safe outputs.

**Triggers on:** `write system prompt` · `design prompt chain` · `optimize prompt` · `structured output` · `evaluation dataset`

- 25 prompt patterns with minimal templates and "use when" guidance (Zero-shot → Multi-modal)
- 4-dimension evaluation framework: accuracy, consistency, safety, cost — with an A/B test harness
- 15 anti-patterns with bad-example / why-it-fails / fix
- Prompt versioning conventions, version-controlled prompts/, and one-page eval report template

### 🔌 `mcp-server-builder` — MCP Servers & Clients

Build Model Context Protocol servers and clients that work with Claude Desktop, IDEs, and any compliant client.

**Triggers on:** `create MCP server` · `implement MCP tools` · `build MCP resources` · `add MCP prompts` · `integrate MCP`

- 5-phase workflow: capability scoping → protocol design → code → test → publish
- Full protocol spec (handshake, Tools/Resources/Prompts, transports, JSON-RPC framing, safety annotations)
- 6 worked examples in TypeScript and Python (stdio and Streamable HTTP)
- Claude Desktop config snippets, MCP Inspector testing recipe, npm/PyPI publishing checklist

---

## 🚀 Quick Start

**Three steps. About 60 seconds.**

```bash
# 1. Install (no checkout required)
curl -fsSL https://raw.githubusercontent.com/liucx147/ai-app-dev-skills/main/scripts/install.sh | bash

# 2. Restart Claude Code

# 3. Try a Skill
# Open Claude Code and type one of the trigger phrases above.
```

**Or install from a local checkout** (better for contributors):

```bash
git clone https://github.com/liucx147/ai-app-dev-skills
cd ai-app-dev-skills
bash scripts/install.sh                # symlink mode (edits picked up live)
bash scripts/install.sh --copy        # copy mode
bash scripts/install.sh --dry-run     # preview only
bash scripts/install.sh --target <d>  # custom install dir
```

The installer drops every Skill into `~/.claude/skills/`. Restart Claude Code and they're live.

---

## 💬 Usage Examples

### 🟢 Build a RAG pipeline

> **You:** *Build me a RAG system over our internal Confluence.*

Claude loads `rag-pipeline-builder` and walks you through:
1. **Requirements** — 5,000 pages, mixed PDFs and HTML, p95 < 2 s, on-prem, GDPR.
2. **Architecture** — PostgreSQL stack → **pgvector**; BGE-M3 embeddings; recursive Markdown chunking at 512 tokens; hybrid BM25 + vector with RRF; Cohere Rerank 3; Claude Sonnet 4.6 with prompt caching.
3. **Code** — A complete Python project: `src/ingest/`, `src/retrieve/`, `src/generate/`, `src/api/`, RAGAS eval scripts, `.env.example`, README.
4. **Optimization** — Walks the 10-item checklist; flags what's done and what needs work.
5. **Evaluation** — Generates a 50-question eval set, runs RAGAS, produces a one-page report.

### 🟢 Ship an agent that handles refunds

> **You:** *I need an agent that can issue refunds up to $200 with human approval above that.*

Claude loads `agent-architect` and produces:
- **Pattern:** ReAct + Tool Router (30+ tools across the support platform).
- **Tools:** `lookup_order`, `process_refund` (HITL gate, max $200), `send_email` (HITL gate), `escalate_to_human`.
- **Memory:** short-term conversation buffer + long-term vector store for customer preferences.
- **Hard caps:** `max_turns=25`, `max_cost_per_task=$0.50`, action-loop detection.
- **Observability:** Langfuse integration from day one.

### 🟢 Rewrite a prompt that has been "kind of working"

> **You:** *This prompt is unreliable, please optimize it.*

Claude loads `prompt-engineering-expert` and:
1. Pins the model version (you weren't).
2. Builds a 50-example held-out eval set covering happy path, edge cases, and 5 known failures.
3. Rewrites the prompt using **Structured Output** (pattern 11) with an explicit JSON schema.
4. A/B tests the new version in shadow mode.
5. Ships the one with higher accuracy *and* lower cost.

### 🟢 Build an MCP server for your internal docs

> **You:** *I want a Claude Desktop integration that lets the model search our internal docs.*

Claude loads `mcp-server-builder` and produces:
- **Capabilities:** 1 tool (`search_documents`) + 1 resource (`docs://{id}`) + 1 prompt (`summarize-document`).
- **Project:** TypeScript stdio server; `npm install && npm run dev` to start.
- **Annotations:** `readOnlyHint: true`, `idempotentHint: true` — honest safety labels.
- **Tested with MCP Inspector** — every tool, resource, and prompt verified end-to-end.
- **Claude Desktop config** — a copy-pasteable JSON snippet.

---

## 📁 Project Structure

```text
ai-app-dev-skills/
├── README.md
├── LICENSE
├── CLAUDE.md
├── skills/                              # The Skill Pack
│   ├── rag-pipeline-builder/
│   │   ├── SKILL.md
│   │   ├── references/                  # chunking · vector DBs · retrieval
│   │   └── scripts/validate-rag-pipeline.sh
│   ├── agent-architect/
│   │   ├── SKILL.md
│   │   ├── references/                  # patterns · multi-agent · tool design
│   │   └── scripts/validate-agent.sh
│   ├── prompt-engineering-expert/
│   │   ├── SKILL.md
│   │   └── references/                  # 25 patterns · eval · 15 anti-patterns
│   └── mcp-server-builder/
│       ├── SKILL.md
│       └── references/                  # protocol spec · 6 examples
├── scripts/                             # Repo-level tooling
│   ├── install.sh                       # Local + remote (curl | bash)
│   ├── validate.sh                      # SKILL.md frontmatter validator
│   ├── test-validate.sh                 # 3-case smoke test for the validator
│   └── generate-index.sh                # Auto-generates the Quick Index above
├── references/                          # Cross-skill reference material
├── examples/                            # End-to-end demos
├── docs/
│   ├── CONTRIBUTING.md
│   ├── SKILL-AUTHORING-GUIDE.md
│   └── CHANGELOG.md
└── .github/
    ├── ISSUE_TEMPLATE/                  # bug · feature · skill request
    ├── pull_request_template.md
    └── workflows/validate-skills.yml
```

---

## 🤝 Contributing

We welcome new Skills, improvements to existing ones, and reference material that more than one Skill will link into.

1. Read [`docs/SKILL-AUTHORING-GUIDE.md`](docs/SKILL-AUTHORING-GUIDE.md) end-to-end.
2. Open a **Skill request** issue using the template — describe trigger phrases, pattern, supporting material.
3. Wait for maintainer sign-off on scope.
4. Submit a PR using the template. CI runs `scripts/validate.sh`; passing is required.
5. On merge, your Skill appears in the Quick Index automatically — `scripts/generate-index.sh` rewrites the README in CI.

See [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) for the full guide.

---

## 🛠 Compatibility

Targets any tool that supports the Claude Code Skill spec:

| Tool | Compatible | Notes |
| --- | --- | --- |
| **Claude Code** | ✅ Primary | Full support; symlinked install picks up edits live. |
| **Cursor** | ✅ | Skills appear as slash-command equivalents. |
| **Windsurf** | ✅ | Compatible via Claude Code Skill adapter. |
| **Codex CLI** | ✅ | Compatible with the MCP adapter layer. |
| **Other** | ➡️ | Any tool that loads `SKILL.md` frontmatter + body. |

If your tool supports the SKILL.md spec but isn't listed, open an issue and we'll add it.

---

## ⭐ Star History

If this pack saved you time, consider starring it — it helps others find it.

<div align="center">

[![Star History Chart](https://api.star-history.com/svg?repos=liucx147/ai-app-dev-skills&type=Date)](https://star-history.com/#liucx147/ai-app-dev-skills&Date)

</div>

---

## 📄 License

[MIT](LICENSE) © 2026 AI App Dev Skills Contributors.

Built by AI engineers who got tired of writing the same scaffolding over and over. 🛠️
