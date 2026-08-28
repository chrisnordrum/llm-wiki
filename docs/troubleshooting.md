# Troubleshooting

Nearly every failure here is **silent** — the pipeline is designed never to disrupt a
session exit, which means it also never tells you it didn't work. Start with the log:

```bash
cat ~/.claude/hooks/.wiki-state/ingest.log
```

And don't diagnose from a session exit. Run the pipeline directly instead:

```bash
~/.claude/hooks/wiki-ingest-run.sh ~/.claude/projects/<project>/<session>.jsonl
```

---

## Nothing happens when a session ends

**First: wait.** The real ingest lands **3–6 minutes** after exit. An exit looks
identical whether it fired or not.

Then, in order:

**Is the hook registered?**
```bash
python3 -c "import json;print(json.load(open('$HOME/.claude/settings.json')).get('hooks',{}).get('SessionEnd'))"
```
Empty or `None` means the merge didn't take.

**Are the scripts executable?**
```bash
ls -l ~/.claude/hooks/wiki-*.sh    # want -rwxr-xr-x
chmod +x ~/.claude/hooks/wiki-*.sh
```

**Did the session qualify?** It's skipped if it was under 30KB, was rooted inside the
wiki, or ended via `/clear` or resume rather than a real exit. All are intentional.

**Is `claude` on PATH?** The log says `claude CLI not on PATH; aborting`. Hooks run in a
minimal environment that may not match your interactive shell.

**Is the wiki where the hooks think it is?** The log says `wiki not found at …`. Check
`LLM_WIKI_DIR` is exported in a profile the hook environment actually reads.

---

## It ingests but never commits

The log says:

```
git commit failed (identity unset?); changes left staged
```

This is the most common setup problem and the most annoying to spot, because everything
else works — pages update, the log fills in, and the repo looks frozen.

```bash
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
```

Your edits aren't lost; they're staged. Commit them by hand once and the pipeline
handles it from then on.

**If you use gpg signing:** the drainer forces it off with `-c commit.gpgsign=false`. It
runs unattended, so a passphrase prompt would hang the drain until the stale-lock timer
clears it 45 minutes later.

---

## The log says "nothing durable"

**That's a success.** Most sessions are routine and produce nothing worth keeping. A
pipeline that always finds something is one filling your wiki with noise.

If *every* run says this and you're sure sessions are substantive, check that the wiki
has an `index.md` the scribe can read, and that `CLAUDE.md` copied over intact.

---

## Ingests stopped happening entirely

A drainer killed mid-run leaves its lock behind:

```bash
ls -ld ~/.claude/hooks/.wiki-state/lock
```

Anything older than 45 minutes is reaped automatically on the next attempt. To clear it
now:

```bash
rm -rf ~/.claude/hooks/.wiki-state/lock
```

Then drain the backlog by hand — queued jobs survive:

```bash
~/.claude/hooks/wiki-ingest-run.sh
```

---

## Sessions are spawning sessions

If ingests appear to run continuously, the reentrancy guard isn't firing. The drainer's
own Claude session triggers `SessionEnd`, which queues another ingest, forever.

Check that `wiki-session-end.sh` still has:

```bash
[[ -n "${WIKI_SCRIBE_RUNNING:-}" ]] && exit 0
```

and that the drainer sets `WIKI_SCRIBE_RUNNING=1` on its `claude` invocation. Don't
remove either.

```bash
rm -f ~/.claude/hooks/.wiki-state/queue/*.job    # stop the bleeding
```

---

## Pages are wrong, or the wiki looks messy

**It made a page it shouldn't have.** The scribe is told to bias hard toward updating
existing pages. If it's creating near-duplicates, `pages/index.md` probably doesn't
describe the existing pages clearly enough to recognize the overlap — the index is what
it checks against.

**It resolved something that was still open.** It's instructed not to, since a work
session is weaker evidence than you stating something directly. Revert it: `git log`,
`git revert`.

**Pages nothing links to.** Run `/lint`. That's what it's for.

**A page is missing from retrieval.** Check it has a line in `pages/index.md`. Without
one it's effectively invisible, because the index is what gets read first.

---

## A session read the wiki and then refused to edit code

Working as intended, in the wrong place. Your wiki's `CLAUDE.md` says *never edit code,
in any repo*, and Claude Code auto-loads it when a session reads files in that directory.

Use the `wiki-librarian` subagent instead of reading pages directly — it takes the wiki's
rules into its own context and returns only an answer. That's what it's for. `/clear`
resolves the current session.

---

## Starting over

```bash
rm -rf ~/.claude/hooks/.wiki-state          # queue, locks, logs
# remove the SessionEnd entry from ~/.claude/settings.json
```

Your wiki is untouched — it's a separate git repo. Nothing here removes pages.
