# Retrieval Optimization

> Reference companion to `../SKILL.md` Phase 2 and Phase 4. Stack these techniques in order of cost: try the cheap ones first, measure, and only add the next when the evals say you need it.

## Pipeline Anatomy

```
user query
   │
   ▼
[query transformation]   ← cheap, high leverage
   │
   ▼
[hybrid retrieval]       ← BM25 + vector + RRF
   │
   ▼
[reranking]              ← cross-encoder or LLM judge
   │
   ▼
[contextual compression] ← optional, before the LLM
   │
   ▼
LLM with cited context
```

Every stage is opt-in. The cheapest pipeline that hits your eval target is the right one.

---

## 1. Query Rewriting

Reformulate the raw user query into one optimized for retrieval — expand abbreviations, resolve pronouns, add likely synonyms, drop chitchat.

### When it helps

- Conversational interfaces where context is implicit ("what about the second one?").
- Short or terse queries ("auth bug?").
- Domains with heavy jargon / abbreviations.

### Recipe

```python
import anthropic

REWRITE_PROMPT = """You rewrite user queries for a retrieval system over <DOMAIN>.

Rules:
- Resolve pronouns and references using the prior turns.
- Expand abbreviations and acronyms.
- Drop chitchat; keep only the information-seeking core.
- Output ONLY the rewritten query, no preamble.

Conversation so far:
{history}

Latest user query:
{query}

Rewritten query:"""

def rewrite_query(client: anthropic.Anthropic, history: str, query: str) -> str:
    msg = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=200,
        messages=[{"role": "user", "content": REWRITE_PROMPT.format(history=history, query=query)}],
    )
    return msg.content[0].text.strip()
```

Use a small fast model — Haiku-class. This runs on every query; latency matters.

---

## 2. HyDE (Hypothetical Document Embeddings)

Have the LLM generate a **hypothetical answer** to the query, then embed that synthetic answer and use it for retrieval instead of the raw question. Synthetic answers live in the same embedding space as your documents, so they retrieve more relevant chunks than terse questions do.

### When it helps

- Short queries ("difference between X and Y").
- Embedders that struggle with question-vs-answer asymmetry.
- Corpora where the user's vocabulary differs from the document's.

### When it doesn't

- Long, well-formed queries that already match document style.
- Latency-critical paths (adds one LLM call per query).

### Recipe

```python
HYDE_PROMPT = """Write a single-paragraph answer to the user's question as if you
were quoting from an authoritative <DOMAIN> document. Use the vocabulary and tone
of the source material. Do not include caveats or meta-commentary.

Question: {query}

Hypothetical passage:"""

def hyde_embedding(client, embedder, query: str) -> list[float]:
    msg = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=300,
        messages=[{"role": "user", "content": HYDE_PROMPT.format(query=query)}],
    )
    hypothetical = msg.content[0].text.strip()
    # Embed BOTH and average for robustness:
    return mean_pool([embedder(query), embedder(hypothetical)])
```

---

## 3. Multi-Query

Generate N paraphrases of the user's query, retrieve for each, and union the results (deduped). Covers more of the query's semantic neighborhood than a single embedding can.

### When it helps

- Open-ended exploratory questions.
- High-recall use cases where missing the right chunk is more expensive than retrieving extra noise.

### Cost

- N× embedding calls per query, N× retrieval calls.
- Mitigate by capping N at 3–4 and using batched embedding APIs.

### Recipe

```python
MULTIQUERY_PROMPT = """Rewrite the user's question in {n} different ways. Each
rewrite should preserve the original intent but use different vocabulary, phrasing,
or focus on a different angle. Output one rewrite per line, no numbering."""

def multi_query(client, query: str, n: int = 4) -> list[str]:
    msg = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=400,
        messages=[
            {"role": "user", "content": MULTIQUERY_PROMPT.format(n=n)},
            {"role": "assistant", "content": "Understood. Provide the question."},
            {"role": "user", "content": query},
        ],
    )
    return [line.strip() for line in msg.content[0].text.splitlines() if line.strip()][:n]
```

Combine results with **reciprocal rank fusion** (see §5) rather than naive set union — fusion preserves ranking signal.

---

## 4. Step-Back Prompting

Before answering, ask the LLM to derive a **more general** version of the question, retrieve for that, and add those chunks to the context. The general retrieval picks up background and definitional material the specific query misses.

### When it helps

- Reasoning questions where the model needs principles, not just facts.
- Domains where the answer requires combining a specific case with general framework.

### Recipe

