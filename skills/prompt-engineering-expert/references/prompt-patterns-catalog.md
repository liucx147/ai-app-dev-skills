# Prompt Patterns Catalog

> Reference companion to `../SKILL.md` Phase 2. 25 patterns, each with a minimal template, a "use when" line, and the most common gotcha. Pick the smallest pattern that hits the spec.

## Index

| # | Pattern | Primary use |
| --- | --- | --- |
| 1 | Zero-shot | Default for simple, well-specified tasks |
| 2 | Few-shot | Output shape is hard to specify in words |
| 3 | Chain-of-Thought (CoT) | Multi-step reasoning required |
| 4 | Zero-shot CoT | Reasoning on tasks with no examples |
| 5 | Self-Consistency | High-stakes single answer |
| 6 | Tree-of-Thought (ToT) | Open-ended search over thoughts |
| 7 | ReAct | Tool use + reasoning in one loop |
| 8 | Self-Refine | Iterative single-pass improvement |
| 9 | Reflexion | Retry with reflection after failure |
| 10 | Program-aided (PAL) | Math / data — write code instead of calculating |
| 11 | Structured Output | Constrained JSON / schema |
| 12 | Tool Use (function calling) | Model calls external functions |
| 13 | Role Priming | Domain-anchored behavior |
| 14 | Constitutional AI | Self-critique against principles |
| 15 | Meta-Prompting | Ask the LLM to write the prompt |
| 16 | Prompt Chaining | Sequence of prompts, each consumes the prior output |
| 17 | Routing | Send request to specialist prompt |
| 18 | Parallelization | Fan-out, then aggregate |
| 19 | Orchestrator-Workers | Supervisor dispatches heterogeneous tasks |
| 20 | Plan-and-Execute | Plan first, then execute step by step |
| 21 | RAG Prompting | Context-augmented answers with citations |
| 22 | Generated Knowledge | Generate facts first, then answer |
| 23 | Active Prompting | Ask clarifying questions when info is missing |
| 24 | Step-Back Prompting | Derive a general question, retrieve, then answer |
| 25 | Multi-modal Prompting | Vision / audio inputs alongside text |

---

## 1. Zero-shot

```text
You are a <ROLE>. You <DO_THING>.
Rules:
- ...
- ...

Input: {{user_input}}
Output:
```

- **Use when**: the task is well-specified and the model already knows the format (translation, simple classification, summarization).
- **Gotcha**: vague instructions. "Be helpful" is not a spec.

## 2. Few-shot

```text
You are a <ROLE>.

Example 1:
Input: <input_1>
Output: <output_1>

Example 2:
Input: <input_2>
Output: <output_2>

Now do the same for:
Input: {{user_input}}
Output:
```

- **Use when**: the output shape is easier shown than described.
- **Gotcha**: examples that contradict the system prompt. Pick one at random = the model picks one at random.

## 3. Chain-of-Thought (CoT)

```text
You are a <ROLE>. Think step by step inside <scratchpad> tags.
Output the final answer inside <answer> tags.

{{user_input}}
```

- **Use when**: multi-step math, logic, or planning.
- **Gotcha**: exposing the scratchpad to end users. Strip or summarize before display.
- **Tip**: with extended-thinking models, prefer the `thinking` parameter over an in-prompt scratchpad.

## 4. Zero-shot CoT

```text
{{user_input}}

Think step by step.
```

- **Use when**: no examples, but reasoning helps. Cheapest CoT.
- **Gotcha**: can drift into a long preamble. Add a hard token limit on the scratchpad.

## 5. Self-Consistency

```python
# Sample N times at temperature > 0, take the majority answer.
answers = [llm(prompt, temperature=0.7) for _ in range(5)]
final  = majority(answers)
```

- **Use when**: classification, math, factual lookup where a wrong answer is expensive.
- **Gotcha**: cost (5–10×). Only for high-stakes calls.

## 6. Tree-of-Thought (ToT)

```text
For each of the following candidate approaches, evaluate and pick the best:
1. <approach A> — <one-line trade-off>
2. <approach B> — ...
3. <approach C> — ...

For the chosen approach, expand one more level of detail.
```

