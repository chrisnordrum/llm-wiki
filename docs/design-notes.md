# Design notes

The parts of this that weren't obvious, and what I got wrong first.

The wiki pattern itself is Karpathy's and I won't re-explain it — the
[gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) does that
better. These notes are about the automation I built on top, which is where all the
interesting failure modes turned out to live.

---

## One writer, many readers

The wiki is a compounding artifact. That's the whole premise — synthesis happens once
and stays trustworthy. Which means a sloppy write is worse than a missing one: it stays
wrong until someone notices, and by then five other pages link to it.

So writes go through exactly one agent. `wiki-scribe` is the only thing permitted to
touch `pages/`, `sources/`, or `log.md`. Everything else — the skill, the librarian,
any session that happens to be curious — reads.

`wiki-librarian` gets `tools: Read, Grep, Glob` and nothing else. Not as a convention
someone has to remember, but structurally: it *cannot* write, so it can't be talked into
it and can't do it by accident.

### The reason that turned out to matter more

I gave the librarian read-only tools for focus. It earned its keep for a different
reason I hadn't thought about.

Claude Code auto-loads a nested `CLAUDE.md` when a session reads files in that directory.
My wiki's `CLAUDE.md` contains this rule, and it needs to:

> **Never edit code from this folder.** Not in this repo, and not in any other repo on
> disk — even when a wiki page describes that code, even when the fix is obvious.

Correct for the wiki. Completely wrong for a session that's halfway through a refactor
and just wanted to look something up. And contradictory instructions in one context get
resolved arbitrarily — not safely, *arbitrarily*.

A read-only subagent makes the conflict unreachable. The wiki's rules load into the
subagent's context, where they're true, and the coding session gets back a paragraph of
text. This is the same shape as putting an access-control rule at the database row
rather than in every caller: enforce it where it's structural, not where each caller has
to remember it.

---

## The retrieval ladder

The first version of the skill was one line: "read the wiki to answer questions about
past work." Predictably, sessions read far too much of it.

A wiki worth having doesn't fit in a context window, and it gets *less* likely to fit
every week. So retrieval is a ladder with an explicit instruction to stop at the first
rung that works:

1. **Read `index.md`.** Every page, one line each. It maps the whole wiki for a fraction
   of what any two pages cost. Most questions end here — the index names the one page
   you need.
2. **`grep -il` for filenames.** Not content. You want to know *which* pages, and then
   read them deliberately.
3. **Read one to three pages.** Follow `[[wikilinks]]` only when the answer actually
   depends on the linked page.
4. **Delegate to the librarian** for anything broader.

Rung 3's caveat is the one that bites. A healthy wiki is densely linked — that's the
point of it — and following links eagerly is how a 3k-token lookup becomes 40k.

This is also why `index.md` is treated as load-bearing rather than as bookkeeping. Every
new page **must** get an index line. A page missing from the index is invisible in
practice, because the index is what retrieval reads first. That rule is stated in the
schema, in the scribe's prompt, and in the ingest prompt, because it's the single thing
that keeps retrieval cheap and it's the easiest thing to skip.

---

## The session pipeline

The wiki only compounds if things get into it. Doing that by hand means remembering, at
the end of a session, that something in it was worth keeping — which is exactly when
you're least inclined to.

So: ingest every session automatically, and put all the intelligence in *deciding
whether anything mattered*.

### The hook does almost nothing, on purpose

`SessionEnd` hooks share a ~1.5 second budget across all of them and can't block or add
context. Anything real is going to blow that.

So `wiki-session-end.sh` does nothing but cheap gating — parse the payload, check a few
conditions, drop a job file, spawn a detached drainer, exit. Every path exits 0. A wiki
ingest is never worth disrupting someone's session exit.

The gates, and why each one:

- **`reason` is `clear` or `resume`** → skip. Those are mid-work events, not "I'm done."
- **cwd is inside the wiki** → skip. Sessions run from inside the wiki already write to
  it directly; ingesting them records the librarian's own bookkeeping as knowledge.
- **transcript under 30KB** → skip. Too short to have learned anything.
- **session already seen** → skip. `SessionEnd` can fire more than once.

### The reentrancy trap

This one cost me a while, and it's obvious in hindsight.

The detached ingest run *is itself a Claude Code session*. When it finishes, its own
`SessionEnd` fires, which queues another ingest, which is another session, forever.

```bash
[[ -n "${WIKI_SCRIBE_RUNNING:-}" ]] && exit 0
```

The drainer exports that variable when it invokes Claude. Three lines, and without them
the whole thing is a fork bomb with a language model in the loop.

Worth stating generally: **any hook that fires on an agent lifecycle event, and whose
handler invokes an agent, needs a reentrancy guard.** The recursion isn't visible in
either file on its own.

### Locking

Two sessions can end at the same moment, and two agents writing `pages/` concurrently
would corrupt the artifact this whole thing exists to protect.

```bash
mkdir "$LOCK_DIR" 2>/dev/null || exit 0
```

`mkdir` is atomic — it either creates the directory or fails, with no window in between.
No flock dependency, no PID files, portable everywhere.

Losing the race is safe by design: whoever holds the lock drains the *whole queue*, so
the loser's job still gets processed. It just doesn't get processed by them.

