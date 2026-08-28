---
description: Health-check the wiki — contradictions, stale claims, orphans, stubs, dupes
argument-hint: (optional) "fix" to apply fixes after reporting
---

Run the **LINT** workflow from `CLAUDE.md` over `pages/`.

Scan every page and produce a concise report grouped by category:
- Contradictions between pages
- Stale claims (old `updated:` dates or time-sensitive statements)
- Orphans (pages nothing links to, or that link to nothing)
- Stubs (`[[links]]` with no matching page — candidates to create)
- Duplication (pages covering the same entity/concept — candidates to merge)
- Format drift (missing frontmatter, wrong `type`, broken links)

Only apply fixes if I said "fix" ($ARGUMENTS) or after I confirm. Do not delete or merge
pages without explicit go-ahead.
