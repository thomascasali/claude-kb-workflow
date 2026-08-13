# Changelog

## v0.3 — 2026-08-03

### 🌍 English front door
- English is now the primary language: README flipped (EN main; compact Italian section linking the 4 native Italian docs), 4 core docs translated (orchestration, kb-driven workflow, knowledge disaster recovery, 2026 comparison) with cross-links both ways.
- Italian remains first-class: native docs, didactic material, and the reason this project exists.
- Agent/skill content still Italian — EN translations are the most-wanted contribution.

## v0.2.1 — 2026-08-02

### Riposizionamento
- **README**: il toolkit si presenta ora per quello che lo distingue — **il sistema di
  memoria** (pipeline Karpathy wiki→KB in produzione da aprile 2026 su 15+ progetti) —
  con agenti/pattern/skill come dotazione. Le raccolte di agenti si sono commoditizzate
  nel 2026; la pipeline di conoscenza con promozione a maturità no.
- **Confronto aggiornato al panorama 2026** (`docs/confronto-superpowers.md`): Superpowers
  ~265k ⭐ e attivissimo, categoria dominata da Superpowers/GSD/gstack ("gstack pensa,
  GSD stabilizza, Superpowers esegue"). Posizionamento esplicito: **complementari, non
  alternativi** — loro il metodo di esecuzione, noi il sistema di memoria.

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
