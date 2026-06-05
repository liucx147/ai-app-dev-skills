# Agent Patterns

> Reference companion to `../SKILL.md` Phase 2. Six patterns, each with an architecture diagram, pseudocode, pros / cons, and "use when" guidance. Read the decision tree in `../SKILL.md` first to pick; come here for the implementation recipe.

## TL;DR Decision Table

| Pattern | Best for | Latency cost | Replan on failure? | Multi-agent? | Long-running? |
| --- | --- | --- | --- | --- | --- |
| **ReAct** | Single-step, ≤ 5 tools, fast answers | Low | No (loop) | No | No |
| **ReAct + Tool Router** | Many tools, only a few relevant per turn | Low–Medium | No (loop) | No | No |
| **Plan-and-Execute** | Linear-ish workflows, distinct tool per step | Medium | Yes (replan) | No | Optional |
| **LATS** | Open-ended exploration, no clear right answer | High (5–50×) | Yes (backtrack) | Optional | No |
| **Reflexion** | Tasks where one-shot fails often | Medium | Yes (reflect) | No | No |
| **Multi-Agent Debate** | High-stakes generation, quality > cost | High | N/A (multi-pass) | Yes (peers) | No |
| **Hierarchical Multi-Agent** | Heterogeneous sub-tasks, true parallelism | High | N/A | Yes (tree) | Optional |

If you have no other information: start with **ReAct**, measure, then escalate.

---

## 1. ReAct (Reason + Act)

The original single-agent loop. The model emits a thought, a tool call, observes the result, and repeats until it has enough to answer.

### Architecture

```text
       ┌────────────┐
       │   user     │
       └─────┬──────┘
             ▼
      ┌────────────────┐    tool result
      │  ReAct loop    │◄────────────────┐
      │  ┌──────────┐  │                 │
      │  │ thought  │  │                 │
      │  │ act      │──┼──► execute ─────┘
      │  │ observe  │  │
      │  └──────────┘  │
      └────────┬───────┘
               ▼
            finish
```

### Pseudocode

```python
def react_agent(task, tools, max_turns=10):
    messages = [{"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user",   "content": task}]
    for turn in range(max_turns):
        msg = llm_call(messages, tools=tools)
        messages.append(msg)
        if msg.stop_reason == "end_turn":
            return msg.content
        for tc in msg.tool_calls:
            result = execute(tc)        # NEVER let this raise
            messages.append(tool_result(tc.id, result))
    return "I could not complete this in the allowed turns."
```

### Pros

- Simplest possible agent. Trivial to debug, trace, and unit-test.
- No additional state to manage beyond the message list.
- Excellent for tasks that fit in one straight reasoning chain.

### Cons

- Cannot backtrack once a tool result is in. Wrong turn = stuck or hallucination.
- Tool call accuracy degrades fast as the toolset grows past ~7.
- No mechanism to plan-then-execute; re-decides every turn.

### When to use

- Single-step lookups, factual Q&A, structured-data CRUD.
- ≤ 5 tools, all obvious from the task description.
- p95 latency target under 30 seconds.

---

## 2. ReAct + Tool Router

Pre-filter the toolset to a small relevant subset, then run a normal ReAct loop over that subset.

### Architecture

```text
    user ──► [Router] ──► top-K tools ──► [ReAct loop over those tools] ──► finish
               │
               └─ LLM judge OR embedding similarity OR rules
```

### Pseudocode

```python
def routed_react(task, all_tools, k=5, max_turns=10):
    chosen = tool_router(task, all_tools, k=k)
    return react_agent(task, chosen, max_turns=max_turns)

def tool_router(task, all_tools, k):
    # Cheap embedding-similarity path:
    return top_k_by_cosine(embed(task), [embed(t.description) for t in all_tools], k=k)
    # Or LLM judge:
    # return llm_pick_tools(task, all_tools, k=k)
```

### Pros

- Scales ReAct to 50+ tools by giving the loop a focused subset.
- Router is independent and can be tuned / cached separately.
- The router's own output is a useful trace artifact.

### Cons

- Two failure modes now: router error + agent error.
- Router latency adds to every turn.

### When to use

- 20+ tools in the registry; per turn only 2–5 are relevant.
- Toolset is stable enough that embedding the descriptions once pays off.

---

## 3. Plan-and-Execute

Generate an explicit plan up front, then execute steps one by one. Replan on failure.

### Architecture

```text
    user ──► [Planner] ──► plan: [step1, step2, step3, ...]
                          │
                          ▼
                    [Executor loop] ──► step1 ──► step2 ──► ...
                          │              ▲
                          │              └── on failure: replan from current state
                          ▼
                        finish
```

### Pseudocode

```python
def plan_and_execute(task, tools, replanner):
    plan = planner(task, available_tools=tools)         # ["step A", "step B", ...]
    history = []
    for step in plan:
        result = execute_step(step, history, tools)
        history.append(result)
        if result.failed:
            plan = replanner(task, plan, history, tools)
            history = []                                  # or keep and re-plan only remaining
    return synthesize(history)
```

### Pros

- Plans are inspectable, evaluable, and re-usable as prompts.
- Replan on failure is a real safety net for flaky tools.
- Cleanly separates "what to do" from "how to do it."

