---
title: Example Project
aliases: [Example Project, example-project]
type: entity
domain: code
tags: [example, project]
created: 2026-01-01
updated: 2026-01-01
sources: []
---

## Summary
A placeholder `code`-domain entity page, here to show the shape a project page takes.
**Delete this page once you have real ones** — and remove its line from [[index]].

## Details
A project page is the canonical place for facts about one codebase. It's where the
scribe puts status changes, so they don't sprawl into new pages every time something
moves.

Worth recording on a page like this:

- **Stack and structure** — what it's built on, and any decision that surprised you.
- **Decisions and their reasoning** — especially ones you'd otherwise re-litigate.
  *Example: money is stored as integer cents, never floats, because rounding drift
  in a budgeting tool is unrecoverable once it compounds.*
- **Gotchas** — the things that cost you an afternoon once already.
- **Status** — with a date. See the warning below.

## Open questions
- Is the deploy still pinned to the old runtime? *(unresolved — checking next release)*

An `## Open questions` section is not decoration. `/gaps` reads these, asks you about
them, and folds your answers back in. It's also what the librarian surfaces so an
answer built on a hedge doesn't come back sounding confident.

> **Status claims rot.** A line saying *pending*, *in progress*, or *Phase 2* was true
> when written and quietly becomes false. These are the highest-value things `/gaps`
> asks about, because nothing else in a wiki degrades on its own.

## Related
- [[llm-wiki-pattern]] — why this page is a page and not a chat message
- [[adding-a-source]] — how knowledge gets here
