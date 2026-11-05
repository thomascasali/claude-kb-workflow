# Changelog

## [0.4.0] - Unreleased

Three model tiers, a promotion rule that matches how the toolkit is actually run,
two new guides, and a round of text corrections.

### Agents
- New `quick-worker` (Haiku), the default for small, closed jobs that a test or a command can prove.
  The pool is now 13 subagents (3 orchestrators and 10 specialists); every count in the docs was updated.
- `fast-worker` (Sonnet) is redefined: unknown causes, choices between approaches that matter, wide changes
  across files and tests, and the relaunch when Haiku comes back incomplete, with its work attached.
- `deep-reasoner` (Opus) now covers design, plans and a second opinion before hard-to-undo actions, and is
  the relaunch when Sonnet fails.
- `docs/orchestration.md`, `docs/orchestrazione.md`, `agents/README-AGENTI.md`, `workflows/common-tasks.md`
  and the README describe the three tiers and when to move up.
- `ci-cd` and `mobile-dev`: the release flow is GitHub Actions triggered by a tag. Android runs on a hosted
  `ubuntu-latest` runner with `subosito/flutter-action`; only iOS needs macOS, with `macos-latest` as the
  default and a self-hosted runner as an alternative (never on public repos). The example workflow has a
  `quality` job that both builds need, reads `.flutter-version` into `$GITHUB_ENV` for `flutter-action`,
  signs Android from secrets, and uses a non-bare Android build number, a completed closed-test release
  (`status: draft` for apps still in draft, plus `releaseName`), secrets passed through `env:`, a temporary
  keychain with a signing lock and an `if: always()` cleanup. The workflow was not run: its YAML blocks were only
  parsed. Codemagic stays as an alternative.
- `integrations`: Telegram and Gemini examples are generic; the project-specific example was removed.

### Promotion rule
- The old fixed threshold (seen on 2+ projects, 2+ sessions, verified in production) is replaced by the rule the
  author actually applies, called the promotion exam: at least one of "used by 2+ projects", "a gotcha already
  paid for that would cost an hour or more to hit again", "a declared standard", and in every case verified in
  production or on a real device. Updated in the README, `llms.txt`, `/kb-promote`, `/kb-lint`, `/kb-ingest`,
  the KB-driven workflow docs and the wiki template schema.

### New guides
- `docs/single-source-of-truth.md` and `docs/fonte-unica.md`: which kind of information lives where, and what
  the other places may hold.
- `docs/incremental-review-log.md` and `docs/review-log-incrementale.md`: review only `git diff <last-sha>..HEAD`,
  with a review log kept in the project memory. `project-memories/_template.md` and the example gain a
  "Review log" section; the `project-memories` README and example now keep project state as a link to the wiki page.

### Texts
- Positioning is "knowledge that crosses your projects" and "shared knowledge layer" everywhere; the
  older wording for the toolkit's category is gone, as is the claim about what survives between sessions
  in the README problem list.
- Dated or boasting claims removed (running since a given month, number of projects, "proven on", "years of").
- Named production sites removed from the README; "new" version markers removed.
- Skills: `docker compose up` only on local or staging in `verifica-prima-di-completare`; a red command in
  `debugging-sistematico`, tests that count in `verifica-prima-di-completare`, a recommended answer in
  `brainstorming-design` (ideas adapted from mattpocock/skills, MIT).
- `LICENSE` header updated with the author's name and the Superpowers note.

### Scripts
- Secret scanner `scripts/lib/secret-scan.sh`, with an example pre-commit hook.
- Restore test `scripts/restore-test.sh` and restore script `scripts/restore.sh`.
- The scanner reads files with a NUL byte anywhere on two raw copies, one without the NUL bytes (ASCII text in UTF-16 or
  UTF-32) and one with spaces in their place. With a UTF-16 or UTF-32 BOM it also decodes with `iconv`, and without `iconv`
  the scan stops with exit 2. Rules compare bytes (`LC_ALL=C`), so a Latin-1 byte next to a key still counts as a boundary.
  It treats file and folder names as plain data (`:`, a leading `-`, `$(...)`), follows a symlink given as an argument,
  and tolerates CR line endings and a missing final newline in the scope and allowlist files.
  `wiki/projects/**` and `raw/**` get the prose password rule, also in scans outside a git repository.
- Scanner arguments go to `grep` in batches, so a large tree no longer fails with "Argument list too long".
  A failing `find` or `grep`, a path that does not exist (even one among others) or a copy that cannot be written gives
  exit 2 and never a clean result. An existing argument that yields no file read gives a warning.
- Skipped without reading: more binary extensions, case-insensitive (`.jar`, `.wasm`, `.docx` and similar), and, with a
  warning, files with NUL bytes that start with a certain binary signature. A secret inside those files is not found.
- `--staged` skips gitlinks (submodules) and also scans type changes. The `gitleaks` report stays in the scanner's work folder,
  which is now removed on HUP, INT and TERM too.
