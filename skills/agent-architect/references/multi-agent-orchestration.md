# Multi-Agent Orchestration

> Reference companion to `../SKILL.md` Phase 2 and `agent-patterns.md` §6. How to actually coordinate multiple agents without the system collapsing under its own weight.

## The One Rule

> **Every agent boundary is a context boundary. What crosses it must be explicit (a structured message), not implicit (shared state).**

If you cannot name exactly what message crosses from agent A to agent B, your design will leak state, race on writes, and become impossible to debug.

## Decision Table

| Pattern | Sub-task shape | Latency | Use when |
| --- | --- | --- | --- |
| **Supervisor** | Heterogeneous, sequential handoff | Sequential (≈ sum) | One orchestrator, several specialists |
| **Hierarchical** | Heterogeneous, recursive decomposition | Sequential (≈ sum of branches) | Each sub-task is itself a multi-agent problem |
| **Peer-to-Peer** | Homogeneous, parallelizable | Parallel (≈ max) | Several agents doing the same kind of work, vote or ensemble |
| **Debate** | Homogeneous, quality-critical | Parallel (≈ max) + judge | High-stakes final answer; quality > cost |

Prefer **single agent with many tools** over any of these. Reach for multi-agent only when one agent clearly cannot do the job.

---

## 1. Supervisor Pattern

One orchestrator agent delegates to N specialist agents. Specialists report back; the supervisor decides what to do next.

### Architecture

```text
                     user
                       │
                       ▼
              ┌────────────────┐
              │  Supervisor    │
              │ (planner /     │
              │  router)       │
              └───┬─────┬──────┘
                  │     │
        ┌─────────┘     └────────┐
        ▼                        ▼
   [Researcher]            [Writer]
        │                        │
        └─► structured report ◄──┘
                  │
                  ▼
              Supervisor
                  │
                  ▼
                final
```

### State passing

- **Down** (supervisor → specialist): a typed `Task` object (`{goal, context, constraints, deadline}`). Not free text.
- **Up** (specialist → supervisor): a typed `Result` object (`{summary, artifacts, confidence, followups}`). Not free text.
- **No shared mutable state** between specialist and supervisor. Communication is message passing only.

### Conflict resolution

- Specialists return a `confidence` score (0–1). Supervisor picks the highest-confidence answer.
- If two specialists disagree above a threshold, escalate to the supervisor's own LLM as tiebreaker.
- The supervisor never overrides a specialist on **specialist-domain facts**; only on **routing decisions**.

### Example

```python
class SupervisorState(TypedDict):
    task: Task
    results: list[SpecialistResult]
    next_step: str

def supervisor_node(state: SupervisorState) -> SupervisorState:
    plan = planner(state.task, state.results)
    chosen = plan.next_specialist
    new_result = SPECIALISTS[chosen].run(plan.subtask)
    return {"results": [*state.results, new_result], "next_step": plan.next}
```

### When to use

- The work decomposes into a small number of named roles (researcher / writer / critic).
- Specialists are independent — no need for them to talk to each other directly.
- The supervisor's job is well-defined: plan, route, synthesize.

---

## 2. Hierarchical Pattern

Supervisor pattern, recursively. A top-level supervisor delegates to mid-level supervisors, which delegate to leaf specialists.

### Architecture

```text
                         user
                           │
                           ▼
                    [Top Supervisor]
                           │
                ┌──────────┼──────────┐
                ▼          ▼          ▼
          [Eng Mgr]  [Research Mgr]  [QA Mgr]
                │          │             │
                ▼          ▼             ▼
            [Eng agents] [Researchers] [Testers]
```

### When to use

- A sub-task is itself complex enough to need its own multi-agent decomposition.
- A large product is being modeled (e.g. SWE-Bench style: "design → code → test" each as a sub-supervisor).

### Cost

- **Communication cost dominates.** Each boundary is a serialization point. Three levels of supervision × five specialists = 15+ message hops per task.
- Limit depth: in practice, 2 levels is almost always enough; 3 is the practical max.

### Hard rules

