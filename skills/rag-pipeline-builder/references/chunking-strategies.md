# Chunking Strategies

> Reference companion to `../SKILL.md` Phase 2. Six strategies, when to use each, what they cost, and a runnable Python recipe for each.

## TL;DR Decision Table

| Strategy | Best for | Default size | Key trade-off |
| --- | --- | --- | --- |
| Fixed-size token | Quick baselines, homogeneous text | 512 tok / 50 overlap | Cuts mid-sentence; weakest semantics |
| Recursive character | General-purpose default | 512 tok / 50 overlap | Slight complexity, big quality win |
| Document-aware | Markdown / HTML / code | Section-bounded | Needs per-format splitter |
| Semantic | Long-form narrative | Dynamic (200–800) | Higher ingest cost |
| Sentence-window | FAQ, dense docs | 3-sentence window | Variable size, needs caps |
| Late chunking | Long-context embeddings | 8 k token doc → 512 tok chunks | Requires ≥ 8 k context embedder |

If you have no other information: start with **recursive character, 512 tokens, 50 overlap**, then measure.

---

## 1. Fixed-Size Token Chunking

Split the text into equal-length chunks measured in **tokens** (not characters — different scripts have wildly different token-to-character ratios).

### Pros

- Trivial to implement and reason about.
- Predictable storage and memory cost.
- Reliable baseline for A/B comparisons.

### Cons

- Cuts mid-sentence, mid-list, and mid-code-block.
- Ignores document structure entirely.
- Embeddings of cut-off chunks are noisier than they need to be.

### When to use

- Building a baseline before you have eval data.
- Corpora that are already uniformly short and structureless (log lines, chat messages).

### Recipe

```python
import tiktoken

def fixed_token_chunks(text: str, chunk_size: int = 512, overlap: int = 50,
                      model: str = "cl100k_base") -> list[str]:
    enc = tiktoken.get_encoding(model)
    tokens = enc.encode(text)
    chunks: list[str] = []
    step = chunk_size - overlap
    for start in range(0, len(tokens), step):
        window = tokens[start : start + chunk_size]
        chunks.append(enc.decode(window))
        if start + chunk_size >= len(tokens):
            break
    return chunks
```

---

## 2. Recursive Character Chunking

Try a list of separators in priority order — paragraph break, line break, sentence terminator, space — recursing into oversized pieces with the next-finer separator. This is the **LangChain `RecursiveCharacterTextSplitter`** strategy.

### Pros

- Respects paragraph and sentence boundaries when they fit.
- Handles any text format with the same code path.
- Cheap; no embedding calls during chunking.

### Cons

- Still character-counted (sizes are approximate in tokens).
- No awareness of headings, tables, or code blocks.

### When to use

- Default choice when you don't know enough about the corpus yet.
- Mixed-format dumps where document-aware splitting would need too many cases.

### Recipe

```python
from langchain_text_splitters import RecursiveCharacterTextSplitter

splitter = RecursiveCharacterTextSplitter(
    chunk_size=2048,            # ~512 tokens at ~4 chars/token
    chunk_overlap=200,
    separators=["\n\n", "\n", ". ", " ", ""],
    length_function=len,
)
chunks = splitter.split_text(long_text)
```

---

## 3. Document-Aware Chunking

Use a parser that understands the source format — Markdown headings, HTML DOM, AST nodes for source code — and split on those boundaries first. Prepend the section path (`H1 > H2 > H3`) to each chunk's text so embeddings carry structural context.

### Pros

- Chunks align with how humans actually navigate the document.
- Section path improves retrievability dramatically for technical docs.
- Code chunks can split at function / class boundaries instead of mid-body.

### Cons

- One implementation per format (Markdown, HTML, code-by-language, PDF).
- Layout-broken or non-conforming source needs fallback to recursive splitting.

### When to use

- Technical documentation, API references, knowledge bases authored in Markdown / HTML.
- Source-code corpora — embed by function / class with the file path prepended.
- Long PDFs that survived a layout-aware extractor.

### Recipe

```python
from langchain_text_splitters import MarkdownHeaderTextSplitter, RecursiveCharacterTextSplitter

headers_to_split_on = [("#", "h1"), ("##", "h2"), ("###", "h3")]
md_splitter = MarkdownHeaderTextSplitter(headers_to_split_on=headers_to_split_on)
sections = md_splitter.split_text(markdown_text)

# Section pieces can still be larger than the embedder's budget.
fallback = RecursiveCharacterTextSplitter(chunk_size=2048, chunk_overlap=200)
chunks = []
for s in sections:
    path = " > ".join(s.metadata.get(h, "") for _, h in headers_to_split_on if s.metadata.get(h))
    for piece in fallback.split_text(s.page_content):
        chunks.append({"text": f"[{path}]\n{piece}", "metadata": s.metadata})
```

---

## 4. Semantic Chunking

Embed every sentence (or small group), compute pairwise cosine distance between adjacent units, and split where the distance exceeds a percentile threshold — i.e. where the topic shifts.

### Pros

- Chunks correspond to **topical units**, not arbitrary windows.
- Reduces "two-topic chunks" that confuse retrieval.

### Cons

