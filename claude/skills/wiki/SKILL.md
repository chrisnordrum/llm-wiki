---
name: wiki
description: >-
  Look up what the user already knows from their personal llm-wiki — past
  projects, people, decisions, employers, notes, how they work. Use for "what do
  I know about X", "have I done X before", "what stack did I use for X", "who is
  X", "why did I decide X", or any question about prior work whose answer is not
  in the current repo. Read-only — never writes to the wiki.
---

# wiki

The user keeps a personal LLM-maintained wiki at:

```
~/llm-wiki/
```

It is the durable record of their projects, people, and decisions. This skill is
about **reading it cheaply**.

## The one rule that matters

A wiki worth having is far too big to load. You will never read a meaningful
fraction of it, and trying is the main way this goes wrong. Every lookup goes
through the index first. **Never** `cat pages/*.md`, never `Read` a page you
haven't first justified from the index or a grep hit, and never read anything in
`sources/` — those are raw inputs the wiki has already digested, and reading them
undoes the entire point.

## Retrieval ladder — stop at the first rung that answers the question

**Rung 1 — the index (start here, always).**

```
Read ~/llm-wiki/pages/index.md
```

It lists **every** page with a one-line description, grouped by domain, for a tiny
fraction of what the pages themselves cost. Most questions are answered by the
index telling you which one page to open. Read that page. Done.

**Rung 2 — grep for filenames only, when the index wording doesn't match.**

```
grep -il "<term>" ~/llm-wiki/pages/*.md
```

`-l` is not optional. You want filenames, not content — content comes from a
deliberate `Read` of the 1–3 pages that actually matter.

**Rung 3 — read the pages.** Follow `[[wikilinks]]` only when the answer
genuinely depends on the linked page. A healthy wiki is densely linked; following
links eagerly is how a 3k-token lookup becomes a 40k-token one.

**Rung 4 — delegate.** If the question spans more than ~3 pages, is open-ended
("what's the through-line across these projects"), or you're mid-task and don't
want the wiki in your context at all, hand it to the `wiki-librarian` subagent
and take back only the answer.

## Delegate by default when you're working

There is a second reason to prefer `wiki-librarian` over reading pages yourself:
`llm-wiki/` has its own `CLAUDE.md` that loads on demand when a session reads
files inside that directory. It instructs the reader to **never edit code, in any
repo on disk**. That is correct for the wiki and actively wrong for a coding
session, and contradictory instructions get resolved arbitrarily.

So: **if the current session is going to write code, use the subagent.** If
you're just answering a question and not touching a repo, reading directly is
fine and cheaper.

## Citing

Answer in terms of the wiki's own page names so the user can follow up:
"per `[[project-slug]]`". If the wiki doesn't cover something, say so plainly and
name what would need ingesting — don't guess and don't fill the gap from the
current repo.

## Writing is not your job

This skill is read-only. The wiki is written by `wiki-scribe` (ingest, lint) and
by the user working inside `llm-wiki/` directly. From a project session:

- Don't create or edit pages.
- Don't append to `log.md`.
- Don't drop files into `sources/`.

If a session turns up something the wiki should know, say so at the end. If the
`SessionEnd` pipeline is installed, it already captures durable session knowledge
automatically.
