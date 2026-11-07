<p align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/memoteca-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="assets/memoteca-light.svg">
  <img src="assets/memoteca.svg" alt="Memoteca" width="320">
</picture>
</p>

# Memoteca

**Knowledge that carries across projects**

_Formerly claude-kb-workflow._

> Claude Code's native auto-memory is
> per-project and per-machine: the lesson you paid for in one repo never
> reaches the other twenty. This toolkit compiles sessions into a wiki and
> promotes a page to a stable, cross-project KB only when it passes the
> promotion exam: **used by 2+ projects, or a gotcha already paid for, or a
> declared standard, and in every case verified in production.**
>
> Skills frameworks like [Superpowers](https://github.com/obra/superpowers), GSD and gstack
> tell you *how to run* a session; this toolkit is about *what's left afterwards*.
> **They're complementary: they install side by side without conflicts**. See
> [the 2026 comparison](docs/comparison-2026.md).

**Memoteca** is an open-source knowledge pipeline for Claude Code
(sessions → LLM wiki → stable KB, in the Karpathy wiki tradition) for people
who maintain many unrelated projects alone. It ships with orchestrated
subagents, production patterns, and methodological skills, plus a write-up of
[a restore dry-run that failed](docs/knowledge-disaster-recovery.md), with the
four silent gaps it exposed. Docs in English and Italian.

[🇮🇹 Versione italiana più sotto](#-per-gli-sviluppatori-italiani)

---

## What this toolkit does

When you work with Claude Code across multiple projects, you keep hitting the same problems:

- **A lesson paid for in one repo never reaches the others**: Claude Code's auto-memory is per project and per machine
- **You repeat the same mistakes** across projects, because each one learns alone
- **Different stacks need different patterns**, but you write them all from memory every time
- **Architectural decisions** made months ago get forgotten

Memoteca solves this with 4 pieces that work together. The first
is the core; the other three are the gear that comes with it:

### 1. KB-driven system (`commands/` + `llm-wiki-template/`) — the core

5 commands (`/kb-ingest`, `/kb-query`, `/kb-promote`, `/kb-lint`, `/kb-output`) that orchestrate a 3-tier pipeline:

```
Real sessions (messy) → LLM Wiki (living synthesis) → Stable KB (authoritative truth)
                       ↑                             ↑
                       /kb-ingest                    /kb-promote
                                                     (only when mature)
```

An implementation of Karpathy's LLM Wiki pattern, with the layer missing from
the write-ups I found: **promotion to the stable KB through a promotion exam**.
A page qualifies when at least one of these holds: it is used by 2 or more
projects, it is a gotcha already paid for that would cost an hour or more to
hit again, or you declare it a standard. In every case it must also be verified
in production or on a real device. See [the full KB-driven workflow](docs/kb-driven-workflow.md),
[where each kind of information lives](docs/single-source-of-truth.md),
[the incremental review log](docs/incremental-review-log.md)
and the [knowledge disaster recovery](docs/knowledge-disaster-recovery.md).
Prefer slides? The same method as [an interactive presentation](https://thomascasali.github.io/presentazione-kb-workflow/?lang=en), in English and Italian.

### 2. Orchestrated subagents (`agents/`)

13 subagents **with valid YAML frontmatter** (name/description/model): Claude
registers them automatically and the main model (the **lead**) picks them
on its own based on the description. Three model tiers, and you move up only
for a reason you can state:

- **Haiku, the default**: `quick-worker` for small, closed jobs that a test or a command can prove
- **Sonnet**: `fast-worker` for an unknown cause, a choice between approaches, or wide changes; it is also the relaunch when Haiku comes back incomplete, with its work attached
- **Opus**: `deep-reasoner` for design, plans and a second opinion; it is the relaunch when Sonnet fails
- **10 multi-stack specialists**: `backend-dev`, `frontend-dev`, `mobile-dev`, `devops`, `database`, `integrations`, `realtime-dev`, `ci-cd` (Sonnet) + `reviewer`, `security` (Opus)

The full system is in [`docs/orchestration.md`](docs/orchestration.md): flat
delegation, the mandatory `reviewer` gate, the hierarchy of levers, and the
story of how corrupted frontmatter kept the whole thing dormant for months.

### 3. Patterns (`patterns/`)

**16 patterns** in [`patterns/patterns.md`](patterns/patterns.md), generalized from
production bugs on live sites so they hold up outside my own setup:
- Laravel/Express routing errors, a Flutter+Stripe Android gotcha, Docker bind-mount permissions
- Socket.io disconnects, a Cloudflare WAF bypass via self-hosted WARP, multi-tenant single-DB SaaS
- Internal SSO, sync-selector catch-22, cold-cache page speed, git/deploy over an unstable network, OTP e-signatures, FCM push without the server SDK, idempotent payment webhooks

The personal counterpart, [`patterns/field-notes-it.md`](patterns/field-notes-it.md),
is my own deploy scripts, env var naming and VPS quirks, in Italian, kept as a
worked example of a cross-project conventions file rather than as advice for you.

### 4. Methodological skills (`skills/`)

6 skills that Claude picks up from their description, when the description matches:
- `debugging-sistematico` — root cause before the fix
- `verifica-prima-di-completare` — evidence before declaring "done"
- `brainstorming-design` — design approval for non-trivial tasks
- `deploy-production` — unified Docker+Traefik workflow
- `flutter-production` — Flutter + Firebase / streaming / push
- `educational-presentation` — teaching presentations, React CDN / Vite

---

## Quick Start

### Installation

```bash
git clone https://github.com/thomascasali/memoteca.git
cd memoteca
./scripts/install.sh
```

The script copies agents, patterns, skills, and commands into `~/.claude/` (or `C:\Users\<you>\.claude\` on Windows).

**Restart Claude Code** and try:

```
"Show me the agent decision tree"
```

### (Optional) LLM Wiki setup

For the full KB-driven system:

```bash
cp -r llm-wiki-template ~/llm-wiki
export LLM_WIKI_PATH=~/llm-wiki
```

Then in Claude Code:
```
/kb-ingest project-name
```

---

## Philosophy

It doesn't impose a method and it doesn't replace your judgment. Install the
parts you want: agents, patterns and skills work without the wiki.

The patterns here come from production bugs, not from theory, and nothing
reaches the KB until it passes the promotion exam. Skills activate by
description: if one slows you down, narrow its trigger or delete it.

Deeper dive → [docs/filosofia.md](docs/filosofia.md) (in Italian)

---

## Compared to Superpowers, GSD and gstack

| Aspect | Superpowers | Memoteca |
|---------|-------------|---------------------|
| What it is | Methodological framework (TDD-strict, plan-driven) | Shared knowledge layer: KB + wiki + agents + patterns |
| **Concerned with** | **How you run *the* session** | **What remains AFTER the session** |
| Base unit | Skills that chain rigid phases | Agents, patterns, project-memory |
| Target | a disciplined loop inside one session | many unrelated projects over time |
| Language | English-only | English front door, native Italian docs |
| Extensibility | Add a phase = add a skill | Add an agent / pattern / project-memory |

**They're complementary, not alternatives.** The 3 methodological skills in
this repo (`debugging-sistematico`, `verifica-prima-di-completare`,
`brainstorming-design`) are **italianized, softened adaptations** of
Superpowers, integrated with the KB-driven workflow.

Deeper dive → [docs/comparison-2026.md](docs/comparison-2026.md)

---

## FAQ

### Doesn't Claude Code already have memory?

It does: auto memory is on by default and works well, per project, per
machine. That is exactly its limit. Each repo accumulates its own notes, and
what you learn in project A never reaches projects B through T. This toolkit
adds the layer above: a cross-project wiki and a stable KB that every
project's sessions can read, with an explicit promotion exam between the two.

### How is this different from CLAUDE.md?

CLAUDE.md is a single static file you maintain by hand, and it grows until it
becomes noise. This system separates fresh knowledge (wiki, updated per
session) from authoritative knowledge (KB, promoted only when it passes the promotion
exam), so what it reads is the part that held up.

### Memoteca vs Superpowers — which one do I need?

Both, if anything. Superpowers (like GSD and gstack) governs *how the agent
runs a session*: TDD, plans, guardrails. This toolkit governs *what survives
the session*: the knowledge. They install side by side without conflicts. See
[the 2026 comparison](docs/comparison-2026.md).

### Do I need the wiki to use the agents?

No. The subagents, patterns, and skills all work standalone: install
only what you need. The wiki→KB pipeline is the core of the system, but it's
opt-in: start with the agents, add the pipeline when you notice the same
lesson being relearned on a second project.

### Does this only work with Claude Code?

The engine is replaceable; the knowledge isn't. It's markdown, git and
conventions, so it should port to Cursor, Codex CLI or aider. I've only run
it in Claude Code. The most Claude Code-specific part is the subagent
mechanics; the role prompts and the policies port anywhere. Details in
[the workflow FAQ](docs/kb-driven-workflow.md).

---

## Repo structure

```
memoteca/
├── README.md                    # This file
├── TESTING-GUIDE.md             # Guide for people who want to test the toolkit
├── CONTRIBUTING.md              # How to contribute
├── LICENSE                      # MIT
├── .githooks/                   # pre-commit hook: secret scan on staged files
├── .gitattributes               # LF line endings for scripts, hook and scanner rules
├── agents/                      # 13 subagents with frontmatter
│   ├── README-AGENTI.md         # Decision tree + orchestration
│   ├── quick-worker.md          # Haiku: small, closed jobs (default)
│   ├── fast-worker.md           # Sonnet: unknown causes, choices, wide changes
│   ├── deep-reasoner.md         # Opus: design, plans, second opinion
│   ├── backend-dev.md           # Laravel + Node.js
│   ├── frontend-dev.md          # Vue + React
│   ├── mobile-dev.md            # Flutter
│   ├── devops.md                # Docker + Traefik + VPS
│   ├── database.md              # MySQL + MongoDB + PostgreSQL + Firestore
│   ├── reviewer.md              # Debugging + code review
│   ├── integrations.md          # Stripe, Email, Google, Push, AI
│   ├── security.md              # JWT + Auth + CORS
│   ├── realtime-dev.md          # Socket.io + WebSocket + MQTT
│   └── ci-cd.md                 # GitHub Actions: Android on a hosted runner, iOS on macOS (Codemagic as alternative)
├── patterns/                    # patterns + personal field notes
│   ├── patterns.md              # 16 generalized patterns (English)
│   └── field-notes-it.md        # personal conventions, Italian (worked example)
├── workflows/                   # Operational workflows
│   └── common-tasks.md
├── skills/                      # 6 custom skills
│   ├── debugging-sistematico/   # Root cause before the fix
│   ├── verifica-prima-di-completare/  # Evidence before "done"
│   ├── brainstorming-design/    # Design approval for non-trivial tasks
│   ├── deploy-production-skill/ # Unified Docker+Traefik
│   ├── flutter-production-skill/  # Flutter + Firebase + streaming
│   └── educational-presentation-skill/  # CDN/Vite slides
├── commands/                    # /kb-* slash commands
│   ├── kb-ingest.md
│   ├── kb-query.md
│   ├── kb-promote.md
│   ├── kb-lint.md
│   └── kb-output.md
├── llm-wiki-template/           # Template for the living wiki
│   ├── schema.md
│   ├── wiki/{projects,concepts,decisions,lessons}/
│   └── raw/sessions/
├── project-memories/            # Template + anonymized examples
│   ├── _template.md
│   └── esempio-saas-fittizio.md
├── docs/                        # Deep dives
│   ├── filosofia.md
│   ├── orchestration.md / orchestrazione.md        # Lead+subagent system, three model tiers
│   ├── single-source-of-truth.md / fonte-unica.md  # Where each kind of information lives
│   ├── incremental-review-log.md / review-log-incrementale.md  # Review only what changed since the last review
│   ├── knowledge-disaster-recovery.md / disaster-recovery-conoscenza.md  # 100%-restorable knowledge
│   ├── kb-driven-workflow.md / workflow-kb-driven.md    # + retroactive census from transcripts
│   └── comparison-2026.md / confronto-superpowers.md
└── scripts/
    ├── install.sh               # Interactive installation
    ├── backup.sh                # Sync ~/.claude/ → repo (for forks)
    ├── restore.sh               # Repo → ~/.claude/ (no overwrite without --force)
    ├── restore-test.sh          # Restore test on an empty temporary HOME
    ├── lib/secret-scan.sh       # Secret scanner, also used by .githooks/pre-commit
    └── test/                    # Scanner tests
```

---

## Testing and feedback

If you want to **test the toolkit** on one of your real projects, read the [full tester guide](TESTING-GUIDE.md) (in Italian).

Quick summary:
1. Install with `./scripts/install.sh`
2. Open Claude Code in one of your active projects
3. Try 3-5 real scenarios (bug fix, new feature, deploy)
4. Note: do the right agents/skills activate? Do they add real value?
5. Open a **GitHub Discussion** with your feedback

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) (in Italian). In short:

- New agent / skill → PR with a formatted SKILL.md + use-case description
- New pattern → PR to `patterns/patterns.md` if it holds up outside my setup, or to `patterns/field-notes-it.md` if it's a personal convention, with a real example
- Trigger bugs / false positives → open an Issue with the prompt that failed
- General feedback → GitHub Discussion

**Contribution language**: Italian or English. The core KB is in Italian, but
agents and skills can be in English if they serve stack-specific patterns.

Agent and skill content is currently Italian, while the architecture is
language-neutral (Claude reads Italian descriptions just fine regardless of
your language). **English translations are the most welcome contribution.**

---

## License

MIT. See [LICENSE](LICENSE). Fork it, modify it, redistribute it. If it's useful to you, a star on GitHub is appreciated.

---

## Credits

- **Methodological skills** (`debugging-sistematico`, `verifica-prima-di-completare`, `brainstorming-design`) adapted from [obra/superpowers](https://github.com/obra/superpowers) (MIT) and [mattpocock/skills](https://github.com/mattpocock/skills) (MIT)
- **Two-tier KB-driven pattern** inspired by Andrej Karpathy's discussions on managing LLM knowledge
- **Agent architecture** evolved from real work on web, mobile and IoT projects

---

**Updates**: Watch → Releases on this repo. No newsletter, no tracking.

<a name="italiano"></a>

## 🇮🇹 Per gli sviluppatori italiani

<p align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/memoteca-mark-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="assets/memoteca-mark-light.svg">
  <img src="assets/memoteca-mark.svg" alt="Memoteca" width="96">
</picture>
</p>

**Memoteca: la conoscenza che attraversa i progetti.** In precedenza claude-kb-workflow.

> L'auto-memory nativa di Claude Code
> è per-progetto e per-macchina: la lezione pagata su un repo non arriva mai
> agli altri venti. Questo toolkit compila le sessioni in una wiki e promuove
> una pagina alla KB stabile e trasversale solo quando supera l'esame di
> promozione: **usata da 2+ progetti, oppure un gotcha già pagato, oppure uno
> standard dichiarato, e in ogni caso verificata in produzione.**
>
> Gli skills framework come [Superpowers](https://github.com/obra/superpowers), GSD e gstack
> ti dicono *come eseguire* una sessione; questo toolkit si occupa di *cosa resta dopo*.
> **Sono complementari: si installano insieme senza conflitti**. Vedi
> [il confronto aggiornato al 2026](docs/confronto-superpowers.md).

I documenti di approfondimento hanno una versione italiana nativa:

- [docs/orchestrazione.md](docs/orchestrazione.md) — sistema lead + subagent
- [docs/workflow-kb-driven.md](docs/workflow-kb-driven.md) — sistema a 3 livelli sessione → wiki → KB
- [docs/disaster-recovery-conoscenza.md](docs/disaster-recovery-conoscenza.md) — conoscenza ripristinabile al 100%
- [docs/confronto-superpowers.md](docs/confronto-superpowers.md) — confronto con Superpowers/GSD/gstack
- [docs/fonte-unica.md](docs/fonte-unica.md) — dove vive ogni tipo di informazione
- [docs/review-log-incrementale.md](docs/review-log-incrementale.md) — rivedere solo ciò che è cambiato dall'ultima review
- [Presentazione interattiva](https://thomascasali.github.io/presentazione-kb-workflow/) — lo stesso metodo raccontato per gli studenti (italiano e inglese)

### Avvio rapido

```bash
git clone https://github.com/thomascasali/memoteca.git
cd memoteca
./scripts/install.sh
```

Poi riavvia Claude Code: agenti, pattern e skill sono da subito disponibili.

**Perché l'italiano**: questo toolkit è costruito anche per i miei studenti,
l'Italia ha poche risorse native su questi temi. La documentazione core nasce
in italiano e viene tradotta in inglese, non viceversa.

Per tutto il resto (cosa fa il toolkit, quick start, filosofia, struttura del
repo, come contribuire, licenza) vedi la sezione inglese qui sopra: è la
stessa identica cosa, solo in un'altra lingua.
