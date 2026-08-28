#!/bin/bash
# Detached drainer -> turn queued sessions into wiki sources and ingest them.
#
# Spawned by wiki-session-end.sh. Holds a lock so concurrent session exits can
# never have two agents writing llm-wiki/pages/ at once. Whoever holds the lock
# drains the whole queue, so losing the race is safe: your job still gets done.
#
# Run it by hand any time to drain pending jobs, or with a transcript path to
# process one directly:
#     ~/.claude/hooks/wiki-ingest-run.sh [transcript.jsonl]
#
# Each ingest is committed to the wiki repo. Set WIKI_AUTO_COMMIT=0 to skip that
# and leave the changes in the working tree.

set -uo pipefail

HOOK_DIR="$HOME/.claude/hooks"
STATE_DIR="$HOOK_DIR/.wiki-state"
QUEUE_DIR="$STATE_DIR/queue"
LOCK_DIR="$STATE_DIR/lock"
LOG_FILE="$STATE_DIR/ingest.log"
WIKI_DIR="${LLM_WIKI_DIR:-$HOME/llm-wiki}"
TRIM="$HOOK_DIR/wiki-trim-transcript.py"

MIN_TRIMMED_BYTES=${WIKI_MIN_TRIMMED_BYTES:-2000}
STALE_LOCK_MINUTES=${WIKI_STALE_LOCK_MINUTES:-45}
MODEL=${WIKI_SCRIBE_MODEL:-sonnet}
MAX_TURNS=${WIKI_SCRIBE_MAX_TURNS:-60}
AUTO_COMMIT=${WIKI_AUTO_COMMIT:-1}

mkdir -p "$QUEUE_DIR" "$STATE_DIR" 2>/dev/null

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"; }