- Each level has a **typed contract** with the level above. Never free text.
- No level can call a level 2 below it. If it needs to, it must go through the intermediate.
- The top supervisor is the only one that ever sees the user.

---

## 3. Peer-to-Peer Pattern

N agents of the same type run in parallel on the same task; their outputs are combined (vote, ensemble, or RRF-style rank fusion).

### Architecture

```text
         task
           │
     ┌─────┼─────┐
     ▼     ▼     ▼
   [A]   [B]   [C]   (same role, possibly different prompts)
     │     │     │
     └─────┼─────┘
           ▼
       [Combiner]
           │
           ▼
         final
```

### State passing

- All peers receive the **same** typed input.
- They produce **the same shape** of typed output.
- The combiner aggregates.

### Conflict resolution

- For classification: majority vote, breaking ties randomly but reproducibly (seeded).
- For generation: pick the highest self-reported confidence, OR use a judge model on the candidates.
- For ranking: RRF (reciprocal rank fusion) is the default; works without training.

### Load balancing

- The "load" is bounded by the number of peers you spawn, not the workload.
- Use this pattern when **diversity** (different prompts / temperatures / models) is the goal, not throughput.
- For raw throughput, you want one agent with replicas, not a peer pattern.

### Example (ensemble judge)

```python
def peer_ensemble(task: str, n: int = 3) -> str:
    candidates = [
        llm_call(task, temperature=0.2 + i * 0.3, model=MODELS[i % len(MODELS)])
        for i in range(n)
    ]
    scores = [judge(task, c) for c in candidates]
    return candidates[max(range(n), key=lambda i: scores[i])]
```

---

## 4. Debate Pattern

N agents argue, see each other's positions, and update. End with a judge or a final round of voting.

### Architecture

```text
   round 1:  A₀ ──► answer₀
             B₀ ──► answer₀
             C₀ ──► answer₀
                       │
   round 2:  A₁ ◄──────┤  (sees others' round 1)
             B₁ ◄──────┤
             C₁ ◄──────┘
                       │
                  [Judge / vote]
                       │
                     final
```

### State passing

- Each round, every agent receives the **current task + all prior answers from other agents**.
- After K rounds (usually 2–3), a judge picks the best.

### Conflict resolution

- Pure debate without a judge degrades into groupthink.
- A small judge model (often Haiku-class) over the final round is the standard.
- To prevent **reward hacking on the judge**, rotate the judge every run OR ensemble judges.

### When to use

- Final-draft generation where quality is paramount.
- Tasks where independent perspectives catch real errors (legal review, complex reasoning).

### Cost

- 3 agents × 3 rounds = 9 LLM calls per task. Plus the judge. This is 10× the cost of a single agent.
- Reserve for: the very last step of a pipeline, or for batch/offline use.

---

## Cross-Cutting Concerns

### Token budget

Multi-agent systems have a tendency to consume tokens exponentially. Put a hard shared budget at the supervisor level and check before every sub-agent call.

```python
def supervisor_can_delegate(state, budget: Budget) -> bool:
    if budget.remaining() < MIN_PER_SUBAGENT:
        return False
    return True
```

### State isolation

Multiple users hitting the same agent instance must have **isolated state**. Encode this in the type:

```python
class AgentRun(BaseModel):
    run_id: str
    user_id: str
    thread_id: str
    state: TypedState
```

Never carry `user_id` implicitly through module-level globals.

### Deadlocks

Two agents waiting on each other is rare but possible. Always set a per-message timeout; treat timeouts as failures with structured errors.

### Tracing

Every boundary emits a trace event. Tools: **Langfuse**, **LangSmith**, **OpenTelemetry GenAI semconv**. Required fields: `parent_run_id`, `run_id`, `agent_role`, `messages_in`, `messages_out`, `tool_calls`, `latency_ms`, `cost_usd`.

### Evaluation

Multi-agent evaluation is harder than single-agent. Track per-agent success rate AND end-to-end success rate. A weak specialist masked by a strong supervisor is the most common silent failure.
