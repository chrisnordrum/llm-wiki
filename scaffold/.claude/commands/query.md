---
description: Answer a question from the wiki, with citations
argument-hint: <your question>
---

Answer this question using the wiki:

$ARGUMENTS

Follow the **QUERY** workflow in `CLAUDE.md`:

1. Search `pages/` and follow `[[links]]` to gather relevant context.
2. Synthesize a grounded answer and cite the pages you used (e.g. "per [[page-slug]]").
   If the wiki doesn't cover it, say so and suggest what to ingest.
3. If your answer contains genuinely new, durable synthesis, offer to file it as a page.
4. Append a QUERY entry to `log.md`.