- Higher ingest cost (one embedding per sentence on top of per-chunk).
- Threshold tuning is corpus-specific.
- Slower indexing; rarely worth it for short docs.

### When to use

- Long-form narrative — research papers, transcripts, articles — where topics drift mid-document.
- Pairs naturally with strong embedding models.

### Recipe

```python
import numpy as np
from sentence_transformers import SentenceTransformer
import re

def semantic_chunks(text: str, breakpoint_percentile: float = 95.0,
                    model_name: str = "BAAI/bge-small-en-v1.5") -> list[str]:
    sentences = [s.strip() for s in re.split(r"(?<=[.!?])\s+", text) if s.strip()]
    if len(sentences) < 2:
        return sentences

    model = SentenceTransformer(model_name)
    embs = model.encode(sentences, normalize_embeddings=True)
    distances = 1.0 - (embs[:-1] * embs[1:]).sum(axis=1)
    cutoff = np.percentile(distances, breakpoint_percentile)
    break_indices = [i + 1 for i, d in enumerate(distances) if d > cutoff]

    chunks, prev = [], 0
    for idx in break_indices + [len(sentences)]:
        chunks.append(" ".join(sentences[prev:idx]))
        prev = idx
    return chunks
```

---

## 5. Sentence-Window Chunking

Index each sentence individually, but at retrieval time return the matched sentence **plus N neighboring sentences** as context to the LLM. The retrieval unit and the context unit are decoupled.

### Pros

- Pinpoint retrieval precision.
- LLM still gets enough surrounding context to ground the answer.
- Easy to tune (just change window size).

### Cons

- More vectors stored per document (one per sentence).
- Requires storing original sentence ordering and document offsets.

### When to use

- FAQ corpora where the answer is a single sentence.
- Dense reference material where adjacent sentences matter for context.

### Recipe

```python
import re
from dataclasses import dataclass

@dataclass
class SentenceUnit:
    doc_id: str
    sentence_idx: int
    sentence: str
    window: str   # sentence ± window_size for the LLM

def sentence_window_units(doc_id: str, text: str, window_size: int = 2) -> list[SentenceUnit]:
    sentences = [s.strip() for s in re.split(r"(?<=[.!?])\s+", text) if s.strip()]
    units: list[SentenceUnit] = []
    for i, s in enumerate(sentences):
        lo = max(0, i - window_size)
        hi = min(len(sentences), i + window_size + 1)
        units.append(SentenceUnit(
            doc_id=doc_id, sentence_idx=i, sentence=s,
            window=" ".join(sentences[lo:hi]),
        ))
    return units
```

At index time, embed `unit.sentence`. At LLM-prompt time, hand the model `unit.window`.

---

## 6. Late Chunking

Embed the **whole document** (or large block) through a long-context embedding model, then mean-pool **slices of the token-level output** to produce chunk embeddings. Each chunk's embedding has seen its entire surrounding context — proper names, anaphora, and cross-references are resolved.

### Pros

- Best-in-class retrieval quality when the embedder supports it.
- Solves the "this chunk is ambiguous out of context" problem (e.g. "He then resigned" — embedded with "Smith joined in 2019" in scope).

### Cons

- Requires a long-context embedder (Jina v2, Nomic, BGE-M3 with proper config).
- More memory during ingest; slower per document.
- More plumbing — most frameworks don't expose token-level embeddings out of the box.

### When to use

- Mid-to-long documents where anaphora and discourse cohesion matter (legal, contracts, research papers).
- When you've squeezed everything else and need the last 5–10 % of recall.

### Recipe (sketch)

```python
import torch
from transformers import AutoTokenizer, AutoModel

MODEL = "jinaai/jina-embeddings-v2-base-en"  # 8k context

def late_chunks(text: str, chunk_token_size: int = 256) -> list[tuple[str, list[float]]]:
    tok = AutoTokenizer.from_pretrained(MODEL)
    model = AutoModel.from_pretrained(MODEL, trust_remote_code=True).eval()

    encoded = tok(text, return_tensors="pt", truncation=True, max_length=8192)
    with torch.no_grad():
        token_embs = model(**encoded).last_hidden_state[0]   # (T, D)

    input_ids = encoded["input_ids"][0]
    out: list[tuple[str, list[float]]] = []
    for start in range(0, len(input_ids), chunk_token_size):
        end = min(start + chunk_token_size, len(input_ids))
        chunk_text = tok.decode(input_ids[start:end], skip_special_tokens=True)
        chunk_emb = token_embs[start:end].mean(dim=0)
        chunk_emb = torch.nn.functional.normalize(chunk_emb, dim=-1)
        out.append((chunk_text, chunk_emb.tolist()))
    return out
```

---

## Cross-Cutting Rules

- **Always prepend the document title and section path** to each chunk's stored text. Cheap, big retrieval win.
- **Always store metadata** alongside the chunk: `doc_id`, `chunk_idx`, `source_url`, `last_modified`, `tenant_id`, `section_path`. Hybrid search and filtering depend on it.
- **Re-chunk when adding a new document class.** Don't assume one chunker fits all.
- **Measure before optimizing.** Hold the embedder constant, sweep chunk size in `{256, 512, 1024}` × overlap in `{0, 50, 128}`, and pick by `recall@k` on a labelled eval set.
