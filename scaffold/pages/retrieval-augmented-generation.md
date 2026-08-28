---
title: Retrieval-Augmented Generation
aliases: [RAG, Retrieval-Augmented Generation]
type: concept
domain: general
tags: [llm, retrieval, architecture]
created: 2026-01-01
updated: 2026-01-01
sources: []
---

## Summary
An architecture where an LLM answers questions by retrieving relevant chunks from a
document corpus at **query time** and generating an answer from them. It is the
approach the [[llm-wiki-pattern]] is defined against.

## How it works
Documents are split into chunks and embedded into a vector store. At query time the
question is embedded, the nearest chunks are retrieved, and those chunks are pasted
into the model's context alongside the question. The model answers from what it was
handed.

## Where it's the right tool
- **Corpora too large to ever synthesize** — millions of documents, where no
  up-front pass is affordable.
- **Content that changes constantly**, where a compiled synthesis would be stale
  before it was useful.
- **Questions whose answers are localized** — a lookup that lives in one chunk.

## Where it falls down
- **Nothing accumulates.** The model re-derives the same understanding on every
  query. Ask the same subtle question twice and pay for it twice.
- **Cross-document synthesis is weak.** An answer spanning five documents needs all
  five to survive retrieval simultaneously, which chunk-level similarity does not
  guarantee.
- **Contradictions stay invisible.** Two sources that disagree are two chunks. Nobody
  ever notices, because nothing ever compares them.
- **Infrastructure cost.** Embeddings, a vector store, a chunking strategy, and a
  re-ranking step to tune.

The [[llm-wiki-pattern]] trades query-time retrieval for ingest-time synthesis: pay
once, on the way in, and get a plain-markdown artifact with no infrastructure at all.
The tradeoff is that ingest is slower and the wiki must be actively maintained —
which is exactly the work the LLM is there to do.

## Related
- [[llm-wiki-pattern]] — the alternative this page exists to contrast with
