# Changelog

All notable changes to `ai-app-dev-skills` are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- _nothing yet_

### Changed

- _nothing yet_

### Fixed

- _nothing yet_

### Removed

- _nothing yet_

---

## [0.1.0] - 2026-06-05

The first public release. Four flagship Skills, full repo tooling, CI, and contributor docs.

### Added

**Skills (4)**

- `skills/rag-pipeline-builder/` — 5-phase workflow for production RAG; 3 reference docs (chunking strategies, vector DB comparison, retrieval optimization); self-validating `scripts/validate-rag-pipeline.sh`.
- `skills/agent-architect/` — 6-phase workflow for production agents; 3 reference docs (agent patterns, multi-agent orchestration, tool design guide with 10 templates); `scripts/validate-agent.sh`.
- `skills/prompt-engineering-expert/` — 4-phase workflow for engineered prompts; 3 reference docs covering 25 prompt patterns, a 4-dimension evaluation framework, and 15 anti-patterns.
- `skills/mcp-server-builder/` — 5-phase workflow for MCP servers; 2 reference docs (protocol spec, 6 worked examples in TypeScript and Python).

**Scripts (4, all executable, all top-of-file documented)**

- `scripts/install.sh` — unified installer: local-checkout mode (symlink or copy) **and** remote mode for `curl | bash` one-liner. Flags: `--target`, `--copy`, `--dry-run`, `--remote [url]`.
- `scripts/validate.sh` — SKILL.md frontmatter validator. Accepts `allowed-tools` as either comma-string or YAML list.
- `scripts/test-validate.sh` — 3-case smoke test for the validator (comma-string pass, YAML list pass, invalid scalar fail).
- `scripts/generate-index.sh` — auto-regenerates the README Skill index between `<!-- SKILL_INDEX:START -->` and `:END` markers.

**Repository plumbing**

- `CLAUDE.md` — project-level rules (layout, frontmatter spec, prohibitions, git conventions).
- `README.md` — high-conversion landing page (hero, pain points, 4-Skill overview, quick start, usage examples, project tree, contributing, compatibility, star history, license).
- `LICENSE` — MIT.
- `.gitignore` — Python / Node / IDE / OS junk.

**CI**

- `.github/workflows/validate-skills.yml` — runs the validator, the validator's own tests, and a markdown lint on every push to `main` and every PR.

**Issue / PR templates**

- `bug-report.md`, `feature-request.md`, `skill-request.md` (under `.github/ISSUE_TEMPLATE/`).
- `pull_request_template.md`.

**Contributor docs**

- `docs/CONTRIBUTING.md` — full flow + SKILL.md format cheatsheet + description writing guide + local test checklist + Code of Conduct.
- `docs/SKILL-AUTHORING-GUIDE.md` — canonical Skill authoring reference with a full walkthrough of an existing Skill.
- `docs/CHANGELOG.md` — this file.

**Reference material (cross-skill)**

- `references/rag-patterns.md` — RAG patterns (chunking, retrieval, reranking, evaluation).
- `references/agent-architecture.md` — agent architecture (tool-use loop, planning, memory, multi-agent).
- `references/prompt-templates.md` — prompt scaffolds (XML, role-priming, few-shot, CoT, caching).

### Notes

- The validator enforces `description` length at **150–300 chars** (project convention from `CLAUDE.md`).
  This is intentionally tighter than a generic 50–500 spec: descriptions shorter than 150 chars tend to be
  vague, descriptions longer than 300 lose semantic-trigger precision. The 4 shipped Skills all pass this
  bar with headroom (longest is 285 chars).
- `scripts/install.sh` ships with `liucx147` as the default repo URL placeholder. Replace it before publishing
  (`sed -i 's|liucx147|your-org|g' scripts/install.sh README.md`).
- `allowed-tools` accepts **either** a comma-separated string (`Read, Write, Edit`) **or** a YAML list
  (`- Read` / `- Write`). Both forms are first-class; choose whichever reads better in your frontmatter.

[Unreleased]: https://github.com/liucx147/ai-app-dev-skills/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/liucx147/ai-app-dev-skills/releases/tag/v0.1.0
