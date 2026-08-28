---
description: Ingest a source into the wiki — extract, reconcile, cross-link, log
argument-hint: <path in sources/ | URL | pasted text>
---

Ingest the following source into the wiki:

$ARGUMENTS

Follow the **INGEST** workflow defined in `CLAUDE.md` exactly:

1. Load the source (read the file, fetch the URL, or save pasted text to `sources/` first).
2. Extract the durable knowledge worth keeping.
3. Reconcile against existing pages in `pages/` — update existing pages where the knowledge
   belongs, create new ones only when needed. Flag any contradictions.
4. Cross-link touched/new pages with `[[slug]]` links (both directions where sensible).
5. Update frontmatter (`aliases:`, `updated:`, `sources:`) and `pages/index.md` if a
   top-level page was added.
6. Append an entry to `log.md`.

Bias toward fewer, richer pages. Show me a short summary of what you created/updated when done.
