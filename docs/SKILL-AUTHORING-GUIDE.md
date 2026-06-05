# Skill Authoring Guide

The canonical reference for writing a Skill that belongs in `ai-app-dev-skills`. If you only read one document before contributing, read this one.

## 1. What a Skill Is

A Skill is a directory under `skills/` containing a `SKILL.md` file with YAML frontmatter and Markdown instructions. Claude Code loads the frontmatter at session start; when a user prompt **semantically matches** the `description`, Claude reads the body and follows the instructions.

A Skill is **not**:

- A function library — it's a behavior contract for the model.
- A chat persona — it's a procedural recipe for a specific task.
- A documentation page — it's instructions a model executes.

## 2. Directory Layout

```
skills/<skill-name>/
├── SKILL.md             # REQUIRED
├── scripts/             # OPTIONAL — helper scripts the Skill invokes
├── references/          # OPTIONAL — long-form context, lazy-loaded
├── templates/           # OPTIONAL — file templates
└── examples/            # OPTIONAL — sample inputs / outputs
```

- The directory name MUST equal the `name` frontmatter field.
- Keep `SKILL.md` lean — push long reference text into `references/` and tell Claude to read it on demand.

## 3. Frontmatter Spec

```yaml
---
name: rag-chunking-strategies
description: >-
  Use when designing or debugging a RAG pipeline's chunking step — picking
  chunk size, overlap, structural vs. semantic splitting. The Skill walks
  through trade-offs, recommends a default per corpus type, and provides
  Python recipes.
allowed-tools: Read, Bash, Grep
disable-model-invocation: false
---
```

### Field Rules

| Field | Required | Rules |
| --- | --- | --- |
| `name` | yes | kebab-case, ≤ 64 chars, matches directory name. |
| `description` | yes | 150–300 chars, includes both **when** and **what**. |
| `allowed-tools` | no | Either a comma-separated string (`Read, Bash, Grep`) or a YAML list (`- Read` / `- Bash` / `- Grep`). Omit to inherit defaults. |
| `disable-model-invocation` | no | Boolean. Set `true` only for explicit-invoke-only Skills. |

### Writing a Description That Triggers

The `description` is the single biggest determinant of whether your Skill ever fires. Treat it like ad copy for a semantic search.

**Bad** (vague, no trigger):

> A skill for chunking documents.

**Bad** (trigger but no scope):

> Use when working with documents.

**Good** (trigger + action + scope):

> Use when designing or debugging a RAG pipeline's chunking step — picking chunk size, overlap, structural vs. semantic splitting. The Skill walks through trade-offs, recommends a default per corpus type, and provides Python recipes.

Heuristics:

1. Lead with a trigger verb: "Use when…", "Invoke for…", "Apply when…".
2. Name the concrete artifacts involved (`RAG pipeline`, `chunking step`, `Python recipes`).
3. State what the Skill outputs or changes.
4. Hit 150–300 characters — the validator enforces this.
5. **Test it.** Phrase three realistic user requests and check whether your description reads as the obvious match.

## 4. Body Structure

Use this template as a starting point:

```markdown
# <Skill Display Name>

<One-paragraph summary: what it does, who benefits.>

## When to Use

- Trigger 1
- Trigger 2
- Trigger 3

## When NOT to Use

- Anti-trigger 1
- Anti-trigger 2

## Steps

1. **Step name** — what to do, what to read, what to ask.
2. **Step name** — …
3. …

## Reference Material

- See `references/<topic>.md` for <X>.
- See `../../references/rag-patterns.md` §3 for chunking trade-offs.

## Examples

See `examples/<case>.md`.
```

Rules:

- Steps are **numbered** and **imperative** ("Run …", "Read …", "Ask the user …").
- Reference files using **relative paths** (`scripts/foo.py`, `../../references/...`).
- No absolute paths. No `~/`. No machine-specific identifiers.
- Tell Claude exactly when to lazy-load a reference: "If the user is using OpenAI embeddings, read `references/openai-specifics.md`."

### Body Patterns

Pick the body shape that matches the task. Three reusable patterns:

