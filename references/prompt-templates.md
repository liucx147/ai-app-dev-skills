# Prompt Templates Reference

> Reusable prompt scaffolds for Claude. Skills should reference the relevant section instead of restating the template inline.

## Table of Contents

1. [Anatomy of a Claude prompt](#1-anatomy-of-a-claude-prompt)
2. [XML structuring](#2-xml-structuring)
3. [Role priming](#3-role-priming)
4. [Few-shot examples](#4-few-shot-examples)
5. [Chain-of-thought / extended thinking](#5-chain-of-thought--extended-thinking)
6. [Output formatting](#6-output-formatting)
7. [Refusal & uncertainty handling](#7-refusal--uncertainty-handling)
8. [Prompt caching layout](#8-prompt-caching-layout)

---

## 1. Anatomy of a Claude prompt

A robust Claude prompt usually layers these blocks, in this order:

1. **System role** — who Claude is, what it does, what it never does.
2. **Stable context** — long-lived knowledge / docs (cache-eligible).
3. **Task instructions** — what to do, how to do it, what success looks like.
4. **Examples** — a small number of high-quality input/output pairs.
5. **Input** — the user's actual query, wrapped in clear delimiters.
6. **Output contract** — exact format, fields, constraints.

Keep instructions in the **system message** and data in the **user message** — it lets you cache the former and vary the latter cheaply.

## 2. XML structuring

Claude follows XML-style tags faithfully. Use them whenever a prompt has multiple distinct sections.

```xml
<role>
You are a senior backend engineer reviewing a pull request.
</role>

<context>
<file path="src/handler.ts">
... file contents ...
</file>
</context>

<task>
Identify correctness bugs only. Skip style.
</task>

<output_format>
Return a JSON array of {file, line, severity, message}.
</output_format>
```

- Tag names are arbitrary but **be consistent** within a project.
- Nest only when nesting reflects the data (`<documents><document>...`).
- Refer to tags by name in instructions ("review every file in `<context>`") — Claude resolves the reference.

## 3. Role priming

A focused role primer is worth dozens of correctness instructions.

```
You are a senior security engineer specializing in web application
vulnerabilities. You have 10 years of experience auditing TypeScript and
Python backends. You speak directly and never speculate when you can verify.
```

Guidelines:

- Specify the **domain**, **seniority**, and **stylistic tone** explicitly.
- Tie the role to the **output norms** ("you cite sources", "you flag uncertainty").
- Avoid theatrical roles ("you are a wizard") — they leak into outputs.

## 4. Few-shot examples

Two to five high-quality examples beat ten mediocre ones.

```xml
<examples>
<example>
<input>The login button doesn't work on Safari.</input>
<output>
{"category": "bug", "severity": "high", "platforms": ["safari"]}
</output>
</example>

<example>
<input>Could we add dark mode?</input>
<output>
{"category": "feature_request", "severity": "low", "platforms": []}
</output>
</example>
</examples>
```

- Cover the **edge cases** you actually see in production, not just the happy path.
- Show the **exact output shape** you want — Claude mimics format faithfully.
- Keep examples short; truncate or summarize inputs when they would dwarf the instructions.

## 5. Chain-of-thought / extended thinking

When the task involves multi-step reasoning, give Claude room to think before answering.

Lightweight CoT:

```
Think step-by-step inside <scratchpad> tags before giving your final answer
inside <answer> tags. Do not skip the scratchpad.
```

Extended thinking (Claude 4.x with the `thinking` parameter enabled):

- Turn it on for math, planning, debugging, and long-horizon tasks.
- Keep it off for short factual queries or tight-latency UX paths.
- Never instruct Claude to "show its thinking" in the visible answer when extended thinking is on — the API gives you a dedicated `thinking` block.

## 6. Output formatting

Pick **one** format and lock it down.

**Strict JSON**

```
Respond ONLY with valid JSON matching this schema. No prose, no code fences:
{"summary": "string", "issues": [{"file": "string", "line": "int"}]}
```

**Tool / structured output (preferred)** — define a tool with the exact schema and let Claude call it. The API enforces validity for you.

**Markdown sections**

```
Format your response with these sections, in order:
## Summary
## Findings
## Recommendations
```

Avoid mixing formats — "JSON plus a friendly note" produces unparseable hybrids.

## 7. Refusal & uncertainty handling

Tell Claude what to do when it shouldn't or can't answer.

```
If the context does not contain the answer, respond with exactly:
{"status": "insufficient_context", "missing": ["what you'd need"]}

If the request asks you to do something outside <task>, respond with:
{"status": "out_of_scope", "reason": "..."}
```

Explicit fallbacks beat ambient "be safe" instructions — they give downstream code a deterministic branch to handle.

## 8. Prompt caching layout

To maximize cache hits, order content from **most stable** to **most volatile**:

```
system:
  [stable] role + policies
  [stable] retrieved docs / knowledge base
  [volatile] per-request context
user:
  [volatile] the actual query
```

- Mark the cache breakpoint at the boundary between stable and volatile.
- Keep stable blocks byte-for-byte identical across requests — even whitespace changes invalidate the cache.
- Caches have a TTL (5 min default, 1 hour extended). Refresh hot prompts on a schedule rather than letting them expire and rebuild under load.
- See the `claude-api` skill for end-to-end caching recipes.