### Cons

- Replanning thrashes on non-deterministic tasks.
- Cost of two LLM calls per turn (executor + occasional replanner).

### When to use

- Workflows where steps are mostly linear but tool calls can fail.
- Coding agents, multi-API research, anything resembling a pipeline.

---

## 4. LATS (Language Agent Tree Search)

Expand the state tree, score branches with an evaluator, and backpropagate the best score. Use when there is no clear right answer and compute budget is large.

### Architecture

```text
                                  ┌──► [score 0.3]
                ┌── action A ──────┤
                │                  └──► [score 0.7]
    state ──────┤
                │                  ┌──► [score 0.2]
                └── action B ──────┤
                                   └──► [score 0.6]   ← best
```

### Pseudocode

```python
def lats(task, tools, n_expand=3, depth=5):
    root = Node(state=task)
    for _ in range(depth):
        leaves = root.leaves()
        for leaf in leaves:
            for _ in range(n_expand):
                action = expander(leaf, tools)
                child = leaf.expand(action)
                child.score = evaluator(child)
                leaf.backprop(child.score)
    return root.best_path()
```

### Pros

- Best of breed for open-ended exploration; can find non-obvious solutions.
- Tree search is naturally self-correcting.

### Cons

- 5–50× more LLM calls than ReAct. Expensive in both time and money.
- Implementation complexity is real; off-the-shelf support is thin.
- Hard to debug without careful tree visualization.

### When to use

- Mathematical reasoning, complex planning, code where the search space is large.
- Latency budget is minutes, not seconds. Compute budget is generous.

---

## 5. Reflexion

A ReAct loop that adds an **explicit self-reflection step** after a failed attempt, then retries with the reflection baked into memory.

### Architecture

```text
   attempt 1 → fail ──► reflect ──► attempt 2 → fail ──► reflect ──► attempt 3 → success
                                              │                       │
                                              └── memory ◄───────────┘
```

### Pseudocode

```python
def reflexion(task, tools, max_trials=3):
    memory = []
    for trial in range(max_trials):
        result = react_agent(task, tools, context=memory)
        if is_success(result):
            return result
        reflection = reflector(task, result, memory)
        memory.append(reflection)
    return "Failed after max trials."
```

### Pros

- Cheap boost (≈ +10–20% success) on tasks where one-shot is the dominant failure mode.
- Reflection log is itself a debugging artifact.

### Cons

- Doubles LLM calls per failed trial.
- The reflector can hallucinate causes; calibrate with held-out traces.

### When to use

- Code generation, SQL synthesis, anything where a quick retry-with-context usually helps.

---

## 6. Multi-Agent Debate

Spawn N independent agents (often with different role prompts or temperatures), collect their outputs, and have a judge (a fourth model, or a small heuristic) pick the best.

### Architecture

```text
    user ──► [Agent A] ──► answer A ─┐
            [Agent B] ──► answer B ──┼──► [Judge] ──► final
            [Agent C] ──► answer C ──┘
```

### Pros

- Diversity from different prompts / temperatures / models catches failure modes a single pass misses.
- Strong on high-stakes generation (final draft, decision support).

### Cons

- 3–5× cost of single-agent.
- Judge becomes the new bottleneck and a new failure mode (reward hacking).

### When to use

- Final-answer generation where quality > cost.
- When the agents can run in parallel (latency stays single-pass).

### See also

`references/multi-agent-orchestration.md` §4 for judge design, prompt diversity, and anti-rotation patterns.

---

## 7. Hierarchical Multi-Agent

A supervisor at the top delegates to specialized sub-agents; sub-agents may themselves supervise other agents. Most powerful, most dangerous.

### Architecture

```text
                       user
                         │
                         ▼
                  ┌──────────────┐
                  │  Supervisor  │
                  └──────┬───────┘
            ┌────────────┼────────────┐
            ▼            ▼            ▼
       [Researcher] [Writer]  [Critic]
            │            │            │
            └── each may call its own tools and/or sub-agents
```

### Pros

- Cleanly models real organizational structure; each agent is testable in isolation.
- True parallelism for independent sub-tasks.

### Cons

- Coordination overhead is the #1 failure mode. Every boundary is a context boundary; you must explicitly serialize what crosses.
- Debugging requires end-to-end traces.

### When to use

- Complex products with genuinely heterogeneous sub-tasks (research + writing + critique).
- After exhausting what a single agent with 20 tools can do.

### See also

`references/multi-agent-orchestration.md` for supervisor / hierarchical / peer / debate patterns in detail.

---

## Cross-Cutting Rules

- **Always set hard limits**: `max_turns`, `max_tokens`, `max_cost_per_task`, `max_wall_clock`. All four; all enforced server-side.
- **Detect action loops**: same tool + same args 3 turns in a row → break out and reflect.
- **Wire observability from day one** (Langfuse, LangSmith). Retro-fitting it after a production failure is painful.
- **Test the tool descriptions, not just the model.** A description rewrite can move success rates 20+ points; that is product, not engineering.
- **Start at the smallest pattern that could possibly work** (ReAct). Escalate only when the eval data forces it.
