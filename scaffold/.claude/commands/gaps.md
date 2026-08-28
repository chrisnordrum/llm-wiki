---
description: Audit the wiki for gaps and open questions, ask them all, then fold the answers back in
argument-hint: (optional) a page slug, tag, or topic to scope the audit to
---

Run the **GAPS** workflow from `CLAUDE.md`.

Scope: $ARGUMENTS — if empty, audit the whole wiki.

This is **not** `/lint`. Lint finds what the wiki can check *by itself* (broken links, orphans,
format drift). This finds what **only the user can answer** — then asks them, then files the
answers. Run it far less often than lint: after a big ingest, or every few weeks.

---

## Phase 1 — Audit (do this silently, then ask)

**Read before you ask.** Never ask a question the wiki, `sources/`, or the filesystem already
answers — that wastes their time and makes the whole command feel cheap. Check first:

- `log.md` — the most recent entries name what was left open last time. Start there.
- Uncertainty markers across `pages/`:
  `grep -rniE "unclear|unknown|TBD|open question|not recorded|unconfirmed|isn't settled|still open|no record|unexplained"`
- `## Open questions` sections and `⚠️` callouts.
- **In-flight claims.** Any page saying *applied / pending / in progress / not yet / Phase N /
  waiting on / unresolved*. **These are the highest-value questions in the whole audit** —
  they were true when written and rot silently into false ones. Nothing else on this list
  degrades on its own.
- **Named-but-unpaged entities.** People, companies, projects, repos mentioned in prose with no
  page. Grep proper nouns; check them against the page list.
- **Coverage holes.** Compare what the pages claim the user does against what has a page. Also
  list their code directories — repos on disk with no page are a recurring blind spot.
- **Thin and stale pages** — but only ask if the thinness matters. "Fine as-is" is a legitimate
  answer, and once they give it, stop re-flagging those pages in future runs.

## Phase 2 — Ask

Deliver **one numbered list**, grouped by kind, so they can answer in bulk by number. Roughly:

1. **Outcomes the wiki is waiting on** — lead with these.
2. **Explicitly flagged open questions** — quote the page's own wording.
3. **History and biography holes** — the "why" behind a decision the wiki records only as fact.
4. **People and entities** with no page.
5. **Coverage and scope decisions** — the ones only they can make.

Rules for the questions themselves:

- **Give the context needed to answer.** If a question depends on detail buried in a page,
  restate the detail. They should not have to go looking.
- **Ask what only they know.** Motivations, outcomes, relationships, intentions, corrections.
- **Say which two matter most**, and why, at the end. They may only answer a few.
- **Hold questions you can't ground.** If you can't verify an entity exists, ask who they are —
  do not write a page on a guess.
- Don't cap the list artificially, but don't pad it either. ~15–20 real questions beats 40 thin
  ones.

## Phase 3 — Reconcile

Their answers are a **first-person primary source and outrank every inference in the wiki.**

1. **Save them first** to `sources/YYYY-MM-DD-gap-filling-qa.md` with a provenance header,
   substance verbatim. Do this before editing any page — the raw answers are the record.
2. Work through the normal **INGEST** workflow: update existing pages, create pages only where
   the knowledge earns one, cross-link both ways, bump `updated:` and `sources:`, update
   `pages/index.md`.
3. **Mark corrections as corrections**, in place — a dated line saying what the page used to
   claim and why it was wrong. That history is worth as much as the fix.
4. Append a **GAPS** entry to `log.md`: created / corrected / outcomes recorded / still open.
5. Re-run the link and orphan check before reporting done.

---

## Principles worth holding

These are the failure modes this workflow keeps hitting. Read them before Phase 2.

- **Don't trust the frame of your own question.** A question can carry a wrong premise and
  still get a right answer. Re-verify where something belongs before writing it down.
- **A correction is not automatically a downgrade.** A page can be wrong in *both* directions
  at once — overstating one part of a claim while understating another. Check whether a
  correction should move in the user's favour before assuming it shrinks the claim.
- **Reference beats recollection.** When their memory conflicts with a written source, say so
  and let them choose. Don't silently overwrite either one.
- **Reconcile before overwriting.** Two accounts that look contradictory are often both true
  from different vantage points. Record how they fit; only overwrite on a real conflict.
- **"Mention them, no page" is a valid answer.** A name deliberately left without a page and
  without a stub link is a decision, not an omission. Respect it once it's made.
- **Expect batched, mid-turn replies.** Answers arrive by number and follow-ups land while
  you're still writing. Fold them in as they come.
- **Watch for the second-order finding.** The best material often comes from a question's side
  effects — an answer exposes something else the page was quietly missing. When an answer
  surprises you, look at what else is absent.