- **Use when**: planning, design, problem-solving with branching strategies.
- **Gotcha**: implementation complexity. Use a framework (LangGraph) before hand-rolling.

## 7. ReAct

```text
You are a <ROLE> with access to these tools: {{tools}}.

For each turn:
1. Decide: do I have enough to answer, or do I need a tool call?
2. If tool: emit a tool call, observe the result, continue.
3. If enough: emit the final answer.

{{user_input}}
```

- **Use when**: tool use is the core of the task. The dominant agent pattern.
- **Gotcha**: unbounded loops. Always cap with `max_turns` server-side.

## 8. Self-Refine

```text
1. Draft an answer to {{user_input}}.
2. Critique the draft: what is weak, missing, or wrong?
3. Rewrite the draft addressing every critique.
4. Repeat steps 2–3 up to N times, stopping when no new critique appears.
```

- **Use when**: open-ended generation where one-shot is poor.
- **Gotcha**: drift. The rewrite can lose the original constraint; pin the spec in the system message and re-inject each iteration.

## 9. Reflexion

```text
You are a <ROLE>. If your first attempt fails, write a one-paragraph
reflection on why it failed, then retry with the reflection in mind.
Store the reflection for use on the next attempt.

{{user_input}}
```

- **Use when**: code generation, SQL synthesis — anywhere "quick retry-with-context" usually helps.
- **Gotcha**: reflection hallucinations. Calibrate with held-out traces.

## 10. Program-aided (PAL)

```text
Solve the following by writing a short Python program. Return only the code.

{{user_input}}
```

- **Use when**: arithmetic, data transformation, anything you can express as a function.
- **Gotcha**: model emits prose around the code. Force "code only" output, then execute in a sandbox.

## 11. Structured Output

```text
You are a <ROLE>. Respond ONLY with valid JSON matching this schema:
{{schema}}

Do not include prose, code fences, or commentary.

{{user_input}}
```

- **Use when**: downstream code consumes the output. **The default for production.**
- **Gotcha**: when using tool-calling / JSON-mode in the API, the schema is enforced — do not double-prompt.

## 12. Tool Use (function calling)

```python
# In the API call, pass a list of tool definitions; the model emits tool calls.
# In the loop, append the tool result back to the message list.
```

- **Use when**: the model needs to call a real function (search, DB, HTTP, code-exec).
- **Gotcha**: tool descriptions are products, not docs. Invest in them; they drive accuracy.

## 13. Role Priming

```text
You are a senior <DOMAIN> engineer with 10 years of experience.
You speak directly, never speculate when you can verify, and you cite sources.
```

- **Use when**: domain-anchored behavior matters (legal, medical, finance, code review).
- **Gotcha**: theatrical roles ("you are a wizard") leak into outputs. Keep it grounded.

## 14. Constitutional AI

```text
Draft an answer to {{user_input}}.
Then critique it against these principles:
  1. {{principle_1}}
  2. {{principle_2}}
  3. {{principle_3}}
Rewrite the answer to address every critique. If a critique cannot be
addressed, explain why and stop.
```

- **Use when**: you need principled self-correction (no hard-coded rules, but bounded behavior).
- **Gotcha**: principles that are vague. "Be helpful" is not a principle; "Never recommend dosage changes for prescription drugs" is.

## 15. Meta-Prompting

```text
# Step 1: ask the LLM to write the prompt
PROMPT_GENERATOR = """
You are a prompt engineer. Given a task spec, write a single, runnable
prompt that solves it. Output only the prompt text.
"""
generated = llm(PROMPT_GENERATOR + spec)

# Step 2: use the generated prompt on real data
real_answer = llm(generated + user_input)
```

- **Use when**: stable task across many call sites, and the prompt is worth designing once.
- **Gotcha**: you have not measured. A generated prompt is a hypothesis. Run it through the eval set.

## 16. Prompt Chaining

```python
step1 = llm(PROMPT_1 + input)
step2 = llm(PROMPT_2 + step1)
step3 = llm(PROMPT_3 + step2)
```

- **Use when**: a single prompt would be too long, or each step needs its own context / model.
- **Gotcha**: error compounding. 95% × 95% × 95% = 86%. Track per-step accuracy.