| Pattern | When to use | Example Skill |
| --- | --- | --- |
| **Linear workflow** | The task has a fixed order: requirements → design → code → test | `mcp-server-builder` (5 phases) |
| **Decision tree** | The task branches on user input; pick a path first | `agent-architect` (ReAct vs Plan-and-Execute vs LATS) |
| **Checklist** | The task is a list of independent verifications; order is flexible | most optimization-style Skills |

Mix as needed. The point is: when Claude reads the body, it should be able to start with the first step without re-deciding the order.

## 5. Helper Scripts

When a Skill needs deterministic logic (file generation, API calls, validation), put it under the Skill's own `scripts/` directory.

- Prefer **Python** for non-trivial logic; **bash** for thin glue.
- Make scripts executable and idempotent.
- Document the exact invocation in `SKILL.md` ("Run `python skills/<name>/scripts/run.py --input=...`").
- Surface failures as non-zero exit codes with clear stderr messages — Claude reads them and adapts.

## 6. Reference Files

For knowledge the Skill needs but rarely all of:

- Place under `skills/<name>/references/`.
- Cross-link from `SKILL.md` with a clear trigger ("Read `references/cohere.md` when the user picks Cohere embeddings").
- Cross-link from the **repo-level** `references/` only when the content is genuinely cross-skill. (Skills are self-contained; cross-skill refs are an exception, not a default.)

## 7. Output Format

Most flagship Skills end with an explicit **Output Format** section that pins down what an artifact looks like before it's handed back to the user. Recommended contract:

- **Justify decisions** — each architectural choice carries a "Picked X over Y because…" line.
- **Be runnable as-is** — no pseudocode, no `# TODO`, no missing imports.
- **Ship with onboarding** — `.env.example` (placeholders only), `README.md` (install, configure, run, evaluate).
- **Cite the references** — when you apply a chunking, retrieval, or pattern, point the user to the relevant section of `references/`.

## 8. Testing Your Skill

Before submitting:

1. Run `bash scripts/validate.sh` — catches frontmatter errors.
2. Run `bash scripts/test-validate.sh` — confirms the validator itself works.
3. Run `bash scripts/generate-index.sh` — updates the README index.
4. Install locally with `bash scripts/install.sh` (use `--dry-run` first).
5. In a fresh Claude Code session, paste your three trigger phrases and confirm the Skill activates.
6. Walk through the Skill's steps with a realistic input — note any ambiguity Claude exposes and fix it in `SKILL.md`.

## 9. Anti-Patterns

- **Kitchen-sink descriptions** — listing 10 unrelated triggers in one Skill. Split it.
- **Imperative tone in the wrong place** — `SKILL.md` instructs Claude (second person); references describe concepts (third person / neutral).
- **Embedded long examples** — bloats every session that triggers the Skill. Move to `examples/`.
- **Hidden side effects** — a Skill that silently writes to disk surprises users. Make writes explicit and confirmable.
- **Re-invented wheels** — if another Skill already covers your trigger surface, improve it instead of forking.
- **Vague "when"** — "Use when working with code" is too broad. Name the artifacts.

## 10. Common Errors & Debugging

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `validator: name does not match directory` | Directory name and `name:` differ by case, hyphens, or trailing whitespace | Rename the directory; rerun the validator. |
| `validator: description out of range` | `description` shorter than 150 or longer than 300 chars | Tighten the trigger phrase and the action sentence. |
| Skill never fires in Claude Code | `description` is too generic; reads as a sibling of stronger Skills | Add the concrete artifacts users will mention (file types, libraries, code patterns). |
| Skill fires too often (overlaps with another) | `description` is too close to an existing Skill's | Make yours more specific; add a "Do NOT use when" line if needed. |
| Helper script fails with `Permission denied` | Forgot `chmod +x` on the script | Run `chmod +x skills/<name>/scripts/*.sh`. |
| Body says "see `references/x.md`" but Claude errors with file not found | Cross-Skill ref from another Skill's directory, or absolute path | Use a relative path from `SKILL.md` (e.g. `references/x.md`, not `../../references/x.md`). |
| Validator fails with `pyyaml not found` | `pip install pyyaml` not run | `python3 -m pip install --user pyyaml`. |
| `generate-index.sh` produces a table but with the wrong columns | README's `<!-- SKILL_INDEX:START -->` / `:END` markers missing | Re-insert the markers exactly; the script only rewrites between them. |
| Markdown lint flags a body in CI | Trailing whitespace, missing language tag on code fence, mixed heading levels | Fix the flagged file; locally you can preview with `npx markdownlint-cli2 skills/<name>/*.md`. |