- Tests passed on Git Bash for Windows and on Ubuntu 22.04 in WSL, not on macOS.
- New `.gitattributes` forces LF on `*.sh`, `.githooks/*`, `scripts/lib/*.txt` and `.secret-allowlist*`, so a clone
  with `core.autocrlf=true` keeps working.
- `scripts/backup.sh` stops with a clear message when the target is not a git repository, no longer suggests
  `git add -A`, and points to the secret scanner before the commit.
- CONTRIBUTING has a section on the secret scanner and the pre-commit hook.

## [0.3.2] - 2026-08-26

Repositioning release, no functional changes to commands or agents.

- README, llms.txt and docs now lead with the cross-project angle: Claude
  Code's native auto-memory is per-project and per-machine; this toolkit is
  the layer above it. An earlier claim in the README about what survives
  between sessions was inaccurate and has been removed everywhere.
- `patterns/critical-patterns.md` (30 mixed-quality items, Italian) split
  into `patterns/patterns.md` (16 general patterns, English) and
  `patterns/field-notes-it.md` (the author's own conventions, Italian,
  clearly labeled). Old links to critical-patterns.md no longer resolve.
- install.sh removes the stale `critical-patterns.md` from `~/.claude/patterns/`
  on upgrade.
- README prose cleanup (long dashes, wording that read as machine-written), a link to the interactive
  presentation, and references to earlier internal versions removed.

## [0.3.1] - 2026-08-13

Initial public release.

- Wiki to KB knowledge pipeline with the five `/kb-*` commands and the wiki template.
- 12 orchestrated subagents with valid YAML frontmatter, 6 methodological skills.
- 30 production patterns (split into general and personal files in 0.3.2).
- Documentation in English and Italian.

## Earlier history (before the public release)

## v0.3 — 2026-08-03

### 🌍 English front door
- English is now the primary language: README flipped (EN main; compact Italian section linking the 4 native Italian docs), 4 core docs translated (orchestration, kb-driven workflow, knowledge disaster recovery, 2026 comparison) with cross-links both ways.
- Italian remains first-class: native docs, didactic material, and the reason this project exists.
- Agent/skill content still Italian — EN translations are the most-wanted contribution.

## v0.2.1 — 2026-08-02

### Riposizionamento
- **README**: il toolkit si presenta ora per quello che lo distingue, la pipeline di
  conoscenza wiki→KB (tradizione Karpathy) con promozione a maturità, con
  agenti/pattern/skill come dotazione. Le raccolte di agenti si sono commoditizzate
  nel 2026; la pipeline di conoscenza con promozione a maturità no.
- **Confronto aggiornato al panorama 2026** (`docs/confronto-superpowers.md`): Superpowers
  ~265k ⭐ e attivissimo, categoria dominata da Superpowers/GSD/gstack ("gstack pensa,
  GSD stabilizza, Superpowers esegue"). Posizionamento esplicito: **complementari, non
  alternativi** — loro il metodo di esecuzione, noi il livello di conoscenza condiviso.

## v0.2 — 2026-07-20

La release "il sistema ora funziona davvero".

### 🚨 Fix critico
- **Gli agenti della v0.1 non venivano MAI orchestrati automaticamente**: erano documenti
  senza frontmatter YAML, quindi invisibili a Claude Code. Tutti i 12 agenti ora hanno
  frontmatter valido (`name`/`description`/`model`) e vengono registrati e auto-selezionati
  dal lead. Se usavi la v0.1: reinstalla con `./scripts/install.sh`.

### ✨ Nuovo
- **Sistema di orchestrazione lead + subagent** (`docs/orchestrazione.md`): delega piatta,
  description come criterio di selezione, gate obbligatorio su `reviewer`, gerarchia delle
  leve, standing policy in CLAUDE.md — con la storia vera del frontmatter corrotto.
- **2 agenti orchestratori**: `deep-reasoner` (Opus) e `fast-worker` (Sonnet).
- **Model tier per agente**: esecutori su Sonnet, `reviewer`/`security` su Opus.
- **8 pattern nuovi** (#23–30): multi-tenant single-DB, SSO interno/IdP, sync-selector
  catch-22, page-speed a cache fredda, git/deploy su VPS instabile, firma FEA-OTP per
  esterni senza account, web push FCM HTTP v1 senza SDK, webhook di pagamento idempotenti.
- **Disaster recovery della conoscenza** (`docs/disaster-recovery-conoscenza.md`):
  il principio "2 repo privati + segreti solo nel vault = macchina dev ricostruibile".
- **Censimento retroattivo da transcript** (in `docs/workflow-kb-driven.md`): come
  recuperare mesi di sessioni mai ingerite leggendo i `.jsonl` locali con agenti in parallelo.

### 🔧 Migliorato
- README-AGENTI con sezione orchestrazione; install script allineato ai 12 agenti.
- Anti-pattern nuovo nel workflow KB: "wiki solo in locale" (dalle un remote privato).

## v0.1 — 2026-05

- Release iniziale: 10 agenti-documento, 22 pattern critici, 6 skill metodologiche,
  5 comandi `/kb-*`, template LLM wiki, guide (filosofia, workflow KB-driven,
  confronto Superpowers).
