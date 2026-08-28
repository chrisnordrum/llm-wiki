---
title: LLM Wiki Pattern
aliases: [LLM Wiki, LLM Wiki Pattern]
type: concept
domain: general
tags: [knowledge-management, llm, second-brain, methodology, foundational]
created: 2026-01-01
updated: 2026-01-01
sources:
  - https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
---

## Summary
A pattern for building personal knowledge bases in which an LLM agent
**incrementally builds and maintains a persistent, interlinked wiki of markdown
files** that sits between you and your raw sources. Knowledge is synthesized once
at ingest time and then kept current — rather than re-derived from scratch on every
query as in [[retrieval-augmented-generation|RAG]]. Introduced by Andrej Karpathy.
**This wiki is an instantiation of this pattern.**

## The core idea: compounding vs. re-deriving
Typical LLM-over-documents usage (NotebookLM, file uploads, most
[[retrieval-augmented-generation|RAG]]) retrieves relevant chunks at query time and
generates an answer. The model rediscovers knowledge from scratch on every question;
nothing accumulates. A subtle question spanning five documents forces it to re-find
and re-piece the same fragments every time you ask.

The LLM Wiki inverts this. On each new source the model **reads, extracts, and
integrates** the knowledge into existing pages — updating entities, revising
summaries, flagging contradictions, strengthening or challenging the evolving
synthesis. The result is a **persistent, compounding artifact**: cross-references
already exist, contradictions are already flagged, the synthesis already reflects
everything read. It gets richer with every source added and every question asked.

**Division of labour:** you curate sources, explore, and ask good questions. The
LLM does the grunt work — summarizing, cross-referencing, filing, bookkeeping.

## The three layers
1. **Raw sources** — curated, *immutable* source documents. The LLM reads but never
   modifies them. (Here: `sources/`.)
2. **The wiki** — interlinked markdown the LLM owns entirely. You read it; the LLM
   writes it. (Here: `pages/`.)
3. **The schema** — a config document defining structure, conventions, and workflows.
   This is what turns the LLM into a *disciplined wiki maintainer* rather than a
   generic chatbot. (Here: `CLAUDE.md`.)

## The four operations
- **Ingest** — drop a source in, tell the LLM to process it. One source may touch
  10–15 pages. See [[adding-a-source]].
- **Query** — ask questions against the wiki. Answers come back with citations, and
  genuinely new synthesis gets **filed back as a page** so explorations compound too.
- **Lint** — periodic health-check: contradictions, stale claims, orphans, stubs, dupes.
- **Gaps** — interview the human for what the wiki structurally cannot know: outcomes,
  motivations, corrections.

## Why it works
The hard part of a knowledge base isn't the reading or thinking — it's the
**bookkeeping**: updating cross-references, keeping summaries current, flagging
contradictions, maintaining consistency across dozens of pages. People abandon wikis
because maintenance cost grows faster than value. LLMs don't get bored, don't forget a
cross-reference, and can touch fifteen files in one pass — so maintenance cost
approaches zero and the wiki stays alive.

## Two navigation files
- **`index.md`** — *content-oriented* catalog: every page with a one-line summary.
  Read first at query time, then drill in. Works well into the hundreds of pages
  **without embedding-based retrieval infrastructure**.
- **`log.md`** — *chronological*, append-only record of every ingest, query, and lint.

## Related
- [[retrieval-augmented-generation]] — the approach this is defined against
- [[adding-a-source]] — the ingest procedure in practice
- [[example-project]] — what a `code`-domain entity page looks like
- [[memex]] — the 1945 intellectual antecedent
