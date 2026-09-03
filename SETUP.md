# Setup

Three parts. Each is independently useful — stop after Part 1 if you just want the wiki.

| Part | What you get | Time |
|---|---|---|
| [1 — The wiki](#part-1--the-wiki) | A working wiki and the four workflows. Fully manual. | ~5 min |
| [2 — Retrieval](#part-2--retrieval) | Any session can query it, cheaply. | ~2 min |
| [3 — Auto-ingest](#part-3--auto-ingest-opt-in) | Sessions ingest themselves. **Opt-in.** | ~5 min |

**Prerequisites:** [Claude Code](https://claude.com/claude-code), `git`, and `python3`
(Part 3 only).

Everything below assumes your wiki will live at `~/llm-wiki`. That's the default
everything ships with, so following it literally means there is nothing to substitute.
If you want it elsewhere, see [Using a different location](#using-a-different-location).

```bash
git clone https://github.com/chrisnordrum/llm-wiki.git
cd llm-wiki
```

---

## Part 1 — The wiki

Copy the scaffold out to a directory **you** own. Don't run your wiki inside this clone:
your knowledge shouldn't live in a tree pointed at someone else's remote, and keeping
them separate means you can pull updates here without touching your pages.

```bash
cp -r scaffold ~/llm-wiki
cd ~/llm-wiki
git init && git add -A && git commit -m "Initial wiki"
```

> **`~/llm-wiki` must not already exist.** If it does, `cp` copies the scaffold *inside* it
> and you get `~/llm-wiki/scaffold/` — `CLAUDE.md` and `.claude/commands/` land a level too
> deep, so the schema never loads and the slash commands silently don't exist. Move the
> existing directory aside first, or pick another path.

Your wiki is now a git repo, so every change is recoverable and you can see exactly what
the LLM did. That matters more than usual here — an agent is going to be editing these
files.

Now run Claude Code from inside it:

```bash
cd ~/llm-wiki && claude
```

Try the workflows against the example pages that shipped with the scaffold:

```
/query what is an LLM wiki, and why not just use RAG?
/lint
/ingest https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
```

`/query` should come back with an answer citing `[[llm-wiki-pattern]]` and
`[[retrieval-augmented-generation]]`. `/lint` should report a stub — `[[memex]]` is
linked but has no page. That's deliberate, so lint has something real to find.

**Delete the four example pages** once your own arrive, and remove their lines from
`pages/index.md`.

### The one file worth reading

`CLAUDE.md` in your wiki is the schema — page format, frontmatter, linking rules, and
the four workflows in full. It's what turns Claude into a disciplined wiki maintainer
instead of a chatbot with file access. Edit it; it's meant to co-evolve with how you
actually work.

---

## Part 2 — Retrieval

Part 1 works only when you're *inside* the wiki. This part lets any session, in any
repo, ask your wiki a question.

```bash
mkdir -p ~/.claude/skills ~/.claude/agents
cp -r claude/skills/wiki ~/.claude/skills/
cp claude/agents/wiki-librarian.md claude/agents/wiki-scribe.md ~/.claude/agents/
```

That installs:

- **the `wiki` skill** — a retrieval ladder. Read `index.md`, pick pages by name, grep
  filenames only, read one to three pages. It exists to stop a lookup from ballooning:
  a full wiki never fits in context.
- **`wiki-librarian`** — read-only (`Read, Grep, Glob`). Answers a question and returns
  *the answer*, not the pages.
- **`wiki-scribe`** — the only agent that writes to the wiki.

Test it from somewhere else entirely:

```bash
cd ~/some-other-project && claude
# then ask: "what do I know about the LLM wiki pattern?"
```

You should get a short cited answer without the pages themselves entering your context.

> **Why the librarian is read-only.** Claude Code auto-loads a nested `CLAUDE.md` when a
> session reads files in that directory. Your wiki's `CLAUDE.md` says *never edit code,
> in any repo* — correct for the wiki, actively wrong for a session that's mid-refactor.
> A read-only subagent structurally cannot act on that conflict, so it can't leak.

---

## Part 3 — Auto-ingest (opt-in)

This one runs unattended, so read this section before installing it.

**What it does.** When a Claude Code session ends, a hook queues it and returns
immediately. A detached process trims the transcript down to just the conversation,
then runs Claude against it with one question: *did anything durable happen here?*
Usually the answer is no and it stops without writing anything. When the answer is yes,
it writes a digest to `sources/`, ingests it into `pages/`, and commits.

**What it reads.** Your session transcripts — the conversation, not tool output. It
skips sessions under 30KB, sessions rooted inside the wiki itself, and `/clear` or
resume events (those aren't "I'm done").

**What it costs.** One Claude call per qualifying session end, on Sonnet, capped at 60
turns. Most exit early having decided nothing was durable.

**What it writes.** Only `pages/`, `sources/`, and `log.md` in your wiki. Never code, in
any repo.

### Before you install: set a git identity

```bash
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
```

Do this first. Without it the pipeline ingests happily and **silently never commits** —
you'd get a wiki that appears frozen no matter how many sessions land. It logs
`git commit failed (identity unset?)` and carries on.

### Install

```bash
mkdir -p ~/.claude/hooks
cp claude/hooks/wiki-session-end.sh claude/hooks/wiki-ingest-run.sh \
   claude/hooks/wiki-trim-transcript.py ~/.claude/hooks/
chmod +x ~/.claude/hooks/wiki-session-end.sh ~/.claude/hooks/wiki-ingest-run.sh
```

### Register the hook

This is the fiddly step. **Merge** this into `~/.claude/settings.json` — add it to
`hooks.SessionEnd`. Do not replace the file; it probably holds your model, theme, and
plugin settings too.

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "matcher": "prompt_input_exit|logout|other",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/wiki-session-end.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

If you have no `hooks` key, paste the whole block. If you already have a `SessionEnd`
array, append this entry to it.

### Verify it — without waiting

Don't end a session and hope. Run the pipeline directly against a transcript:

```bash
ls ~/.claude/projects/*/*.jsonl | head            # find one
~/.claude/hooks/wiki-ingest-run.sh <that-file>    # run it now
cat ~/.claude/hooks/.wiki-state/ingest.log        # see what it decided
```

Then check `git -C ~/llm-wiki log` for an `Ingest session …` commit. If the log says
`nothing durable`, that's a success — it means the gate works.

### When it's quiet

A session exit looks identical whether the pipeline fired or not, and the real run lands
**3–6 minutes later**. Give it the full window before concluding it's broken, then read
`~/.claude/hooks/.wiki-state/ingest.log`. See [troubleshooting](docs/troubleshooting.md).

### Turning it off

Remove the `SessionEnd` entry from `~/.claude/settings.json`. That's the whole switch —
the scripts are inert without it. To disable just the auto-committing, set
`WIKI_AUTO_COMMIT=0`.

---

## Using a different location

Everything defaults to `~/llm-wiki`. To put it elsewhere, copy the scaffold there, then:

**The shell hooks** read an environment variable — set it in your shell profile:

```bash
export LLM_WIKI_DIR="$HOME/notes/wiki"
```

**The skill and agents** are prompts and can't read environment variables, so their path
is literal text:

```bash
sed -i '' 's|~/llm-wiki|~/notes/wiki|g' \
  ~/.claude/skills/wiki/SKILL.md \
  ~/.claude/agents/wiki-librarian.md \
  ~/.claude/agents/wiki-scribe.md
```

(Drop the `''` after `-i` on Linux.)

Both steps are needed: the hooks read the environment variable, the prompts carry the
literal path. Miss the second and the agents keep looking in `~/llm-wiki` and quietly
find nothing.

## Tuning

Environment variables, all read by the hooks:

| Variable | Default | What it does |
|---|---|---|
| `LLM_WIKI_DIR` | `~/llm-wiki` | Where the wiki lives |
| `WIKI_AUTO_COMMIT` | `1` | Commit each ingest; `0` leaves changes in the tree |
| `WIKI_SCRIBE_MODEL` | `sonnet` | Model for the ingest run |
| `WIKI_SCRIBE_MAX_TURNS` | `60` | Turn cap per ingest |
| `WIKI_MIN_TRANSCRIPT_BYTES` | `30000` | Below this, a session is too short to have learned anything |
| `WIKI_MIN_TRIMMED_BYTES` | `2000` | Below this after trimming, skip |
| `WIKI_STALE_LOCK_MINUTES` | `45` | When to reap a lock left by a killed run |
