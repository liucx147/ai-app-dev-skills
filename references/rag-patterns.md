# RAG Patterns Reference

> Cross-skill reference material for Retrieval-Augmented Generation. Individual Skills should link sections here instead of restating the theory.

## Table of Contents

1. [When to use RAG](#1-when-to-use-rag)
2. [Document loading & normalization](#2-document-loading--normalization)
3. [Chunking strategies](#3-chunking-strategies)
4. [Embeddings & vector stores](#4-embeddings--vector-stores)
5. [Retrieval strategies](#5-retrieval-strategies)
6. [Reranking](#6-reranking)
7. [Context assembly & prompting](#7-context-assembly--prompting)
8. [Evaluation](#8-evaluation)
9. [Common failure modes](#9-common-failure-modes)

---

## 1. When to use RAG

RAG is the right tool when **all** of the following are true:

- The knowledge changes more often than you want to fine-tune (hours to weeks).
- The answer must cite a specific source.
- The corpus exceeds the model's effective context (or you want to control cost per query).

If the knowledge is stable, small, and not citation-bound, just put it in the system prompt with **prompt caching** enabled.

## 2. Document loading & normalization

- Strip boilerplate (navigation, footers, ads) before chunking — noise dominates embeddings.
- Preserve structural metadata: title, section, page, source URL, last-modified.
- Normalize tables (Markdown or JSON), code (fenced blocks with language), and lists.
- For PDFs, prefer layout-aware extractors (e.g. PyMuPDF + heuristics, or vision-LM extraction for figure-heavy docs).
- Store the raw extracted text alongside the chunks so you can re-chunk without re-extracting.

## 3. Chunking strategies

| Strategy | When to use | Trade-offs |
| --- | --- | --- |
| Fixed-size (tokens / chars) | Quick baselines, homogeneous text | Cuts mid-sentence; weakens embeddings |
| Sentence-window | FAQ / docs with natural sentences | Variable size; needs upper/lower bounds |
| Recursive structural | Markdown / HTML / code with headings | Best default; preserves hierarchy |
| Semantic | Long-form narrative where topic drifts | Higher cost; pairs well with embeddings |
| Late-interaction (ColBERT) | Latency-tolerant, recall-critical | Different infra path; richer retrieval |

Heuristics:

- Start at **~512 tokens** with **~64 tokens overlap** as a baseline.
- Always include the document title and section path in the chunk's metadata; many retrievers benefit from prepending them to the chunk text.
- Re-chunk when adding a new document class; do not assume one chunker fits all.

## 4. Embeddings & vector stores

- Pick an embedding model by **(quality, dimensionality, cost, multilingual support)**. Match the model to your retrieval evals, not vendor benchmarks.
- Store the embedding **model id and version** in chunk metadata — when you swap models, you can backfill incrementally.
- Choose the store by access pattern, not hype: pgvector / SQLite-vss for ≤1M chunks, dedicated stores (Qdrant, Weaviate, Pinecone, Vespa) past that.
- Always index on (vector, **filter fields**) — pure ANN without metadata filtering kills precision in multi-tenant corpora.

## 5. Retrieval strategies

- **Dense only**: cheap, strong recall on paraphrased queries; weak on rare terms.
- **Sparse only (BM25)**: strong on exact / rare terms; weak on paraphrase.
- **Hybrid (dense + sparse)**: near-universal default; combine via reciprocal rank fusion (RRF) or weighted sum.
- **Query expansion**: rewrite the user query with an LLM (HyDE, multi-query) for ambiguous or short inputs.
- **Multi-hop**: when a single retrieval can't answer (e.g. "compare A and B"), let the agent issue follow-up retrievals.
- Always log `(query, retrieved_ids, scores)` for offline eval.

## 6. Reranking

- Rerank the top **20–100** retrieved chunks down to the top **3–10** with a cross-encoder or LLM judge.
- Reranking buys precision; it does not fix recall — if the gold chunk isn't in the candidate set, no reranker recovers it.
- Cache rerank scores keyed by `(query_hash, chunk_id)` when queries repeat.

## 7. Context assembly & prompting

- Lead with a **role + task** instruction; then the retrieved context; then the user query.
- Wrap each chunk in a clearly delimited block (XML tags or numbered sections) with its source identifier so the model can cite.
- Tell the model what to do **when retrieval fails**: refuse, ask for clarification, or fall back to general knowledge with a disclaimer — pick one explicitly.
- Enable **prompt caching** on the static instructions + retrieved context boundary that repeats across turns.

## 8. Evaluation

Two layers, run both:

- **Retrieval eval** (offline): for a labelled `(query, gold_chunk_ids)` set, measure recall@k, MRR, nDCG. Move these before touching the generator.
- **Generation eval**: faithfulness (no unsupported claims), answer relevance, citation correctness. Use an LLM-as-judge with a held-out human sample to calibrate.

Track regression on every embedding / chunker / reranker change. Tag each eval run with the full retrieval-stack version.

## 9. Common failure modes

- **Lost-in-the-middle**: long contexts bury relevant chunks. Cap context length; rerank aggressively; consider position-aware reordering.
- **Stale embeddings**: re-embed on schema or model changes; track the model version per chunk.
- **Citation drift**: the model paraphrases a chunk into an unsupported claim. Mitigate with explicit "cite the chunk id for every claim" instructions and post-hoc citation verification.
- **Chunk leakage across tenants**: enforce tenant filters at the index level, not just in the prompt.
- **Embedding contamination**: log and dedupe near-identical chunks; otherwise they dominate retrieval.
