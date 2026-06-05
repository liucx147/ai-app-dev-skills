# CLAUDE.md

> Project-level configuration for Claude Code working in the `ai-app-dev-skills` repository.

## Project Overview

- **Name**: ai-app-dev-skills
- **Tagline**: The definitive Claude Code Skill Pack for building production-grade AI applications.
- **Scope**: Curated, battle-tested Skills covering RAG, Agents, Prompt Engineering, MCP Server development, evaluation, observability, and the full lifecycle of AI app delivery.
- **Audience**: AI engineers and teams using Claude Code as their primary development environment.

## Tech Stack

- **Primary language**: Markdown (Skill instructions, references, docs).
- **Scripting**: Bash (installer, validator, index generator, CI helpers).
- **Example code**: Python (preferred for RAG / Agent / MCP samples). TypeScript is acceptable for MCP and tool-use examples.
- **CI**: GitHub Actions (skill validation, link checking, lint).

## Repository Layout

```
ai-app-dev-skills/
├── CLAUDE.md                  # This file — read first
├── README.md                  # Public-facing entry point
├── LICENSE                    # MIT
├── .github/                   # Issue/PR templates, CI workflows
├── skills/<skill-name>/       # One directory per Skill (see "Skill Layout")
├── scripts/                   # Repo-level helpers (install/validate/index)
├── examples/                  # End-to-end usage demos
├── references/                # Cross-skill reference material
└── docs/                      # Contributor + author docs
```

## Skill Layout — MUST follow

Every Skill is a self-contained directory under `skills/`:

```
skills/<skill-name>/
├── SKILL.md             # REQUIRED — entry point read by Claude Code
├── scripts/             # OPTIONAL — helper scripts the Skill invokes
├── references/          # OPTIONAL — long-form context the Skill loads on demand
├── templates/           # OPTIONAL — file templates the Skill copies / fills
└── examples/            # OPTIONAL — illustrative inputs / outputs
```

### `SKILL.md` Frontmatter Spec

```markdown
---
name: <kebab-case-name>           # REQUIRED, ≤ 64 chars, must equal directory name
description: <when + what>        # REQUIRED, 150–300 chars, semantic trigger
allowed-tools: Read, Bash, Grep   # OPTIONAL; string OR YAML list (see below)
disable-model-invocation: false   # OPTIONAL, default false
---
```

- `name` MUST be kebab-case (`rag-chunking-strategies`, not `RAG_Chunking`).
- `name` MUST match the containing directory name exactly.
- `description` MUST describe both **what the Skill does** and **when it should trigger**. Aim for 150–300 characters. Lead with the trigger verb ("Use when…", "Invoke for…").
- Use `allowed-tools` to constrain a Skill's tool surface; omit to inherit the session defaults.
- `allowed-tools` accepts either a comma-separated string (`Read, Write, Edit`) **or** a YAML list (`- Read` / `- Write` / `- Edit`). Pick whichever reads better for your Skill — `scripts/validate.sh` accepts both.
- Use `disable-model-invocation: true` only for skills that must be invoked explicitly by the user (rare).

### `SKILL.md` Body Spec

- Written in **English**, Markdown only.
- Begin with a one-paragraph summary of the Skill's purpose.
- Use clear **numbered steps** for procedural Skills.
- Reference supporting files with **relative paths** (e.g. `scripts/run.sh`, `references/patterns.md`).
- NEVER hardcode absolute paths (`/Users/...`, `C:\Users\...`, `~/...` outside of explicit user-config examples).
- NEVER hardcode usernames, machine names, or environment-specific identifiers.
- When the Skill needs to run code, place it under the Skill's own `scripts/` directory and invoke via the relative path.
- When the Skill needs lengthy reference material, place it under the Skill's own `references/` directory and instruct Claude to read it on demand (lazy-load to keep the SKILL.md lean).

## Code Style

- **Markdown**: English only, ATX headers (`#`), fenced code blocks with language tags, line length ~100 chars (soft).
- **Comments**: English only, in Markdown, Shell, and Python.
- **Shell**: Bash (`#!/usr/bin/env bash`), `set -euo pipefail`, prefer POSIX-portable syntax where reasonable.
- **Python**: PEP 8, type hints on public functions, docstrings for non-trivial helpers.
- **YAML**: 2-space indent, lowercase keys, no trailing whitespace.

## Hard Prohibitions

- ❌ Do not hardcode absolute paths in `SKILL.md` or any Skill helper.
- ❌ Do not hardcode user/machine-specific identifiers.
- ❌ Do not bundle large binary assets (>1 MB) — link out instead.
- ❌ Do not include API keys, tokens, or any secret material in examples — use clearly fake placeholders (`sk-ant-PLACEHOLDER`).
- ❌ Do not add Skills that duplicate an existing Skill's trigger description — refine the existing one instead.

## Testing & Validation

- Every new or changed Skill MUST pass `scripts/validate.sh` before merge.
- The `description` field MUST be specific enough that semantic matching reliably triggers the Skill for its intended use case — test with realistic user phrasings before submitting.
- CI runs `scripts/validate.sh` on every push and PR via `.github/workflows/validate-skills.yml`.
- When a Skill ships helper scripts, include a minimal smoke test or example invocation in the Skill's `examples/` directory.

## Git Conventions

- **Branching**: feature work on `feat/<short-name>`, fixes on `fix/<short-name>`.
- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/) — `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, `test:`, `ci:`.
- **Scope** (optional): the affected Skill or area, e.g. `feat(rag-chunking): add semantic splitter recipe`.
- **PR titles**: mirror the commit subject; keep under 72 chars.
- Squash-merge by default; preserve a clean history.

## When Authoring a New Skill

1. Read `docs/SKILL-AUTHORING-GUIDE.md` end-to-end.
2. Create `skills/<your-skill-name>/SKILL.md` with valid frontmatter.
3. Add supporting `scripts/`, `references/`, `templates/`, `examples/` as needed.
4. Run `bash scripts/validate.sh` locally.
5. Run `bash scripts/generate-index.sh` to refresh the README index.
6. Open a PR using the template.

## Quick Commands

```bash
bash scripts/validate.sh          # Validate every SKILL.md
bash scripts/generate-index.sh    # Regenerate the skill index in README.md
bash scripts/install.sh           # Install skills into the user's Claude Code config
```
