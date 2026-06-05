# Agent Architecture Reference

> Cross-skill reference material for designing LLM agents. Individual Skills should link sections here instead of restating the theory.

## Table of Contents

1. [What counts as an agent](#1-what-counts-as-an-agent)
2. [The tool-use loop](#2-the-tool-use-loop)
3. [Tool design](#3-tool-design)
4. [Planning](#4-planning)
5. [Memory](#5-memory)
6. [Multi-agent orchestration](#6-multi-agent-orchestration)
7. [Stop conditions & safety](#7-stop-conditions--safety)
8. [Observability](#8-observability)
9. [Common failure modes](#9-common-failure-modes)

---

## 1. What counts as an agent

An **agent** is an LLM that runs in a loop, choosing tools to take actions in an environment until a goal is met or a stop condition fires. The minimum surface area:

- A **model** with tool-use capability.
- A set of **tools** with typed schemas.
- A **loop** that feeds tool results back into the model.
- A **stop condition** (goal reached, budget exhausted, error).

Workflows that hard-code the tool order are not agents — they are pipelines. Reach for an agent only when the next action genuinely depends on prior results.

## 2. The tool-use loop

```
while not stopped:
    response = model(messages, tools=tools)
    if response.stop_reason == "end_turn":
        break
    for tool_call in response.tool_calls:
        result = execute(tool_call)
        messages.append(tool_result(tool_call.id, result))
```

- Append both the assistant's tool-use block **and** the tool_result back into the message list — losing either breaks the conversation.
- Cap the loop with a **hard turn limit** (e.g. 25) and a **token budget**. Both should fail loudly, not silently truncate.
- For long-running agents, persist `messages` after every turn so you can resume on crash.

## 3. Tool design

- Name tools by **action verbs**, not noun categories (`search_docs`, not `docs`).
- Write tool **descriptions** as if for a junior engineer: when to use, when NOT to use, input semantics, output shape.
- Keep input schemas **flat and required-only** where possible — optional sprawl invites hallucinated arguments.
- Return **structured** results (JSON) with stable field names; avoid free-form prose unless the next step is reading.
- For long outputs, return a **summary plus a handle** (id, path) the agent can use to fetch detail on demand — don't dump everything into context.
- Co-locate tool error handling: return `{ok: false, error: "..."}` rather than throwing, so the agent can decide whether to retry, change tactic, or give up.

## 4. Planning

Three common patterns:

- **No plan (reactive)**: cheapest; works when each turn's choice is locally obvious. Most short tasks.
- **Single up-front plan**: ask the model to outline steps before tool use; useful for multi-step research / debugging. Risk: plans go stale.
- **Plan-and-replan**: re-issue a planning turn at checkpoints. Heavier; needed for open-ended environments where surprises are routine.

Tip: When you do plan, force the plan into a **structured output** (JSON list of steps with rationale) so downstream code can inspect and gate on it.

## 5. Memory

- **Working memory** = the message list. Bounded by context window. Apply summarization or selective dropping when it grows.
- **Episodic memory** = persisted summaries of past sessions, keyed by user / task. Inject the most relevant items into the next session's system prompt.
- **Semantic memory** = a retrievable knowledge base of distilled facts. Usually backed by the same vector store as RAG; see [rag-patterns](rag-patterns.md).
- Never silently overwrite memory. Make writes explicit (a tool the agent calls) so they appear in traces.

## 6. Multi-agent orchestration

Patterns, from simplest to most complex:

- **Single agent, many tools** — strongly prefer this. Coordination overhead is the #1 multi-agent killer.
- **Supervisor / worker** — one orchestrator delegates to specialized sub-agents. Use when sub-tasks are heterogeneous **and** parallelizable.
- **Pipeline of agents** — fixed hand-off (research → write → critique). Use when stages are well-defined and the hand-off contract is stable.
- **Debate / panel** — N agents produce candidates, a judge picks. Use for high-stakes generation where diversity beats single-shot quality.

Rules of thumb:

- Each agent boundary is a **context boundary** — what crosses must be explicit (a structured message), not implicit (shared state).
- Run sub-agents in parallel when their tasks are independent; serialize when later steps depend on earlier outputs.
- A shared **token budget** prevents any one agent from starving the others.

## 7. Stop conditions & safety

- Always set both `max_turns` and `max_tokens` on the loop.
- Detect **action loops** (same tool + arguments three turns in a row) and break out — usually the agent is stuck.
- Gate destructive actions (write, delete, send, pay) behind explicit confirmation, even when the agent has the tool.
- Sandbox shell / code execution. Strip credentials from logged tool results before persisting traces.

## 8. Observability

Minimum trace per turn:

- Turn number, model id, input/output token counts.
- Full message list (input) and assistant content (output).
- Each tool call: name, arguments, result, latency, error.
- Stop reason and total cost.

Aggregate: time-to-goal, turns-to-goal, tool-call frequency, error rate per tool, replan rate.

When you can't reproduce a failure, you can't fix it — trace from day one.

## 9. Common failure modes

- **Tool spam**: agent keeps calling search variants instead of answering. Tighten tool descriptions; add a "have enough info?" reflection step.
- **Hallucinated tool arguments**: schemas too loose, or examples missing. Add 1–2 in-description examples per tool.
- **Context bloat**: tool results accumulate. Summarize or use the "handle + fetch" pattern.
- **Silent goal drift**: the agent forgets the original goal mid-conversation. Re-inject the goal in the system prompt; consider a planning checkpoint.
- **Cascading errors in pipelines**: stage N+1 trusts stage N's output structurally. Validate hand-offs with schemas.
- **Reward hacking**: with judge-based loops, the agent learns the judge's blind spots. Rotate / ensemble judges.
