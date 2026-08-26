# claude-kb-workflow in the 2026 landscape (Superpowers, GSD, gstack)

> 🇮🇹 Versione italiana: [docs/confronto-superpowers.md](confronto-superpowers.md)

> A frank assessment of the different approaches, written by someone who **adopted and adapted** parts of Superpowers into `claude-kb-workflow`. Updated: **August 2026**.

---

## The 2026 landscape in brief

In 2026, "skills frameworks" for Claude Code became a mainstream category.
Three names dominate the conversation — the community's summary: **"gstack thinks, GSD
stabilizes, Superpowers executes"**:

- **[Superpowers](https://github.com/obra/superpowers)** (~265k ⭐, very active development) — THE methodological framework: TDD-strict, plan-driven, strong guardrails. If you write code professionally, it's the category's starting point.
- **GSD** — oriented toward workflow stabilization.
- **gstack** — oriented toward thinking/multi-product work (solo founders running multiple products).

In parallel, **agent collections have become commoditized**: toolkits with
100-135 ready-made agents exist. Competing on agent count no longer makes
sense for anyone.

**Where `claude-kb-workflow` sits**: in a different category — the
**cross-project knowledge layer**. Skills frameworks tell you *how to run* a session; this repo is
about what's left after the session: the wiki→KB pipeline (Karpathy
pattern, which went viral in April 2026 — our implementation has been
running since that same month), patterns
battle-tested in production, knowledge disaster recovery. **They install
side by side without conflicts: their execution method, our knowledge layer.**

---

## TL;DR

| | Superpowers | claude-kb-workflow |
|---|-------------|---------------------|
| **What it is** | Methodological framework | Memory system: KB + wiki + agents + patterns |
| **Philosophy** | Imposes a disciplined workflow | Captures experience and makes it reusable |
| **Direction** | Top-down (rules → practice) | Bottom-up (practice → rules) |
| **Concerned with** | How you run THE session | What remains AFTER the session |
| **Ideal target** | SaaS teams with weak discipline | Solo devs and small multi-project teams |
| **Language** | English-only | English front door, native Italian docs |

**They're not competitors** — they're complementary by construction. The 3
methodological skills in `claude-kb-workflow` are **italianized, softened
adaptations** of Superpowers.

> ⚠️ Freshness note: the detail sections below are a snapshot of Superpowers as of
> **May 2026** (14 skills). The project evolves quickly: verify against the
> official repo before citing numbers. The comparison's philosophy remains valid.

---

## What Superpowers is

