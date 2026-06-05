# Vector Database Comparison

> Reference companion to `../SKILL.md` Phase 2. Pick the database by your **access pattern and ops appetite**, not the marketing.

## Comparison Matrix

| Database | Deployment | Max dimensions | HNSW | Hybrid (BM25 + vector) | Metadata filtering | Pricing model | Official SDKs | Best for |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Pinecone** | Managed only (serverless + pod) | 20 000 | Yes (proprietary) | Yes (sparse + dense) | Yes (typed) | Per-namespace storage + read/write units | Python, TS, Java, Go | Zero-ops, multi-tenant SaaS, predictable latency |
| **Weaviate** | Managed + self-host | 65 536 | Yes | Yes (native BM25 + vector) | Yes (typed schema) | OSS free; cloud per-node | Python, TS, Go, Java | Schema-rich KBs, GraphQL, modular embedders |
| **Qdrant** | Managed + self-host | 65 536 | Yes (tunable M, ef) | Yes (sparse + dense) | Yes (rich payload filters) | OSS free; cloud per-cluster | Python, TS, Rust, Go, Java | Self-hosted production, fast filtering, quantization |
| **Chroma** | Embedded + self-host server | ~No hard cap (HNSW-bounded) | Yes | Limited (BM25 via plugin) | Yes (simple) | OSS free; managed beta | Python, TS, Ruby | Prototypes, embedded use, small corpora |
| **pgvector** | Self-host (Postgres ext.) + most managed Postgres | 2 000 (HNSW), 16 000 (IVFFlat) | Yes (PG ≥ 0.5.0) | Yes (combine with `tsvector` / `pg_trgm`) | Yes (full SQL) | Free; pay for Postgres host | Any Postgres driver | Existing Postgres stacks, joins with relational data |
| **Milvus** | Managed (Zilliz) + self-host | 32 768 | Yes (HNSW, IVF, DiskANN, ScaNN) | Yes (sparse + dense, since 2.4) | Yes (typed) | OSS free; Zilliz per-CU | Python, TS, Go, Java, C++ | Billion-scale, multi-index, advanced ANN |
| **Vespa** | Managed (Vespa Cloud) + self-host | ~No hard cap | Yes (HNSW + many alternatives) | Yes (best-in-class — was built for it) | Yes (typed, rich) | OSS free; cloud per-resource | Java, Python (HTTP), JS (HTTP) | Search-first apps, complex ranking, very large scale |
| **LanceDB** | Embedded + cloud | ~No hard cap | IVF-PQ + HNSW | Yes (FTS + vector) | Yes | OSS free; cloud per-storage/query | Python, TS, Rust | Local-first, on-device, columnar / multimodal |
| **Elasticsearch / OpenSearch** | Managed + self-host | 4 096 (dense_vector) | Yes (Lucene HNSW) | Yes (rich BM25 + kNN) | Yes (full ES query DSL) | OSS / paid tiers; managed per-node | Python, TS, Java, Go, Ruby, … | Teams already running ES, log + doc search hybrid |

> Numbers reflect publicly documented limits at time of writing. Always verify against the vendor's current docs before committing.

---

## How to Choose

Walk this tree top-down. Stop at the first branch that fits.

1. **Are you already running PostgreSQL and the corpus is < 5 M chunks?**
   → **pgvector**. Reuse the database you already operate. Joins to relational data come for free. Add HNSW once you outgrow IVFFlat.

2. **Is this a prototype or < 100 k chunks living on one machine?**
   → **Chroma** or **LanceDB**. Embedded, zero infra, in-process.

3. **Do you want zero ops and have budget?**
   → **Pinecone** (serverless) or **Weaviate Cloud**. Predictable latency, managed upgrades.

4. **Do you need rich filtering and high QPS, willing to self-host?**
   → **Qdrant**. Fastest path to a production-quality self-hosted setup.

5. **Do you need schema-rich data + GraphQL + modular embedders?**
   → **Weaviate** (self-host).

6. **Billions of vectors, multi-tenant, multi-index strategies?**
   → **Milvus** (self-host or Zilliz Cloud).

7. **Search-first product where ranking sophistication matters more than vector purity?**
   → **Vespa**.

8. **Already running Elasticsearch / OpenSearch for logs or full-text?**
   → Use the existing cluster's `dense_vector` field. Don't add a second store unless you've outgrown it.

---

## Per-Database Notes

### Pinecone

- **Serverless** tier auto-scales; pay per read/write unit + storage. Great default for SaaS.
- **Pod-based** tier when you need dedicated capacity / predictable QPS.
- Sparse-dense hybrid is first-class; supply a sparse vector alongside the dense one and weight at query time.
- No self-host option — accept the lock-in or pick something else.

### Weaviate

- Module system embeds documents server-side (`text2vec-openai`, `text2vec-cohere`, etc.) — fewer client moving parts, but couples your DB to the embedder.
- Native hybrid search via `nearText + bm25` with `alpha` blending.
- GraphQL query interface is powerful but adds a learning curve.

### Qdrant

- Payload filtering is fast even on large collections (filterable HNSW).
- Built-in quantization (scalar, product, binary) can cut RAM 4–32× with modest recall loss.
- Cluster mode for horizontal scaling; single-node is excellent for most teams.

### Chroma

- Best DX for getting started; `pip install chromadb` and you're indexing in three lines.
- Server mode (HTTP / gRPC) when you need to share an index across processes.
- Not the choice for billion-scale or high-QPS production — by design.

### pgvector

- IVFFlat is the classic index; HNSW (`pgvector` 0.5+) closes most of the quality gap with dedicated stores.
- Combine `tsvector` (BM25-like) + `embedding` (vector) and fuse with RRF in SQL for hybrid search.
- Sharding strategy is your Postgres sharding strategy — Citus, partitions, or read replicas.

### Milvus

- Multiple index types per collection — pick HNSW for low-latency, DiskANN for huge corpora with limited RAM.
- GPU acceleration available (CAGRA, GPU_IVF_FLAT).
- Run via **Zilliz Cloud** if you want billion-scale without operating it.

### Vespa

- The retrieval engine behind Yahoo and Spotify-scale workloads.
- Native support for tensor expressions in ranking — you can stack multiple stages (BM25, vector, learned ranker) in the engine itself.
- Steeper learning curve; the ranking flexibility usually rewards it.

### LanceDB

- Columnar storage (Apache Arrow); the same files back vector search, full-text search, and analytics queries.
- Strong story for multimodal (image + text + audio) embeddings co-located in one table.
- Great for on-device and edge deployments where you don't want a server.

### Elasticsearch / OpenSearch

- Dense vector field with Lucene HNSW. Combine with classic BM25 in a single query, blend with `rank_features` or learned-to-rank.
- Mature operational tooling (snapshots, ILM, cross-cluster replication).
- Vector latency is fine but rarely best-in-class versus a dedicated store at the same scale.

---

## Cross-Cutting Selection Criteria

Beyond the matrix, weigh these:

- **Quantization support.** Binary or product quantization can cut RAM and cost dramatically — Qdrant, Milvus, and Vespa lead here.
- **Filter performance.** Vector ANN + post-filter is slow at scale. Prefer engines with native pre-filtered ANN (Qdrant, Weaviate, Vespa).
- **Hybrid search ergonomics.** Some engines require you to issue two queries and fuse client-side; others fuse internally. Internal fusion is faster and easier to tune.
- **Snapshot / restore + multi-region.** Critical the moment you go to production.
- **Vendor health.** Read recent release cadence, open-issue triage time, and funding status — these stores are infrastructure; you'll live with the choice for years.
