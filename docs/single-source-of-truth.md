# Single source of truth: where each kind of information lives

> 🇮🇹 Versione italiana: [docs/fonte-unica.md](fonte-unica.md)

> Every piece of information has one home. Every other place links to it instead of copying it.

## Why

With a wiki, a stable KB, per-project memory files, repo docs and Claude Code's own
auto-memory, the same fact tends to end up in four places. Then one copy gets updated
and the others quietly go stale. The fix is a table you write once: for each kind of
information, which place is the source, and what the other places are allowed to hold.

## The table

| Kind of information | Single source | What the other places may hold |
|---|---|---|
| **Current state of a project**: phase, version (from the git tag), what is live, next steps, date | `wiki/projects/<slug>.md`, section "Current state" | index: one line; project memory: a link to the wiki page |
| **Stable facts about a project**: stack, repos, deploy, URLs, commands, gotchas, key decisions | KB `project-memories/<slug>.md` | wiki page: one line linking to the project memory |
| **Review log** of a project | KB `project-memories/<slug>.md`, section "Review log" | nothing; never in the repo's `docs/` (see [incremental review log](incremental-review-log.md)) |
| **Working instructions** for a repo | the repo's `CLAUDE.md` | no versions and no status: those live in the wiki page |
| **Project documentation**: architecture, the project's own ADRs, manuals | the repo's `docs/` | wiki: a link, or a summary made at ingest |
| **Your feedback and preferences** about how Claude should work on a project | Claude Code's local auto-memory | only this; a general fact, or one already written in its source, is not saved there |
| **Inventory and state of shared resources**: servers, DNS, accounts, backups | `wiki/infra/<resource>.md` | project memories and project pages: a link only |
| **Operating procedures** on shared resources, and reusable guides | KB `knowledge-base/<GUIDE>.md` (plus `workflows/` and skills) | wiki infra or concept page: a link to the guide |
| **Cross-project pattern that is not yet a guide** | `wiki/concepts/<slug>.md` | nothing |
| **Cross-project architectural decision** | `wiki/decisions/` | project memory: a list of links |
| **Post-mortem or dated lesson** | `wiki/lessons/` | log: one line |
| **Chronology and history** | a summary page in the wiki, plus git | nothing |
| **Secrets** | the password manager, or the server's `.env` | everywhere else: only where the secret lives, never its value |
| **Note from a temporary session** (for example a cloud or throwaway one) | `docs/kb-handoff/` in the project repo | folded into the wiki by hand (`/kb-ingest` does not read `docs/kb-handoff/`), then removed |

`wiki/infra/` is not in the starter template. Create it when you have shared resources to inventory.

## Rules that keep the table honest

1. **Link, don't copy.** If you catch yourself pasting a version number into a second file, replace it with a link.
2. **State and facts are different files.** "What is live today" changes weekly and sits in the wiki. "What stack it runs on" changes rarely and sits in the project memory.
3. **A promoted concept stays in the wiki with a pointer note.** `/kb-promote` adds a "Promoted to ..." line with the destination to the concept, and an entry in the log. It does not empty the concept: keeping new gotchas out of it, and writing them only in the guide, is up to you. See the [KB-driven workflow](kb-driven-workflow.md).
4. **Auto-memory stays small.** Claude Code's auto-memory is for feedback and preferences. If a fact belongs in one of the rows above, write it there.
5. **Secrets are the exception that proves the rule.** Even the pointer says where the secret is, not what it is.

## Adapting it

The table is a starting point. Rename the places to match your setup, and delete rows you do not need. What matters is that
every row has exactly one source, and that you can answer "where do I update this?" without thinking.
