# Orchestration: lead + subagents

> 🇮🇹 Versione italiana: [docs/orchestrazione.md](orchestrazione.md)

> The toolkit's multi-agent work system (introduced in v0.2).
> One principle: **the main model doesn't do the work — it orchestrates it.**

## The mental model

For non-trivial work, the main Claude Code session acts as **lead**:

1. **Plans** — shows the plan before executing
2. **Decomposes** — breaks the work into delegable phases
3. **Delegates** to subagents — doesn't do the work itself
4. **Synthesizes** — integrates results while keeping its own context lean

The benefit isn't (only) parallelization: it's that the lead's context stays
clean and strategic, while the messy details (files read, attempts, test
output) stay in the subagents' throwaway contexts.

## The three-tier pool + specialists

```
                       ┌─ quick-worker (Haiku)    → small, closed jobs a test or command can prove
                       ├─ fast-worker  (Sonnet)   → unknown causes, real choices, wide changes
  LEAD (orchestrates) ─┼─ deep-reasoner (Opus)    → design, plans, second opinion
                       ├─ 8 specialists (Sonnet)  → backend-dev, frontend-dev, mobile-dev,
                       │                            devops, database, integrations,
                       │                            realtime-dev, ci-cd
                       └─ 2 specialists (Opus)    → reviewer, security
```

### Which model for which job

Use the cheapest model that is enough, and move up only for a reason you can state.

| Tier | Agent | Use it when | Escalate when |
|---|---|---|---|
| Haiku (default) | `quick-worker` | The "how" is decided and a test or a command proves the job is done: collecting local state, summaries, local or already-downloaded logs, bounded questions, mechanical edits, serial output, plans already written, first-pass review. | The job needs an unknown cause found, a choice between approaches, or many files: relaunch on `fast-worker` with the Haiku work attached. |
| Sonnet | `fast-worker` and the specialists | An unknown cause to find, a choice between approaches that matters, wide changes across files and tests. | It returns incomplete or fails: relaunch on `deep-reasoner` with the work done so far. |
| Opus | `deep-reasoner`, `reviewer`, `security` | Design, plans, deep platform knowledge, a second opinion before a hard-to-undo action, the final gate. | Nothing above it: the lead decides. |

Limits for Haiku: no ssh or commands on production servers (that goes to `devops`),
no files with secrets, and never the final gate. A domain with its own patterns
(backend, mobile, deploy) goes to its specialist even when the job is small.

**Mandatory gate**: before declaring work done, the result passes through
`reviewer`. It's the highest-leverage single change in the
system: it forces a second read with a clean context.

## The 6 non-obvious rules (learned the hard way)

1. **An agent only exists if its YAML frontmatter parses.** A file in
   `~/.claude/agents/` without frontmatter (or with corrupted frontmatter) is
   invisible: it doesn't throw errors, it's simply never used.
   ```yaml
   ---
   name: agent-name
   description: What it does and WHEN to use it. This is the lead's only selection criterion.
   model: sonnet   # opus for reasoning phases; 'inherit' to inherit
   ---            #  from the session; omitted = subagent default model
   ```
2. **The `description` is the only auto-selection criterion.** The lead sees
   every agent's name + description and picks based on those. If it delegates
   poorly, fix the description — not the prompt.
3. **Keep delegation flat.** Nesting (a subagent that in turn delegates) is
   technically possible when the subagent has the delegation tool, but it
   multiplies tokens and latency and makes you lose control of the synthesis:
   the operating rule is that ONLY the lead delegates. Don't design specialists
   "inside" other agents.
4. **Don't list agents in prompts or in CLAUDE.md** to "make them discoverable"
   — discovery is automatic. CLAUDE.md should only hold the *routing policy*.
5. **The lead's formula goes in CLAUDE.md, not in prompts.** As a standing
   policy it's loaded in every session; the prompt is left with only task,
   constraints, and extra gates. Example policy (adapt it):
   ```markdown
   ## Orchestration flow (applies to all non-trivial work)
   You are the lead: plan, decompose, delegate to subagents — don't do
   the work yourself — and synthesize. Show the plan first, then execute.
   - Small, closed, testable jobs -> quick-worker (default)
   - Unknown cause, real choice, wide changes -> fast-worker
   - Design, plans, second opinion -> deep-reasoner
   - Relaunch one tier up, with the previous work attached, when a tier fails.
   - For everything else, pick the specialist from the pool's description.
   - Mandatory gate: before declaring done, pass through `reviewer`.
   - Exception: trivial/conversational tasks done directly, no ceremony.
   ```
6. **Name an agent in the prompt only to force the exception** — e.g. "have
   deep-reasoner and a second engine evaluate this schema decision in
   parallel, then synthesize blind." The ordinary case is handled by policy.

## The hierarchy of levers

| Level | Contains | When to touch it |
|---|---|---|
| `~/.claude/CLAUDE.md` | Lead formula + routing + reviewer gate | Only method changes |
| `agents/*.md` → `description` | Selection criterion | If the lead delegates poorly/too little |
| Session prompt | Task, constraints, extra gates | Every job |

## A true story (why the health check matters)

This system stayed **dormant for months without anyone noticing**: the two
main agents had frontmatter corrupted by an editor that had escaped the
markdown (`\---` instead of `---`, `&#x20;` instead of spaces), and the
specialists had no frontmatter at all. Everything *looked* like it was
working — the lead was simply improvising on its own.

**Health check** (30 seconds): ask the lead "what subagents do you have
available?" If your agents don't show up in the list, the frontmatter isn't
parsing. After fixing it, restart the session (or `claude --continue`, which
reloads the pool without losing the conversation); in some environments the
pool reloads on the fly too.

## When NOT to orchestrate

Trivial tasks, one-line fixes, conversational questions: do them directly, no
ceremony. Orchestration has a cost (tokens + latency) that only pays off when
the work has distinct phases or requires isolated contexts.
