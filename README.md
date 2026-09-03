# llm-wiki

A personal wiki that an LLM builds and maintains for you — plus the automation to keep
it fed without you remembering to.

Inspired by [Andrej Karpathy's LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f),
which is where the core pattern comes from. This repo is that pattern made concrete,
with a session-ingest pipeline layered on top.

---

## The idea

Most LLM-over-documents setups retrieve chunks at **query time** and generate an answer
from them. The model rediscovers the same understanding on every question. Nothing
accumulates. Ask a subtle question twice, pay for it twice.

An LLM wiki inverts that. Each source gets **read, distilled, and integrated** into a
growing set of cross-linked markdown pages — once, on the way in. Contradictions get
flagged. Cross-references get maintained. The next question reads a page that's already
correct.

The reason people abandon hand-built wikis is bookkeeping: updating links, keeping
summaries current, noticing that page 12 now contradicts page 40. That's precisely the
work an LLM is good at and never gets bored doing.

```
your-wiki/
  CLAUDE.md    the schema — page format, linking rules, the four workflows
  sources/     raw, immutable inputs you ingest FROM
  pages/       the wiki — distilled, cross-linked markdown. The valuable part.
  log.md       append-only history of every action
```

## What you get

**Four workflows**, as slash commands:

| | |
|---|---|
| `/ingest <path \| URL \| text>` | read a source, distil it into pages, cross-link, log |
| `/query <question>` | a synthesized answer with citations to the pages it used |
| `/lint` | contradictions, stale claims, orphans, stubs, duplication, format drift |
| `/gaps` | interviews *you* for what the wiki structurally can't know |

**Cheap retrieval from any session.** A `wiki` skill and a read-only `wiki-librarian`
subagent, so a session working in some unrelated repo can ask your wiki a question and
get back an answer instead of a pile of pages. Retrieval always goes through
`pages/index.md` first — a full wiki never fits in context, and pretending otherwise is
the main way this goes wrong.

**Optional: automatic session ingest.** A `SessionEnd` hook that trims the ended
session's transcript, decides whether anything durable actually happened, and — usually
not — stops. When something did, it writes a digest and ingests it, then commits. This
is opt-in and [documented separately](SETUP.md#part-3--auto-ingest-opt-in), because it's
a lot of trust to grant on a first install.

## Setup

Follow **[SETUP.md](SETUP.md)**. Three parts, each independently useful, about seven
minutes total for the first two.

```bash
git clone https://github.com/chrisnordrum/llm-wiki.git
cd llm-wiki
```

## Obsidian (optional)

The format is Obsidian-native — `[[wikilinks]]`, YAML frontmatter, `aliases:` — so
backlinks and graph view work with no configuration. Open your wiki folder as a vault.
Claude edits the markdown, Obsidian renders it live, nothing conflicts.

## Why it's built this way

There's a [design notes](docs/design-notes.md) writeup covering the decisions that
weren't obvious: why the librarian is read-only and structurally can't write, why the
`SessionEnd` hook does almost nothing, the reentrancy trap that makes an ingest pipeline
spawn itself forever, and why transcripts get trimmed from the middle rather than the
end. Also the things I measured and then deliberately *didn't* build.

## Credit

**The LLM Wiki pattern is [Andrej Karpathy](https://github.com/karpathy)'s**, introduced in
[this gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f). The three
layers, the ingest / query / lint workflows, and the central argument for compounding
synthesis over query-time re-derivation are all from there. This repo is an implementation
of that pattern, and it exists because the idea was worth building.

What's mine is only the automation layered on top: the session-ingest pipeline, the
reader/writer agent split, and the `/gaps` workflow.

## License

MIT — see [LICENSE](LICENSE).
