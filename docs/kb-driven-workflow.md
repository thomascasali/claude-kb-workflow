# KB-driven workflow

> 🇮🇹 Versione italiana: [docs/workflow-kb-driven.md](workflow-kb-driven.md)

> How the 3-tier system (session → wiki → stable KB) works, and why.

---

## The problem

When you work with an agentic LLM, knowledge emerges **continuously**:

- You fix a bug → you learn a lesson
- You make a decision → it has a rationale you'll forget
- You find a pattern → it will recur on other projects

Without a system, this knowledge **evaporates** at the end of the session.

Naive solutions fail because:

| Approach | Why it fails |
|-----------|----------------|
| "I dump everything in one giant README" | Becomes unreadable, nobody keeps it updated |
| "I keep a memory file per project" | Good per project, but not for cross-project patterns |
| "I take scattered notes on the desktop" | They get lost and Claude can't search them |
| "I let Claude handle it" | Amnesia between sessions |

---

## The solution: 3 tiers

```
┌──────────────────────────────────────────────────────────────┐
│  TIER 1: Real sessions                                       │
│  Daily chaos, decisions made on the fly, bugs fixed          │
│  → Live in: git commits, CURRENT_STATUS.md, chat history     │
└──────────────────────────────────────────────────────────────┘
                          │
                          │  /kb-ingest [project]
                          ▼
┌──────────────────────────────────────────────────────────────┐
│  TIER 2: LLM Wiki (local, ~/llm-wiki/)                       │
│  Living, mutable, interlinked synthesis                      │
│  4 page types:                                               │
│   - projects/   (1 per project, current status)              │
│   - concepts/   (emerging technical patterns)                │
│   - decisions/  (ADRs — why you chose X over Y)              │
│   - lessons/    (fixed bugs, failed deploys, mistakes)       │
└──────────────────────────────────────────────────────────────┘
                          │
                          │  /kb-promote [concept]
                          │  (criteria: ≥2 projects, ≥2 sessions, prod-verified)
                          ▼
┌──────────────────────────────────────────────────────────────┐
│  TIER 3: Stable KB (this repo or fork)                       │
│  Authoritative, small, curated knowledge                     │
│  → patterns/, agents/, skills/, workflows/                   │
└──────────────────────────────────────────────────────────────┘
```

---

## Key differences between wiki and stable KB

| Aspect | LLM Wiki (tier 2) | Stable KB (tier 3) |
|---------|----------------------|------------------------|
| **Size** | Keeps growing | Small by choice |
| **Stability** | Mutable, updated every session | Rarely changes |
| **Publishability** | Private (contains client details) | Publishable (sanitized) |
| **Type of knowledge** | "What's happening right now" | "What we've learned once and for all" |
| **Audience** | You only (local) | Community (if forked) |
| **Update cadence** | Frequent, automatic (ingest) | Rare, manual (promote) |
| **Syntax** | Obsidian-friendly (`[[wikilinks]]`) | Standard markdown |

---

## The 5 commands

### `/kb-ingest [target]`

**When**: after a significant session, after fixing an important bug, after an architectural decision.

**What it does**:
1. Gathers sources (git log, CURRENT_STATUS, chat)
2. Saves the raw material to `~/llm-wiki/raw/YYYY-MM-DD-*.md` (immutable)
3. Updates `~/llm-wiki/wiki/projects/[target].md` with a synthesis
4. If new patterns emerge → updates `wiki/concepts/`
5. Logs to `wiki/log.md`

**Example**:
```
/kb-ingest taskflow
```

### `/kb-query [question]`

**When**: you want to recall info from the wiki instead of reading the project directly.

**What it does**:
1. Reads `wiki/index.md`
2. Identifies relevant pages
3. Answers citing sources
4. If info is missing → tells you which `/kb-ingest` to run

**Example**:
```
/kb-query which projects use PostgreSQL?
```

### `/kb-promote [concept]`

**When**: a concept in `wiki/concepts/` has appeared in ≥2 projects, has been verified in production, and has been stable for ≥2 sessions.

**What it does**:
1. Checks the promotion criteria
2. Moves/copies the pattern from the wiki to the stable KB
3. Adds a promotion note in the wiki
4. Logs to both repos

**Example**:
```
/kb-promote docker-bind-mount-perm
```

### `/kb-lint`

**When**: weekly, or whenever the wiki starts feeling noisy.

**What it does**:
1. Scans all wiki pages
2. Flags critical issues (undated pages, broken links), warnings (stale pages, open decisions), info (promotion candidates)
3. Produces a report and logs it

### `/kb-output [page] --slides|--summary|--report`

**When**: you want to present the content to someone (client, student, future you).

**What it does**:
1. Exports a page as a Marp slide deck, a text summary, or a multi-project report
2. Output goes to `wiki/output/` (in .gitignore)

---

## Practical setup

### 1. Create your local wiki

```bash
cp -r llm-wiki-template ~/llm-wiki
export LLM_WIKI_PATH=~/llm-wiki
```

Add the export to your `.bashrc` / `.zshrc` / PowerShell profile.

### 2. (Optional) Open it as an Obsidian vault

