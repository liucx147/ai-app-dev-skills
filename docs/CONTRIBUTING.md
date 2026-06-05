# Contributing

Thanks for considering a contribution to `ai-app-dev-skills`. This project lives or dies by the quality of its Skills — please read this guide end-to-end before opening a PR.

## Before You Start

1. Read [CLAUDE.md](../CLAUDE.md) for the project's hard rules (layout, frontmatter spec, prohibitions).
2. Read [SKILL-AUTHORING-GUIDE.md](SKILL-AUTHORING-GUIDE.md) if you're adding or changing a Skill.
3. Open (or comment on) an issue using the **Skill request** or **Feature request** template before writing code. We'd rather discuss scope upfront than reject a finished PR.

## Setup

```bash
git clone https://github.com/<your-fork>/ai-app-dev-skills.git
cd ai-app-dev-skills
python3 -m pip install --user pyyaml      # required by scripts/validate.sh
chmod +x scripts/*.sh                     # one-time, *nix only
```

## SKILL.md Format Cheatsheet

Every `skills/<name>/SKILL.md` MUST have this frontmatter:

```yaml
---
name: <kebab-case, ≤ 64 chars, matches the directory name>
description: <150–300 chars, states both "when" and "what">
allowed-tools: <optional; comma-string OR YAML list>
disable-model-invocation: <optional; default false>
---
```

The validator (`scripts/validate.sh`) enforces all of the above. See [SKILL-AUTHORING-GUIDE.md](SKILL-AUTHORING-GUIDE.md) for the full spec, with worked examples and field-by-field rationale.

## Writing a Description That Triggers

The `description` is the **only** thing Claude sees when deciding whether to load your Skill. Treat it like ad copy for a semantic search.

- **Lead with a trigger verb**: "Use when…", "Invoke for…", "Apply when…".
- **Name the concrete artifacts** the user is likely to mention (`RAG pipeline`, `chunking step`, `MCP server`, `vector database`).
- **State what the Skill produces** (a project, an analysis, a config — never "help").
- **Aim for 150–300 chars** — short enough to stay in the trigger window, long enough to disambiguate from sibling Skills.
- **Test with three realistic phrasings** before submitting. If your description doesn't read as the obvious match for the request, rewrite it.

A good `description` reads like the answer to "what would I Google to find this Skill?". See [SKILL-AUTHORING-GUIDE.md §3](SKILL-AUTHORING-GUIDE.md#3-frontmatter-spec) for side-by-side bad / good examples.

## Local Test Checklist

Run these in order before pushing:

```bash
# 1. Project validator passes (checks a–d from the CI spec).
bash scripts/validate.sh

# 2. Validator's own tests pass (3 cases).
bash scripts/test-validate.sh

# 3. README Skill index regenerates cleanly.
bash scripts/generate-index.sh

# 4. Installer sees your new Skill (dry-run; should list it).
bash scripts/install.sh --dry-run

# 5. End-to-end: open Claude Code in a fresh project, type 3 trigger
#    phrases for your Skill, confirm Claude loads it and the body
#    instructions walk you through the task. This is the only test
#    that catches "description doesn't actually trigger."
```

If all five pass, push and open the PR.

## Development Loop

```bash
# Create a feature branch from main
git switch -c feat/<short-name>

# ... edit / add files ...

bash scripts/validate.sh                  # MUST pass before pushing
bash scripts/generate-index.sh            # regenerate the README index

git add -A
git commit -m "feat(<scope>): <subject>"  # Conventional Commits
git push -u origin feat/<short-name>
```

Open a PR using the template. CI runs `scripts/validate.sh` and `scripts/test-validate.sh` on every push.

## What We Accept

- ✅ New Skills that cover a real, recurring AI-app-dev task.
- ✅ Improvements to existing Skills (sharper descriptions, better steps, fewer failure modes).
- ✅ Reference doc additions / corrections that more than one Skill will link.
- ✅ Tooling improvements (validator, installer, CI).

## What We Decline

- ❌ Skills that duplicate an existing Skill's trigger surface — refine the existing one.
- ❌ Skills that wrap a single library call without adding judgement / context.
- ❌ Personal preference dotfiles, IDE configs, or hosting-specific glue.
- ❌ Anything containing secrets, real API keys, or proprietary content.

## Commit Style

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(rag-chunking): add semantic splitter recipe
fix(installer): handle Windows symlink fallback
docs(authoring-guide): clarify description length rules
refactor(validate): switch to PyYAML safe_load
chore(ci): bump checkout action to v4
```

Scope is the Skill name or area, in kebab-case. Subject is imperative, ≤ 72 chars, no trailing period.

## PR Review

- One reviewer approval is required.
- All CI checks must be green.
- We squash-merge by default; the PR title becomes the commit subject.
- Expect comments — Skill descriptions in particular often need a second pass to trigger reliably.

## Code of Conduct

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/) spirit, adapted to a small, focused maintainer team:

- **Be kind.** Critique the Skill, not the contributor. Assume good faith.
- **Stay on topic.** Off-topic debates belong in the issue tracker, not in PR comments.
- **Disclose conflicts.** If you're working on a commercial project that touches a Skill, say so in the PR description.
- **No tolerance for harassment.** Maintainers reserve the right to remove comments or contributors that violate this.

## License

By contributing, you agree your work is licensed under the [MIT License](../LICENSE).