```python
STEPBACK_PROMPT = """Given the specific user question, write one more general
question whose answer would provide useful background. Output only the general
question.

Specific: {query}
General:"""

def step_back_retrieval(client, retriever, query: str, k_specific: int = 5, k_general: int = 3):
    msg = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=120,
        messages=[{"role": "user", "content": STEPBACK_PROMPT.format(query=query)}],
    )
    general = msg.content[0].text.strip()
    specific_chunks = retriever(query, k=k_specific)
    general_chunks  = retriever(general, k=k_general)
    return specific_chunks + [c for c in general_chunks if c.id not in {s.id for s in specific_chunks}]
```

---

## 5. Reranking & Fusion

Retrieval gives you the **candidates**; reranking gives you the **order**. Three flavors, increasing cost:

### 5a. Reciprocal Rank Fusion (RRF)

Use when you have multiple ranked lists (BM25 + vector, multi-query, multiple embedders) and want to fuse them without training anything.

```python
def rrf(rank_lists: list[list[str]], k: int = 60) -> list[tuple[str, float]]:
    scores: dict[str, float] = {}
    for ranks in rank_lists:
        for position, doc_id in enumerate(ranks):
            scores[doc_id] = scores.get(doc_id, 0.0) + 1.0 / (k + position + 1)
    return sorted(scores.items(), key=lambda kv: kv[1], reverse=True)
```

`k=60` is the standard default. Cheap, robust, no model required.

### 5b. Cross-Encoder Reranker

A small transformer scores `(query, chunk)` pairs jointly — far more accurate than separate embeddings.

```python
from sentence_transformers import CrossEncoder

reranker = CrossEncoder("BAAI/bge-reranker-v2-m3", max_length=512)

def rerank(query: str, candidates: list[dict], top_k: int = 5) -> list[dict]:
    pairs = [(query, c["text"]) for c in candidates]
    scores = reranker.predict(pairs)
    ranked = sorted(zip(candidates, scores), key=lambda x: x[1], reverse=True)
    return [c for c, _ in ranked[:top_k]]
```

Recommended defaults:

| Model | Strength | Latency (GPU) |
| --- | --- | --- |
| `BAAI/bge-reranker-v2-m3` | Multilingual, strong default | ~5 ms / pair |
| `BAAI/bge-reranker-large` | English, slightly stronger | ~8 ms / pair |
| Cohere `rerank-3-multilingual` | Managed, no infra | ~50 ms RTT |

Always rerank the top 20–100 candidates down to top 3–10. Anything larger eats latency without help.

### 5c. LLM-as-Judge Reranker

A small LLM scores each `(query, chunk)` pair on a 1–5 scale; sort descending. Use only when cross-encoders underperform on your domain (rare) and budget allows.

Costs ~5–10× more than a cross-encoder; prefer cross-encoders by default.

---

## 6. Contextual Compression

Before handing chunks to the LLM, **trim each chunk** to only the spans relevant to the query. Reduces prompt cost and the "lost in the middle" effect.

### Flavors

- **Embedding-filter compression**: drop sentences inside each chunk whose embedding is below a similarity threshold to the query.
- **LLM extractive compression**: ask a small LLM to "extract only the spans from this chunk that help answer the question; return verbatim".
- **Summarization compression**: paraphrase each chunk into a 1–2 sentence summary. Use only when faithfulness is auditable elsewhere — paraphrase can drift.

### Recipe (LLM extractive)

```python
COMPRESS_PROMPT = """From the passage below, return ONLY the verbatim sentences
that help answer the question. If nothing is relevant, return exactly "NONE".

Question: {query}

Passage:
{chunk}

Relevant sentences:"""

def compress_chunk(client, query: str, chunk: str) -> str | None:
    msg = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=400,
        messages=[{"role": "user", "content": COMPRESS_PROMPT.format(query=query, chunk=chunk)}],
    )
    text = msg.content[0].text.strip()
    return None if text == "NONE" else text
```

Run in parallel across chunks. Drop chunks that compress to `NONE` from the final context.

---

## Stacking Recommendations

| Use case | Recommended stack |
| --- | --- |
| Prototype | Vector top-K + RRF if hybrid enabled |
| General chat over docs | Hybrid (BM25 + vector) → cross-encoder rerank → top-5 to LLM |
| High-precision (legal / medical) | HyDE + multi-query → hybrid → cross-encoder rerank → LLM extractive compression → top-3 to LLM |
| Long conversational | Query rewriting → hybrid → cross-encoder rerank → top-5 |
| Open-ended research | Multi-query + step-back → hybrid → cross-encoder rerank → top-10 |

Run each addition through your eval set (`recall@k`, faithfulness, latency). Ship only the additions that move metrics; remove the rest.
