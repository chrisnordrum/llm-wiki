#!/bin/bash
# SessionEnd hook -> queue a session for wiki ingest.
#
# SessionEnd shares a 1.5s budget across all hooks, so this script does nothing
# but cheap gating: it drops a job file and detaches. All real work happens in
# wiki-ingest-run.sh.
#
# Exits 0 in every path. A wiki ingest is never worth disrupting a session exit.

set -uo pipefail

HOOK_DIR="$HOME/.claude/hooks"
STATE_DIR="$HOOK_DIR/.wiki-state"
QUEUE_DIR="$STATE_DIR/queue"
SEEN_DIR="$STATE_DIR/seen"
WIKI_DIR="${LLM_WIKI_DIR:-$HOME/llm-wiki}"

# The detached run is itself a Claude Code session. Without this guard its own
# SessionEnd fires this hook, which queues another run, forever.
[[ -n "${WIKI_SCRIBE_RUNNING:-}" ]] && exit 0

# A raw transcript below this is a session too short to have learned anything.
MIN_TRANSCRIPT_BYTES=${WIKI_MIN_TRANSCRIPT_BYTES:-30000}

payload=$(cat 2>/dev/null)
[[ -z "$payload" ]] && exit 0

eval "$(printf '%s' "$payload" | python3 -c '
import json, shlex, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for key in ("session_id", "reason", "cwd", "transcript_path"):
    print("%s=%s" % (key, shlex.quote(str(d.get(key, "")))))
' 2>/dev/null)"

[[ -z "${session_id:-}" || -z "${transcript_path:-}" ]] && exit 0

# clear/resume are mid-work events, not "I'm done". bypass_permissions_disabled
# is a mode toggle. Only real exits should produce a source.
case "${reason:-}" in
  clear | resume | bypass_permissions_disabled) exit 0 ;;
esac

# Sessions run from inside the wiki already write to it directly; ingesting them
# would record the librarian's own bookkeeping as knowledge.
case "${cwd:-}" in
  "$WIKI_DIR" | "$WIKI_DIR"/*) exit 0 ;;
esac

[[ -f "$transcript_path" ]] || exit 0

size=$(stat -f%z "$transcript_path" 2>/dev/null || stat -c%s "$transcript_path" 2>/dev/null || echo 0)
[[ "$size" -lt "$MIN_TRANSCRIPT_BYTES" ]] && exit 0

mkdir -p "$QUEUE_DIR" "$SEEN_DIR" 2>/dev/null || exit 0

# One ingest per session, even if SessionEnd fires more than once.
[[ -e "$SEEN_DIR/$session_id" ]] && exit 0
: > "$SEEN_DIR/$session_id"

printf '%s\n%s\n%s\n' "$transcript_path" "$cwd" "$session_id" \
  > "$QUEUE_DIR/$session_id.job" 2>/dev/null || exit 0

# Detach and return immediately. The drainer serialises itself with a lock, so
# spawning one per session end is safe -- extra ones exit as soon as they lose
# the race, and whoever holds the lock drains their job too.
nohup "$HOOK_DIR/wiki-ingest-run.sh" >/dev/null 2>&1 &
disown 2>/dev/null

exit 0
