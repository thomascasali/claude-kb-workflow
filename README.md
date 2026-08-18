# claude-kb-workflow

> **The memory system for Claude Code**: the wiki → KB knowledge pipeline
> (Karpathy pattern, running in production since April 2026 across 15+ real
> projects) so the next session starts from what the last one learned,
> bundled with 12 orchestrated subagents, 30 patterns battle-tested
> in production, and 6 methodological skills.
>
> Skills frameworks like [Superpowers](https://github.com/obra/superpowers), GSD and gstack
> tell you *how to run* a session; this toolkit is about *what's left afterwards*.
> **They're complementary: they install side by side without conflicts**. See
> [the 2026 comparison](docs/comparison-2026.md).

**claude-kb-workflow** is an open-source memory system for Claude Code: a
three-tier pipeline (sessions → LLM wiki → stable KB) where knowledge is
promoted only after being verified in production on 2+ projects. Running since
April 2026 on 15+ live products, it bundles orchestrated subagents, patterns
paid for in production, and methodological skills. Docs in English and Italian.

[🇮🇹 Versione italiana più sotto](#-per-gli-sviluppatori-italiani)

---

## What this toolkit does

When you work with Claude Code across multiple projects, you keep hitting the same problems:

- **You lose context** between one session and the next
- **You repeat the same mistakes** because there's no memory of lessons learned
- **Different stacks need different patterns**, but you write them all from memory every time
- **Architectural decisions** made months ago get forgotten

`claude-kb-workflow` solves this with 4 pieces that work together. The first
is the core; the other three are the gear that comes with it:

### 1. KB-driven system (`commands/` + `llm-wiki-template/`) — the core

5 commands (`/kb-ingest`, `/kb-query`, `/kb-promote`, `/kb-lint`, `/kb-output`) that orchestrate a 3-tier pipeline:

```
Real sessions (messy) → LLM Wiki (living synthesis) → Stable KB (authoritative truth)
                       ↑                             ↑
                       /kb-ingest                    /kb-promote
                                                     (only when mature)
```

An implementation of Karpathy's LLM Wiki pattern (which went viral in April
2026; this pipeline has been running since that same month, and the toolkit
has shipped it since May), with the layer missing from the write-ups I found:
**promotion to the stable KB with maturity criteria** (2+ projects, verified
in production). See [the full KB-driven workflow](docs/kb-driven-workflow.md)
and the [knowledge disaster recovery](docs/knowledge-disaster-recovery.md).
Prefer slides? The same method as [an interactive presentation in five acts](https://thomascasali.github.io/presentazione-kb-workflow/?lang=en), in English and Italian.

### 2. Orchestrated subagents (`agents/`)

12 subagents **with valid YAML frontmatter** (name/description/model): Claude
registers them automatically and the main model (the **lead**) picks them
on its own based on the description. Two tiers:

- **Orchestrators**: `deep-reasoner` (Opus, reasoning phases) and `fast-worker` (Sonnet, mechanical work)
- **10 multi-stack specialists**: `backend-dev`, `frontend-dev`, `mobile-dev`, `devops`, `database`, `integrations`, `realtime-dev`, `ci-cd` (Sonnet) + `reviewer`, `security` (Opus)

The full system is in [`docs/orchestration.md`](docs/orchestration.md): flat
delegation, the mandatory `reviewer` gate, the hierarchy of levers, and the
story of how corrupted frontmatter kept the whole thing dormant for months.

### 3. Critical patterns (`patterns/`)

**30 patterns** and antipatterns captured from real production experience
(live sites like fivbeach.com, maraffaonline.it, tornei.app):
- Laravel/Express routing errors, Vite pitfalls, Docker bind-mount permissions
- Socket.io, MongoDB, Firestore, MQTT, WAF bypass via WARP
- Multi-tenant single-DB, internal SSO/IdP, sync-selector catch-22, cold-cache page speed, git/deploy on an unstable VPS, FEA-OTP
  signing, web push via FCM without an SDK, idempotent payment webhooks

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
git clone https://github.com/thomascasali/claude-kb-workflow.git
cd claude-kb-workflow
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
reaches the KB until it has held up on a second project. Skills activate by
description: if one slows you down, narrow its trigger or delete it.

Deeper dive → [docs/filosofia.md](docs/filosofia.md) (in Italian)

---

## Compared to Superpowers, GSD and gstack

| Aspect | Superpowers | claude-kb-workflow |
|---------|-------------|---------------------|
| What it is | Methodological framework (TDD-strict, plan-driven) | Memory system: KB + wiki + agents + patterns |
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

### Does Claude Code remember anything between sessions?

Within a session, the context window remembers everything. Between sessions,
nothing survives: the knowledge stays locked in each chat. This toolkit fixes
that with a pipeline that compiles sessions into a living wiki and promotes
mature knowledge to a stable KB that every future session can read.

### How is this different from CLAUDE.md?

CLAUDE.md is a single static file you maintain by hand, and it grows until it
becomes noise. This system separates fresh knowledge (wiki, updated per
session) from authoritative knowledge (KB, promoted only when verified in
production on 2+ projects), so what it reads is the part that held up.

### claude-kb-workflow vs Superpowers — which one do I need?

Both, if anything. Superpowers (like GSD and gstack) governs *how the agent
runs a session*: TDD, plans, guardrails. This toolkit governs *what survives
the session*: the memory. They install side by side without conflicts. See
[the 2026 comparison](docs/comparison-2026.md).

### Do I need the wiki to use the agents?

No. The subagents, patterns, and skills all work standalone: install
only what you need. The wiki→KB pipeline is the core of the system, but it's
opt-in: start with the agents, add the memory when you feel the amnesia tax.

### Does this only work with Claude Code?

The engine is replaceable; the memory isn't. It's markdown, git and
conventions, so it should port to Cursor, Codex CLI or aider. I've only run
it in Claude Code. The most Claude Code-specific part is the subagent
mechanics; the role prompts and the policies port anywhere. Details in
[the workflow FAQ](docs/kb-driven-workflow.md).

---

## Repo structure

```
claude-kb-workflow/
├── README.md                    # This file
├── TESTING-GUIDE.md             # Guide for people who want to test the toolkit
├── CONTRIBUTING.md              # How to contribute
├── LICENSE                      # MIT
├── agents/                      # 12 subagents with frontmatter
│   ├── README-AGENTI.md         # Decision tree + orchestration
│   ├── deep-reasoner.md         # Opus — reasoning phases (NEW)
│   ├── fast-worker.md           # Sonnet — mechanical work (NEW)
│   ├── backend-dev.md           # Laravel + Node.js
│   ├── frontend-dev.md          # Vue + React
│   ├── mobile-dev.md            # Flutter
│   ├── devops.md                # Docker + Traefik + VPS
│   ├── database.md              # MySQL + MongoDB + PostgreSQL + Firestore
│   ├── reviewer.md              # Debugging + code review
│   ├── integrations.md          # Stripe, Email, Google, Push, AI
│   ├── security.md              # JWT + Auth + CORS
│   ├── realtime-dev.md          # Socket.io + WebSocket + MQTT
│   └── ci-cd.md                 # GitHub Actions + Codemagic
├── patterns/                    # 30 critical patterns
│   └── critical-patterns.md
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
│   ├── orchestration.md / orchestrazione.md        # Lead+subagent system
│   ├── knowledge-disaster-recovery.md / disaster-recovery-conoscenza.md  # 100%-restorable knowledge
│   ├── kb-driven-workflow.md / workflow-kb-driven.md    # + retroactive census from transcripts
│   └── comparison-2026.md / confronto-superpowers.md
└── scripts/
    ├── install.sh               # Interactive installation
    └── backup.sh                # Sync ~/.claude/ → repo (for forks)
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
- New pattern → PR to `patterns/critical-patterns.md` with a real example
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

- **Methodological skills** (`debugging-sistematico`, `verifica-prima-di-completare`, `brainstorming-design`) adapted from [obra/superpowers](https://github.com/obra/superpowers) (MIT)
- **Two-tier KB-driven pattern** inspired by Andrej Karpathy's discussions on managing LLM knowledge
- **Agent architecture** evolved from years of real work on web/mobile/IoT projects

---

**Updates**: Watch → Releases on this repo. No newsletter, no tracking.

<a name="italiano"></a>

## 🇮🇹 Per gli sviluppatori italiani

> **Il sistema di memoria per Claude Code**: la pipeline di conoscenza wiki → KB
> (pattern Karpathy, in produzione da aprile 2026 su 15+ progetti reali) che fa
> sì che la sessione dopo parta da quello che ha imparato la precedente, con a corredo
> 12 subagent orchestrati, 30 pattern pagati in produzione e 6 skill metodologiche.
>
> Gli skills framework come [Superpowers](https://github.com/obra/superpowers), GSD e gstack
> ti dicono *come eseguire* una sessione; questo toolkit si occupa di *cosa resta dopo*.
> **Sono complementari: si installano insieme senza conflitti**. Vedi
> [il confronto aggiornato al 2026](docs/confronto-superpowers.md).

I 4 documenti di approfondimento hanno una versione italiana nativa:

- [docs/orchestrazione.md](docs/orchestrazione.md) — sistema lead + subagent
- [docs/workflow-kb-driven.md](docs/workflow-kb-driven.md) — sistema a 3 livelli sessione → wiki → KB
- [docs/disaster-recovery-conoscenza.md](docs/disaster-recovery-conoscenza.md) — conoscenza ripristinabile al 100%
- [docs/confronto-superpowers.md](docs/confronto-superpowers.md) — confronto con Superpowers/GSD/gstack
- [Presentazione interattiva in cinque atti](https://thomascasali.github.io/presentazione-kb-workflow/) — lo stesso metodo raccontato per gli studenti (italiano e inglese)

### Avvio rapido

```bash
git clone https://github.com/thomascasali/claude-kb-workflow.git
cd claude-kb-workflow
./scripts/install.sh
```

Poi riavvia Claude Code: agenti, pattern e skill sono da subito disponibili.

**Perché l'italiano**: questo toolkit è costruito anche per i miei studenti,
l'Italia ha poche risorse native su questi temi. La documentazione core nasce
in italiano e viene tradotta in inglese, non viceversa.

Per tutto il resto (cosa fa il toolkit, quick start, filosofia, struttura del
repo, come contribuire, licenza) vedi la sezione inglese qui sopra: è la
stessa identica cosa, solo in un'altra lingua.