## 17. Routing

```python
# A small classifier picks which specialist prompt to run.
intent = classifier(user_input)
answer = llm(ROUTER_PROMPTS[intent] + user_input)
```

- **Use when**: a single prompt tries to do too much; split by intent.
- **Gotcha**: router accuracy. If the router is 80% right, the specialist is irrelevant for 20% of traffic.

## 18. Parallelization

```python
# Fan out, then aggregate.
results = await asyncio.gather(*[llm(PROMPT + x) for x in inputs])
final   = aggregator(results)
```

- **Use when**: independent sub-tasks, latency matters, sub-tasks are well-defined.
- **Gotcha**: aggregating requires a defined contract. If each `result` is free-form prose, aggregation is hopeless.

## 19. Orchestrator-Workers

```text
You are an orchestrator. Given {{user_input}}, decompose it into
sub-tasks, assign each to a worker, and synthesize the final answer
from the workers' outputs.
```

- **Use when**: heterogeneous sub-tasks, true parallelization possible, output quality > cost.
- **Gotcha**: the #1 over-engineering trap. One well-tooled agent usually beats a small army of specialists.

## 20. Plan-and-Execute

```text
Step 1: produce a plan (numbered list of steps).
Step 2: execute each step in order, using the available tools.
Step 3: if a step fails, replan from the current state.
```

- **Use when**: linear-ish workflows, each step is a distinct tool, replan-on-failure is acceptable.
- **Gotcha**: replan thrashes on non-deterministic tasks. See `../agent-architect/` Skill for the full pattern.

## 21. RAG Prompting

```text
You are a <ROLE>. Use the context below to answer. Cite the source id
for every factual claim. If the context does not contain the answer,
respond with {{REFUSAL}}.

<context>
{{retrieved_chunks_with_ids}}
</context>

Question: {{user_input}}
```

- **Use when**: any task over a private corpus. Default for knowledge-base Q&A.
- **Gotcha**: lost-in-the-middle. Cap context length; rerank aggressively.

## 22. Generated Knowledge

```text
Step 1: write 3–5 facts that would help answer this question.
Step 2: use those facts as additional context to answer.

Question: {{user_input}}
```

- **Use when**: the model lacks domain knowledge in its weights and you cannot RAG.
- **Gotcha**: hallucinated facts. Only useful for general-domain reasoning; never for specific facts.

## 23. Active Prompting

```text
You are a <ROLE>. If the user's input is missing information needed
to answer, ask the most important clarifying question first. Otherwise,
answer.

{{user_input}}
```

- **Use when**: sparse user input, ambiguous intent, regulated decisions.
- **Gotcha**: asking too many questions. One question, then answer if it is still missing.

## 24. Step-Back Prompting

```python
general   = llm("Derive one more general question whose answer would "
               "provide useful background for: " + user_input)
context   = retrieve(general)
special   = llm("Use this context to answer: " + user_input, context=context)
```

- **Use when**: reasoning questions where the model needs principles, not just facts.
- **Gotcha**: doubles retrieval cost. Use only when the specific-question retrieval is missing background.

## 25. Multi-modal Prompting

```text
You are a <ROLE>. The user has supplied an image and a question.
Describe what you see relevant to the question, then answer.

[image: {{image_url}}]
Question: {{user_input}}
```

- **Use when**: the input is not text (screenshot, photo, chart, document scan).
- **Gotcha**: model invents text. Quote only what OCR / VLM actually read; never paraphrase "the chart says X" without verification.

---

## Cross-Cutting Rules

- **Default to Structured Output** (pattern 11) for anything that feeds downstream code.
- **Default to ReAct** (pattern 7) for anything with tools. Other agent patterns (20, 8, 9) are variants.
- **Default to a 200-word system prompt**. Expand only with a measured reason; trim aggressively otherwise.
- **Always pin the model version** in the eval report. Behavior changes silently across versions.
- **Always cache the stable prefix** (system + retrieved context boundary). Order content from most-stable to most-volatile.
- **Always evaluate on a held-out set**. Vague "it works for my examples" is not a release bar.