[Superpowers](https://github.com/obra/superpowers) is an **agentic development
framework** created by Jesse Vincent. It imposes a structured, phased workflow:

```
brainstorming → writing-plans → executing-plans → test-driven-development
→ systematic-debugging → verification-before-completion
→ requesting/receiving-code-review → using-git-worktrees
→ finishing-a-development-branch
```

14 skills total, with meta-skills `writing-skills`, `using-superpowers`, `subagent-driven-development`, `dispatching-parallel-agents`.

### Superpowers' strengths

✅ **Discipline**: forces the agent not to skip steps (no fixes without root cause, no completion claims without verification)
✅ **Consistency**: the workflow is always the same, predictable
✅ **Error reduction**: strong guardrails drastically reduce "I declared it done but it doesn't work"
✅ **TDD-first**: where TDD applies, guarantees test coverage
✅ **Team-friendly**: the uniform structure eases collaboration

### Superpowers' weaknesses

❌ **Rigidity**: applying TDD + planning + formal review even to 5-minute tasks is overhead
❌ **"ALWAYS/NEVER" philosophy**: imperative rules ("ALWAYS find root cause", "NO COMPLETION CLAIMS WITHOUT VERIFICATION") generate frustration on edge cases
❌ **Language**: English only
❌ **Stack-agnostic but not quite**: implicitly designed for SaaS projects with mature CI/CD, less suited to teaching / IoT / scripting
❌ **Heavy onboarding**: 14 skills to absorb, self-referencing meta-skills

---

## What claude-kb-workflow is

`claude-kb-workflow` starts from the opposite premise: **not a framework, but a shared memory**.

```
12 subagents (2 orchestrators + 10 specialists) (what to do per stack)
+ 16 patterns (what to avoid, generalized from real experience)
+ 6 methodological skills (how to reason, lightly)
+ KB-driven system (how to accumulate knowledge over time)
```

### claude-kb-workflow's strengths

✅ **Real patterns**: every pattern comes from actual production bugs, not theory
✅ **Stratification**: explicit separation between fresh knowledge (wiki) and authoritative knowledge (KB)
✅ **Multi-stack**: explicit support for Laravel, Node, Vue, React, Flutter, Docker, MySQL/Mongo/PostgreSQL, IoT
✅ **Italian**: built for the Italian community, accessible to vocational-school (ITIS) students
✅ **Modular**: install only the parts you need
✅ **Self-tunable**: descriptive triggers that the user can refine

### claude-kb-workflow's weaknesses

❌ **Less disciplined**: contextual triggers are softer than imperative rules — a "sloppy" agent can ignore them
❌ **Requires more maturity**: the user must know when to apply a pattern and when not to
❌ **Complex KB-driven setup**: the 3-tier system (session → wiki → KB) requires upfront investment
❌ **Young project**: far fewer users and contexts than Superpowers
❌ **No official plugin marketplace integration** (for now)

---

## How they compare on the 3 shared skills

`claude-kb-workflow` includes 3 methodological skills **derived from
Superpowers** but adapted. Let's look at them one by one.

### `systematic-debugging` (Superpowers) vs `debugging-sistematico` (kb-workflow)

| | Superpowers | kb-workflow |
|---|-------------|-------------|
| **Language** | English | Italian |
| **Tone** | "NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST" (imperative) | "Symptom fixes fail" (principle + examples) |
| **Trigger** | Generic | Explicit on when to activate AND when NOT to |
| **Specific cases** | No | Yes (Laravel, Node, Flutter, Docker) |
| **Stop rule** | Identical (3 failed fixes → stop) | Identical |

### `verification-before-completion` (Superpowers) vs `verifica-prima-di-completare` (kb-workflow)

| | Superpowers | kb-workflow |
|---|-------------|-------------|
| **Language** | English | Italian |
| **Tone** | "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE" | "Evidence before you call it done" |
| **Exceptions** | Not explicit | Explicit (exploration, research-only) |
| **Specific cases** | Generic | Per-stack (Laravel tests, Flutter analyze, Docker compose config, browser load) |

### `brainstorming` (Superpowers) vs `brainstorming-design` (kb-workflow)

| | Superpowers | kb-workflow |
|---|-------------|-------------|
| **Language** | English | Italian |
| **When to activate** | "Even simple projects benefit" | Explicitly NOT for pinpoint edits, trivial fixes, explicit instructions |
| **Number of questions** | One at a time, sequential, long | 2-3 targeted, no rapid-fire questioning |
| **Proposed approaches** | Generic | 2-3 with explicit trade-offs |
| **"Educational presentations" case** | Doesn't exist | Specific case documented |

**Insight**: the main practical difference is that the adapted versions are
**less aggressive on triggers**. They're designed to activate when actually
needed, not on every request.

---

## What Superpowers has that claude-kb-workflow doesn't

| Superpowers feature | Status in kb-workflow |
|---------------------|-----------------------|
| `test-driven-development` | Not present as a dedicated skill — the principle is included in `debugging-sistematico` |
| `writing-plans` / `executing-plans` | Not present — replaced by the native `Plan` agent + the community's `planning-with-files` |
| `using-git-worktrees` | Not present — Claude Code supports it natively |
| `subagent-driven-development` | Not present — replaced by thematic agents + the native `Agent` tool |
| `dispatching-parallel-agents` | Not present — the native `Agent` tool allows parallelism |
| `requesting-code-review` / `receiving-code-review` | Replaced by the `reviewer` agent + native `/review` / `/ultrareview` |
| `finishing-a-development-branch` | Not present — generic git workflow |
| `writing-skills` | Replaced by the official `anthropic-skills:skill-creator` |
| `using-superpowers` (meta) | Useless without the full framework |

In short: 9 of Superpowers' 14 skills are **duplicated by Claude Code's
native features** or covered by other toolkits. That's why
`claude-kb-workflow` doesn't include them.

---

## What claude-kb-workflow has that Superpowers doesn't

| kb-workflow feature | Status in Superpowers |
|---------------------|----------------------|
| **12 subagents (2 orchestrators + 10 specialists) for specific stacks** | Not present — Superpowers is stack-agnostic |
| **16 patterns generalized from real production** | Not present |
| **`deploy-production-skill`** (Docker+Traefik) | Not present |
| **`flutter-production-skill`** (Firebase, streaming, push) | Not present |
| **`educational-presentation-skill`** (teaching slides) | Not present |
| **3-tier KB-driven system** | Not present |
| **5 `/kb-*` commands** | Not present |
| **Project memory template** | Not present |
| **Italian documentation** | Not present |

In short: kb-workflow is **more complete on the "knowledge" side** and **less
complete on the "methodology" side**.

---

## Can they coexist?

**Yes, and `claude-kb-workflow` demonstrates it**:

1. Superpowers' 3 methodological skills (adapted) are included
2. Superpowers' other 11 skills can be installed manually alongside
3. The KB-driven system doesn't conflict with the Superpowers workflow — if anything, it enriches it
4. Per-stack agents are **complementary** to Superpowers' methodological skills

Realistic scenario:
```
Laravel + Vue + Flutter developer
├── claude-kb-workflow (this repo) → installs agents + patterns + KB-driven
├── Superpowers (optional) → installs additional methodological skills (TDD, plans, etc.)
└── Anthropic skills (official) → pptx, docx, xlsx, pdf
```

---

## Which one should you choose?

### Choose Superpowers if:
- You work mainly in English
- You want a complete, turnkey framework
- You appreciate rigid discipline (strict TDD, plan-driven)
- Your stack is generic (web SaaS, no IoT/teaching/embedded)
- You have a team that wants uniformity

### Choose claude-kb-workflow if:
- You want documentation and patterns in Italian
- You work across many projects with different stacks
- You prefer accumulating knowledge over time (KB-driven)
- You have real production patterns to capture
- You want a modular toolkit (install only what you need)

### Choose both if (the most common case):
- You want the best of both worlds: **an execution framework + a shared knowledge layer**
- Your problem isn't "how does the agent work within a session" but "why am I
  making the same mistakes I made three months ago" → no skills framework
  covers that part
- You have time to learn 2 systems (kb-workflow's onboarding is lighter: you
  start with agents + patterns, and add the wiki→KB pipeline when you need it)

---

## Acknowledgments

Thanks to Jesse Vincent ([@obra](https://github.com/obra)) for publishing Superpowers under the MIT license. The 3 skills in this repo (`debugging-sistematico`, `verifica-prima-di-completare`, `brainstorming-design`) are adaptations of his (`systematic-debugging`, `verification-before-completion`, `brainstorming`) — the credit for the ideas is his; the adaptation — and anything that got worse in translation — is mine.
