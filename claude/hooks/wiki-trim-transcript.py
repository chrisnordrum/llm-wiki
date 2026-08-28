#!/usr/bin/env python3
"""Trim a Claude Code transcript to just the conversation.

A session transcript is dominated by tool_result payloads (file contents, command
output) that the scribe has no use for -- 99% of bytes in a typical session. This
keeps the human/assistant turns and a one-line trace of what tools ran, which is
everything needed to decide what was durable about a session.

Sessions too long to fit the cap are trimmed from the middle, not the end: what
a session decided lives in its last turns, and cutting the tail hands the scribe
a transcript that stops before the conclusions it is being asked to record.

Usage: wiki-trim-transcript.py <transcript.jsonl> [max_bytes]
Writes markdown to stdout.
"""

import json
import sys

MSG_CAP = 4000       # per-message char cap
TRACE_CAP = 160      # per-tool-call char cap
DEFAULT_MAX = 120_000
TAIL_SHARE = 0.6     # share of the budget reserved for the closing turns
TOOL_SHARE = 0.2     # floor on what's left for the tool trace when space is tight
ELISION = "…[{n} turns elided from the middle of this session]…\n\n"


def clip(text, cap):
    text = " ".join(str(text).split())
    return text if len(text) <= cap else text[:cap] + " …[clipped]"


def tool_target(name, inp):
    """The most identifying field of a tool call, without its payload."""
    if not isinstance(inp, dict):
        return ""
    for key in ("file_path", "command", "pattern", "path", "url", "prompt", "skill"):
        if key in inp:
            return clip(inp[key], TRACE_CAP)
    return clip(", ".join(sorted(inp)), TRACE_CAP)


def render_tools(uniq, budget):
    """The tool trace is context, not content, so it never crowds out conversation."""
    kept, used = [], 0
    for entry in uniq:
        line = f"- {entry}\n"
        if used + len(line) > budget:
            break
        kept.append(line)
        used += len(line)

    text = "## Tool activity (names and targets only)\n\n" + "".join(kept)
    if len(kept) < len(uniq):
        text += f"- …[{len(uniq) - len(kept)} more tool calls elided]"
    return text.rstrip("\n")


def select_turns(rendered, budget):
    """Fit whole turns into budget, keeping the opening and the closing ones.

    The tail gets the larger share because that is where a session states what it
    decided; the head is kept so the scribe still sees what the session set out to
    do. Whatever the tail doesn't need is handed back to the head, so a session
    with a short ending still gets a long beginning.

    Turns are kept whole -- a half-sentence is worse than a clean gap.
    Returns (head, tail, dropped_count).
    """
    if sum(len(r) for r in rendered) <= budget:
        return rendered, [], 0

    tail, used = [], 0
    for chunk in reversed(rendered):
        if used + len(chunk) > int(budget * TAIL_SHARE):
            break
        tail.append(chunk)
        used += len(chunk)
    tail.reverse()

    head, head_used = [], 0
    for chunk in rendered[: len(rendered) - len(tail)]:
        if head_used + len(chunk) > budget - used:
            break
        head.append(chunk)
        head_used += len(chunk)

    return head, tail, len(rendered) - len(head) - len(tail)


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: wiki-trim-transcript.py <transcript.jsonl> [max_bytes]")
    path = sys.argv[1]
    max_bytes = int(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_MAX

    out, tools = [], []
    try:
        fh = open(path, encoding="utf-8", errors="replace")
    except OSError as exc:
        sys.exit(f"cannot read transcript: {exc}")

    with fh:
        for line in fh:
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            kind = rec.get("type")
            if kind not in ("user", "assistant"):
                continue
            content = rec.get("message", {}).get("content")

            if isinstance(content, str):
                if content.strip():
                    out.append(("user", clip(content, MSG_CAP)))
                continue
            if not isinstance(content, list):
                continue

            for block in content:
                if not isinstance(block, dict):
                    continue
                btype = block.get("type")
                # thinking is private reasoning; tool_result is the bulk we drop
                if btype == "text" and block.get("text", "").strip():
                    out.append((kind, clip(block["text"], MSG_CAP)))
                elif btype == "tool_use":
                    tools.append(
                        f"{block.get('name', '?')}: {tool_target(block.get('name'), block.get('input'))}"
                    )

    header = "\n".join([
        "# Session transcript (trimmed)",
        "",
        f"_{len(out)} conversation turns, {len(tools)} tool calls._",
        "",
        "## Conversation",
        "",
        "",
    ])

    turns = [f"**{role}:** {text}\n\n" for role, text in out]
    # Reserved at its widest, since dropped can never exceed the total turn count.
    overhead = len(header) + len(ELISION.format(n=len(turns)))

    tool_text = ""
    if tools:
        seen, uniq = set(), []
        for entry in tools:
            if entry not in seen:
                seen.add(entry)
                uniq.append(entry)
        # The conversation has first claim: the trace gets whatever the turns
        # don't need, and only falls back to its floor when they need everything.
        spare = max_bytes - overhead - sum(len(t) for t in turns)
        tool_text = render_tools(uniq, max(spare, int(max_bytes * TOOL_SHARE)))

    head, tail, dropped = select_turns(turns, max(max_bytes - overhead - len(tool_text), 0))

    body = "".join(head)
    if dropped:
        body += ELISION.format(n=dropped)
    body += "".join(tail)

    result = header + body + tool_text
    if not tool_text:
        # Turns carry a trailing blank line that the tool section would consume.
        result = result.rstrip("\n") + "\n"
    sys.stdout.write(result)


if __name__ == "__main__":
    main()
