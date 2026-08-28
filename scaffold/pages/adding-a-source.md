---
title: Adding a Source
aliases: [Adding a Source, How to ingest]
type: howto
domain: general
tags: [workflow, howto, ingest]
created: 2026-01-01
updated: 2026-01-01
sources: []
---

## Summary
How to get something into the wiki so it compounds instead of scrolling away.

## The short version
From inside your wiki directory, run Claude Code and:

```
/ingest https://example.com/some-article
/ingest sources/2026-01-01-meeting-notes.md
/ingest <paste text directly>
```

Then ask it something:

```
/query what do I know about X?
```

## What actually happens
1. **Load** — the source is read, fetched, or (for pasted text) saved to `sources/`
   first with a provenance header. Sources are immutable once written.
2. **Extract** — the durable knowledge only. The test is *"what would I want already
   synthesized when I ask about this in six months?"*
3. **Reconcile** — against existing pages. Updating an existing page is the default;
   creating one is the exception. Contradictions get stated explicitly, not silently
   overwritten.
4. **Cross-link** — `[[links]]` both ways where it makes sense.
5. **Index** — every new page gets a line in [[index]]. A page missing from the index
   is effectively invisible, because that's what retrieval reads first.
6. **Log** — one entry appended to `log.md`.

## Rules of thumb
- **Fewer, richer pages.** Don't create a page per sentence. If knowledge belongs on
  an existing entity, put it there.
- **Distil, don't dump.** A good page is shorter than its sources. If you're pasting,
  it's going wrong.
- **A link to a page that doesn't exist is fine.** It's a stub marker meaning "this
  deserves a page." `/lint` collects them.
- **Sources are disposable; pages are the product.** Once ingested, a source can rot
  untouched.

## Keeping it healthy
- `/lint` — contradictions, stale claims, orphans, stubs, duplication, format drift.
- `/gaps` — interviews you for what the wiki structurally cannot know: outcomes,
  motivations, corrections. Run it far less often than lint.

## Related
- [[llm-wiki-pattern]] — why ingest-time synthesis beats query-time retrieval
- [[example-project]] — what a finished entity page looks like