## 11. A Complete Skill Walkthrough — `mcp-server-builder`

To make the spec concrete, here is the actual `skills/mcp-server-builder/SKILL.md` dissected.

### Frontmatter

```yaml
---
name: mcp-server-builder
description: Use when creating an MCP server, implementing MCP tools, ...
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
---
```

| Field | Why this value |
| --- | --- |
| `name` | `mcp-server-builder` — kebab-case, 18 chars, matches the directory name exactly. |
| `description` | 240 chars. Opens with a trigger verb, lists 5 user-uttered artifact phrases (creating an MCP server, implementing MCP tools, building MCP resources, adding MCP prompts, integrating MCP), and ends with what the Skill covers (TypeScript/Python SDK, transport layers, tool registration, best practices). |
| `allowed-tools` | YAML list, not comma-string. The Skill needs to read prior context, write new files, run scripts (e.g. `npx @modelcontextprotocol/inspector`), and search the codebase. This is the right surface; it doesn't need `WebFetch` or `WebSearch`. |

### Body

The body follows the **linear workflow** pattern (5 numbered phases), each with a one-paragraph "what to do" plus concrete sub-tasks:

- **Phase 1 — Capability Scoping**: asks the user 3 grouped questions (Tools, Resources, Prompts). The Skill explicitly refuses to proceed if any group is unanswered — this is how you prevent the "I'll just guess" failure mode.
- **Phase 2 — Protocol Design**: defines the contracts (tool `inputSchema`, resource URIs, prompt templates) before any code. The user can edit the contract; the code generation is mechanical.
- **Phase 3 — Code Generation**: project layout, per-module standards (time hints, structured logging, error envelope, timeouts), transport choice (stdio vs Streamable HTTP).
- **Phase 4 — Testing**: unit tests for each capability + integration tests with the MCP Inspector. The Inspector is the source of truth for "does this actually work."
- **Phase 5 — Publishing**: npm/PyPI packaging, README, Claude Desktop config snippet.

After the phases, two short sections:

- **Anti-Patterns** — 6 named failure modes (throwing across the protocol boundary, fragile URI parsing, etc.) the user is likely to fall into.
- **Output Format** — 5 binding rules every generated artifact must satisfy.

### Why this Skill is a good model

- The 5 phases map to natural break points; a human contributor can review and merge after any single phase.
- Each phase has an explicit "do not proceed unless" gate, so the Skill can't run ahead of the user.
- `references/mcp-protocol-spec.md` is **lazy-loaded** — Claude only reads it when the user is at Phase 2, keeping the trigger load minimal.
- The Skill's "Output Format" section doubles as a PR review checklist for the contributor who wrote the Skill.

## 12. Checklist Before You PR

- [ ] Directory name matches frontmatter `name`.
- [ ] `name` is kebab-case, ≤ 64 chars.
- [ ] `description` is 150–300 chars, with explicit when + what.
- [ ] `SKILL.md` body has numbered steps.
- [ ] No absolute paths anywhere.
- [ ] Helper scripts live in the Skill's own `scripts/`.
- [ ] Long context lives in the Skill's own `references/` and is lazy-loaded.
- [ ] `bash scripts/validate.sh` passes.
- [ ] `bash scripts/test-validate.sh` passes.
- [ ] `bash scripts/generate-index.sh` was run (README updated).
- [ ] Tested with three realistic trigger phrases in a real Claude Code session.
- [ ] `docs/CHANGELOG.md` updated under the **Unreleased** section.