A lock left behind by a killed run would block ingests forever, so anything older than
45 minutes gets reaped on the next attempt.

---

## Committing is part of the feature

Early on the pipeline wrote to the working tree and stopped. That was wrong in a way
that took a while to name: the wiki *read* as frozen at the last hand-made commit no
matter how many sessions had landed, and there was no way to tell an agent's edits from
my own.

So the drainer commits. Three details, each fixing something that actually happened:

**Commit before the scribe runs.** If there are hand edits sitting uncommitted, they get
swept into the ingest's commit and attributed to an agent that never touched them. So
any pre-existing dirty tree is committed first, on its own, as *"Snapshot manual wiki
edits."* Every `Ingest session …` commit then contains exactly what the scribe wrote.

**Commit even when the scribe exits non-zero.** A run that hit `--max-turns` still left
real edits behind, and stranding those uncommitted is the exact failure this step exists
to prevent. The exit status goes in the commit body instead.

**Force gpg signing off.** This runs unattended behind a lock. A passphrase prompt has
nobody to answer it, so the drain hangs until the stale-lock timer clears it 45 minutes
later — and the symptom is "the pipeline just stopped working," with nothing in the log.

A clean tree commits nothing, so an ingest that found nothing durable leaves no empty
commit. And the commit is the review gate: `git log` in the wiki is where you see what
the agent decided, not the working tree's dirty/clean state.

---

## Trimming transcripts

A raw session transcript is dominated by `tool_result` payloads — file contents, command
output, search results. On a real transcript of mine: **537KB raw, 14KB after trimming.
Tool results were ~99% of it.** None of that helps decide whether a session was durable.

So the trimmer keeps human and assistant turns plus a one-line trace of what tools ran
(name and target, no payload), and drops the rest. Thinking blocks are dropped too —
private reasoning, not conclusions.

### Cutting from the middle, not the end

The first version truncated long transcripts at the cap. Wrong, and wrong in the most
expensive possible way: **what a session decided lives in its last turns.** Cutting the
tail hands the scribe a transcript that stops before the conclusions it's being asked to
record.

Now it fits whole turns from both ends — 60% of the budget reserved for the tail, the
remainder for the head, with an explicit `…[n turns elided from the middle]…` marker.
The head is kept because it's where the session states what it set out to do. Whatever
the tail doesn't use is handed back to the head, so a session with a short ending still
gets a long beginning.

Turns are kept **whole**. A clean gap is better than half a sentence.

### The tool trace can't crowd out the conversation

Originally unbounded, which meant that at tight caps the tool trace could survive intact
while the conversation was squeezed to nothing — the exact inversion of what matters.
Now the conversation has first claim on the budget and the trace gets the remainder,
falling back to a 20% floor only when the turns need everything.

### A measurement footnote

I originally believed three of my transcripts had hit the cap. It was two. I'd conflated
byte length and character length — the cap is character-based, and multi-byte UTF-8 had
pushed one transcript over in bytes while it stayed under in characters. Worth
mentioning because the fix was the same either way, but the number I was reasoning from
was wrong, and I'd have kept quoting it.

---

## What I measured and deliberately didn't build

The size gate (skip transcripts under 30KB) is a weak filter. My first estimate was that
~92% of sessions would pass it, which made a case for a cheap Haiku triage pass before
the real ingest.

Then I looked at what actually happened. In the pipeline's first five days live, **three
ingests ran, and all three produced real wiki updates.** Zero wasted "nothing durable"
runs.

The estimate overstated the cost because the filters that do the real work aren't the
size gate at all — they're the wiki-cwd exclusion, and the fact that sessions left open
in a tab never fire `SessionEnd` in the first place.

So I skipped the triage pass. What makes this a decision rather than laziness is naming
the signal that would reverse it: **if `ingest.log` starts showing a run of "nothing
durable" results, build the triage.** Until then it's optimizing a cost I measured at
approximately zero.

I'd rather ship this with the reasoning attached than quietly leave it out.

---

## Memory versus wiki

Claude Code has an auto-memory that loads into every session. Two persistent stores
overlap immediately, so they needed a rule:

**Memory is state. The wiki is knowledge.**

Memory is injected every session at fixed cost whether it's relevant or not, and stops
scaling past roughly ten facts. The wiki costs nothing until something calls it, but
only works if something remembers to.

So: what's true *right now*, what changes often, and behavioural guardrails that must
fire without a lookup go in memory. What happened and why — the accumulating part — goes
in the wiki. **If a fact has a wiki page, memory points at it rather than restating it,
and the wiki wins on conflict.**

The exception is behavioural guidance. That has to fire without being asked, so it stays
inline in memory rather than becoming a pointer to a page nothing thinks to read.

---

## What I'd tell someone adopting this

- **Start with Part 1.** The wiki is useful on its own. The pipeline is a convenience on
  top and it's the part that needs trust.
- **Read `CLAUDE.md` and change it.** It's the schema, it's meant to co-evolve with how
  you actually work, and it's the highest-leverage file in the repo.
- **Keep the wiki in git.** An agent is editing these files. `git log` is your review
  surface and your undo.
- **Let it decline to write.** "Nothing durable happened here" is the correct outcome for
  most sessions, and a pipeline that always finds something is one that's filling your
  wiki with noise.