# One-off mode: process a transcript directly, no queue, no lock.
if [[ $# -ge 1 ]]; then
  printf '%s\n%s\n%s\n' "$1" "$PWD" "manual-$(date +%s)" \
    > "$QUEUE_DIR/manual-$(date +%s).job"
fi

# A lock left by a killed run would block ingests forever.
if [[ -d "$LOCK_DIR" ]] && \
   [[ -n "$(find "$LOCK_DIR" -maxdepth 0 -mmin "+$STALE_LOCK_MINUTES" 2>/dev/null)" ]]; then
  log "removing stale lock"
  rm -rf "$LOCK_DIR"
fi

# mkdir is atomic; losing the race means another drainer is running and will
# pick up our job when it drains the queue.
mkdir "$LOCK_DIR" 2>/dev/null || exit 0
trap 'rm -rf "$LOCK_DIR"' EXIT INT TERM

command -v claude >/dev/null 2>&1 || { log "claude CLI not on PATH; aborting"; exit 0; }
[[ -d "$WIKI_DIR" ]] || { log "wiki not found at $WIKI_DIR; aborting"; exit 0; }

# Committing is what makes an ingest visible. Without it the wiki reads as frozen
# at the last hand-made commit no matter how many sessions have landed, and
# there's no way to tell an agent's edits from your own.
#
# Signing is forced off: this runs unattended behind the lock, so a passphrase
# prompt would hang the drain until the stale-lock timer clears it.
git_wiki() { git -c commit.gpgsign=false -C "$WIKI_DIR" "$@"; }

# $1 subject, $2 body. A clean tree commits nothing, so an ingest that found
# nothing durable leaves no empty commit behind. Never fails the drain: an
# uncommitted wiki is a much smaller problem than a stuck queue.
wiki_commit() {
  [[ "$AUTO_COMMIT" == 1 ]] || return 0
  git_wiki rev-parse --git-dir >/dev/null 2>&1 || return 0

  git_wiki add -A >/dev/null 2>&1 || { log "git add failed; nothing committed"; return 0; }
  git_wiki diff --cached --quiet 2>/dev/null && return 0

  local files
  files=$(git_wiki diff --cached --name-status 2>/dev/null)

  if git_wiki commit -q -m "$1" -m "$2" -m "$files" >/dev/null 2>&1; then
    log "committed: $1"
  else
    log "git commit failed (identity unset?); changes left staged"
  fi
}

shopt -s nullglob
for job in "$QUEUE_DIR"/*.job; do
  { read -r transcript_path; read -r session_cwd; read -r session_id; } < "$job"
  rm -f "$job"

  [[ -f "$transcript_path" ]] || { log "skip $session_id: transcript gone"; continue; }

  trimmed="$STATE_DIR/trimmed-$session_id.md"
  if ! python3 "$TRIM" "$transcript_path" > "$trimmed" 2>>"$LOG_FILE"; then
    log "skip $session_id: trim failed"
    rm -f "$trimmed"
    continue
  fi

  tsize=$(stat -f%z "$trimmed" 2>/dev/null || stat -c%s "$trimmed" 2>/dev/null || echo 0)
  if [[ "$tsize" -lt "$MIN_TRIMMED_BYTES" ]]; then
    log "skip $session_id: trimmed to ${tsize}b, nothing to ingest"
    rm -f "$trimmed"
    continue
  fi

  log "ingesting $session_id (cwd=$session_cwd, trimmed=${tsize}b)"

  # Hand edits sitting in the tree would otherwise be swept into the ingest's own
  # commit and attributed to an agent that never touched them. Separating them
  # first keeps every ingest commit exactly what the scribe wrote.
  wiki_commit "Snapshot manual wiki edits" \
"Uncommitted work found in the tree when the automatic ingest pipeline ran.
Committed on its own so the ingest commit that follows contains only the
scribe's changes."

  # Run from inside the wiki so llm-wiki/CLAUDE.md loads as project instructions:
  # the ingest workflow and the "never write code" rule apply without being
  # restated here, and stay in one place when the schema changes.
  #
  # Bash and network tools are denied. This runs unattended; ingest needs to read
  # and write markdown, nothing else.
  today=$(date +%Y-%m-%d)
  read -r -d '' prompt <<PROMPT
A Claude Code session just ended. A trimmed transcript is at:
  $trimmed
The session's working directory was: $session_cwd

Follow the INGEST workflow in CLAUDE.md, with these session-digest specifics:

1. Read the trimmed transcript. Decide first whether anything in it is DURABLE —
   a decision and its reasoning, a gotcha worth not rediscovering, a change in a
   project's status, a new tool or person, a correction to something the wiki
   already asserts.

2. If nothing is durable, STOP. Write nothing — no source, no page, no log entry.
   Most sessions are routine work and produce nothing worth keeping. Say
   "nothing durable" and exit. This is the expected outcome and is not a failure.

3. If something is durable, write a SHORT digest to
   sources/$today-session-<slug>.md — a provenance header and the durable
   findings only. Not a play-by-play. Then ingest that digest into pages/ per
   CLAUDE.md.

   The provenance header records the date, session id $session_id, and the
   working directory. Do NOT cite the trimmed transcript path — it is deleted
   when this run finishes, and a source must not point at a file that no
   longer exists.

Hold the line on these:
- Prefer UPDATING existing pages. Status changes belong on the project's existing
  page, never on a new one.
- Any new page MUST get a line in pages/index.md, in the right section.
- Preserve existing uncertainty markers. Do not resolve an open question because
  a session sounded confident; a work session is weaker evidence than the user
  stating something directly.
- Never edit code in any repo. Read to verify, write only to the wiki.
- Append to log.md, noting this came from an automatic session ingest.
PROMPT

  (
    cd "$WIKI_DIR" || exit 0
    WIKI_SCRIBE_RUNNING=1 claude -p "$prompt" \
      --model "$MODEL" \
      --add-dir "$STATE_DIR" \
      --permission-mode bypassPermissions \
      --disallowedTools "Bash" "WebFetch" "WebSearch" "Task" \
      --max-turns "$MAX_TURNS" \
      >> "$LOG_FILE" 2>&1
  )

  status=$?
  log "finished $session_id (exit $status)"

  # Committed regardless of exit status. A run that hit --max-turns still leaves
  # real edits behind, and stranding those uncommitted is the failure this whole
  # step exists to prevent; the status line in the body says what happened.
  wiki_commit "Ingest session ${session_id%%-*} from $(basename "$session_cwd")" \
"Written by the automatic session-digest pipeline, not by hand. See
~/.claude/hooks/wiki-ingest-run.sh.

Session: $session_id
Working directory: $session_cwd
Scribe exit status: $status"

  rm -f "$trimmed"
done

# Keep the audit log from growing without bound.
if [[ -f "$LOG_FILE" ]]; then
  lsize=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
  if [[ "$lsize" -gt 2000000 ]]; then
    tail -n 2000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
  fi
fi

# Session markers are only needed to dedupe repeat SessionEnd events.
find "$STATE_DIR/seen" -type f -mtime +7 -delete 2>/dev/null

exit 0