[Obsidian](https://obsidian.md) is a markdown editor that recognizes `[[wikilinks]]` and shows a connection graph.

- File → Open vault → select `~/llm-wiki/`
- Recommended plugins: **Marp Slides** (for `/kb-output`), **Tag Wrangler**, **Better Search**

### 3. First ingest

In Claude Code, from any project:

```
/kb-ingest project-name
```

This creates the first `wiki/projects/project-name.md` page. Open it in Obsidian to see the result.

### 4. Work normally

Keep using Claude Code as before. Every so often, after important sessions:

```
/kb-ingest project-name
```

After a few weeks, run:

```
/kb-lint
```

To see if there are mature patterns worth promoting.

---

## What goes in the wiki vs. the stable KB?

### What belongs in the **wiki** (private)

- Current project status
- Decisions tied to a specific client
- Endpoints, hostnames, real IPs
- Client names and business details
- Bugs fixed on this specific project
- Concrete infrastructure configurations

### What belongs in the **stable KB** (publishable) — and only this

- Cross-project code patterns
- Generic antipatterns
- Abstract architectures (e.g. "how to structure a Laravel controller")
- Generic workflows (e.g. "deploying with Docker+Traefik")
- Lessons applicable to anyone

**Golden rule**: if the knowledge mentions a real client or system, **it stays in the wiki**. Only after abstraction and generalization can it move up to the stable KB.

---

## Inspiration: the Karpathy pattern

Andrej Karpathy has publicly discussed how knowledge in LLM systems should be
layered in a way analogous to how human memory works:

- **Working memory** (the current conversation)
- **Episodic memory** (individual sessions / experiences)
- **Semantic memory** (consolidated abstract concepts)

The KB-driven workflow applies this idea to software projects:

- Session = working memory
- LLM Wiki = episodic memory
- Stable KB = semantic memory

---

## Antipatterns to avoid

### ❌ "I promote everything to the stable KB right away"

If the stable KB grows too large, it loses its authority. Only verified patterns. The wiki can grow as much as it wants.

### ❌ "I never run /kb-ingest"

Then the system doesn't work. The wiki only lives if you feed it. Tip: a hook that automatically runs `/kb-ingest` at the end of important sessions.

### ❌ "I run /kb-ingest after every message"

Too much noise. The wiki loses value. A good cadence is: after significant bug fixes, after decisions, at the end of the day if the session was productive.

### ❌ "I edit raw/"

Files in `raw/` are **immutable by design**. Editing them breaks the "raw sources + living synthesis" model. If you have corrections, do a new ingest that incorporates them.

### ❌ "I keep the wiki on a public Git repo"

The wiki contains client details by definition. **Keep it in a private repo** or local only. The stable KB (sanitized) can be public.

### ❌ "I keep the wiki ONLY locally"

The opposite mistake: without a (private!) remote, your working memory doesn't survive the machine. Give it a private repo from day one. See `docs/knowledge-disaster-recovery.md`.

---

## Recovery: the retroactive census (if you've stopped ingesting for months)

It happens: you work intensely for weeks across N projects and the wiki falls
behind. Don't panic — Claude Code's **local transcripts** are a recoverable
source: `~/.claude/projects/<project>/*.jsonl`, one JSON line per message.

⚠️ **Privacy first**: transcripts by definition contain more sensitive data
than the wiki (pasted credentials, client names, infrastructure details). The
census reports and the raw material derived from them go ONLY into private
repos, never into public KBs.

The technique (proven on ~15 projects in a single session):

1. **Map the gap**: for each project, compare the last date in `wiki/log.md`
   with the transcript dates (or session history). That gives you a list of project → period not covered.
2. **Fan out reading agents** (one per project, in parallel): each agent
   extracts ONLY the user texts and assistant summaries from the `.jsonl`
   files (never the tool results, too bulky — use `grep`/`jq`/Python) and
   summarizes: what was done, status, decisions, gotchas.
3. **Compile the wiki** from the reports: new/updated project pages, index
   entries, log.
4. **Save a single raw file** for the census (the condensed reports are the raw source).
5. **Promote** whatever has matured in the meantime (the census often reveals
   patterns that appeared in 2+ projects without you noticing).

Technical gotcha: on Windows read the `.jsonl` files with
`PYTHONIOENCODING=utf-8` (cp1252 crashes on emoji/accented characters).

---

## FAQ

### "Does this only work with Claude Code?"

No — it's layered. The **wiki→KB pipeline is tool-agnostic**: markdown + git +
conventions, operable from Cursor, Codex CLI, Gemini CLI, aider, or by a human
(Karpathy's pattern names no tool). The **`/kb-*` commands** are instructions
in prose: the content ports anywhere, only the trigger mechanism changes. The
**patterns** are pure knowledge. The most Claude Code-specific part is the
**subagent mechanics** (frontmatter, auto-selection, model tiers) — but the
role prompts are portable text and the policy (single lead, reviewer gate)
works as a method everywhere. In short: **the engine is replaceable, the
memory isn't** — and it's markdown in a git repo, the most portable format
there is.


**Q: Do I have to use Obsidian?**
A: No. The wiki is standard markdown. Obsidian is handy for the graph view, but you can use VSCode, Logseq, or any editor.

**Q: Can I use the wiki without the stable KB?**
A: Yes. They're independent. You can install just the `/kb-*` commands and use the wiki on its own.

**Q: Can I use the stable KB without the wiki?**
A: Yes. It's the most common use case. You install the agents, patterns, skills — and ignore the `/kb-*` commands.

**Q: How do I back up the wiki?**
A: Version it in Git in a private repo (e.g. a private GitHub or self-hosted GitLab).

**Q: How much does the wiki grow over time?**
A: Depends on how much you work. For reference, a wiki with 20 active projects and 50 concepts comes to about 5-10 MB of markdown — nothing.
