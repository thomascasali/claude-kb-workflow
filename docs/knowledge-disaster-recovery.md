# Knowledge disaster recovery

> 🇮🇹 Versione italiana: [docs/disaster-recovery-conoscenza.md](disaster-recovery-conoscenza.md)

> Goal: if your dev machine disappears tomorrow, you're fully operational again — at 100% —
> **including the knowledge accumulated with Claude Code**, not just the code.

## The principle

Everything of value lives in **private Git repos**; everything secret lives
**only in a password manager or in production servers' `.env` files**. The
rest (session transcripts, cache, local state) is disposable by design.

```
Restorable (private Git repos)            Disposable
─────────────────────────────────         ─────────────────────────
Stable KB (guides, patterns, agents,      Local session transcripts
  workflows, project-memories)            ~/.claude cache and state
LLM Wiki (compiled working memory)        Local .env files — ONLY IF every value
Snapshot of ~/.claude/CLAUDE.md             is in the vault or regenerable
Project repos                               (verify this BEFORE the disaster)

In the vault (never in repos)
─────────────────────────────
SSH keys · passwords · API keys · data encryption keys
```

## The two knowledge repos

1. **Stable KB** — the curated truth: operational guides, patterns, agents,
   workflows, and a **project memory per project** (status, gotchas,
   decisions). It's the repo this toolkit helps you build.
2. **LLM Wiki** — the working memory: pages compiled from sessions via
   `/kb-ingest`, promoted to the KB via `/kb-promote` once a pattern matures.
   See `llm-wiki-template/` and `docs/kb-driven-workflow.md`.

⚠️ Easy mistake: keeping the wiki **local only**. It's a Git repo just like
any other — give it a private remote from day one, or your working memory is
not restorable. (Yes, we've been burned by this.)

## The restore guide (write it BEFORE the disaster)

Keep a `DEV-MACHINE-RESTORE.md` file in the KB with:

1. **Prerequisites**: password manager, `git` + `gh auth login`, SSH key from the vault
2. **The knowledge clones**: the two repos above, with their conventional paths
3. **Claude Code config**: the `~/.claude/CLAUDE.md` snapshot (keep it in the KB
   repo, synced whenever you edit the original) + agents/skills from the toolkit
4. **Infrastructure map**: which projects run on which hosts, how to access
   them (no secrets: only *where* the secrets are)
5. **Toolchain**: the list of what needs installing (runtimes, CLIs, SDKs)
6. **What is NOT restorable** — stating this explicitly avoids panic:
   local transcripts don't come back, but if you ingest regularly the
   extracted knowledge is already in the wiki.

## Encryption keys are a special case

If your projects encrypt data (e.g. AES-256-GCM on sensitive data), the key
is **immutable and unrecoverable**: lose the key, lose the data. It goes in
the vault with a clear label, and the restore guide must name it explicitly.

## Testing the system

The honest test isn't "did I back it up?" but: *"opening the restore guide on
an empty machine, do I get back to working without asking anyone anything?"*
If the answer is no, something's missing — usually a config snapshot or an
unlabeled secret in the vault.

## The proof: a restore dry-run (mandatory, not optional)

"100% restorable" is a claim until you test it. The test costs ten minutes:
create an empty folder simulating a fresh machine's `~/.claude`, point the
restore script at it, run it, and VERIFY DEEPLY — not "the folders exist" but
"the files inside exist" (a skill is its `data/` and `scripts/`, not just its
`SKILL.md`).

Our first dry-run failed, surfacing four defects in one shot that a real
restore would have discovered at the worst possible moment:

1. **The script died halfway, silently**: `set -e` + one `cp` on an empty glob
   = stop with no visible error. Half the restore "succeeded".
2. **Shallow copies**: copying only `.md` files returns skills stripped of
   their core (`data/`, `scripts/`). They look restored; they don't work.
3. **Destructive overwrites**: the script touched state files owned by other
   systems. A restore must NEVER overwrite what it didn't create.
4. **Promised files never versioned**: the README listed a config file that
   had never been committed. Documentation is not a backup.

Taxonomy bonus from the drill — skills live on THREE tracks, and only two are
protected by default: (a) your own, versioned in the repo; (b) community ones
with a lock file, reinstallable; (c) **hand-installed ones, which live
nowhere** — inventory and version them, or be ready to lose them.

## Bonus: recovering knowledge that was never ingested

If you've worked for months without ingesting, Claude Code's local
transcripts (`~/.claude/projects/<project>/*.jsonl`) are a recoverable gold
mine: each line is a JSON object with the user/assistant messages. A
**retroactive census** — parallel reading agents, one per project, extracting
user requests and summaries — reconstructs the state of dozens of sessions in
an hour. Then you compile the wiki and promote what has matured. (Technique
described in `docs/kb-driven-workflow.md`.)
