# Disaster recovery della conoscenza

> 🇬🇧 English version: [docs/knowledge-disaster-recovery.md](knowledge-disaster-recovery.md)

> Obiettivo: se domani la tua macchina di sviluppo sparisce, torni operativo al 100% —
> **inclusa la conoscenza accumulata con Claude Code**, non solo il codice.

## Il principio

Tutto ciò che vale vive in **repo Git privati**; tutto ciò che è segreto vive
**solo in un password manager o nei `.env` dei server di produzione**. Il resto
(transcript delle sessioni, cache, stato locale) è sacrificabile per costruzione.

```
Ripristinabile (repo Git privati)         Sacrificabile
─────────────────────────────────         ─────────────────────────
KB stabile (guide, pattern, agenti,       Transcript sessioni locali
  workflow, project-memories)             Cache e stato di ~/.claude
LLM Wiki (memoria di lavoro compilata)    .env locali — SOLO SE ogni valore
Snapshot di ~/.claude/CLAUDE.md             è nel vault o rigenerabile
Repo dei progetti                           (verificalo PRIMA del disastro)

Nel vault (mai nei repo)
────────────────────────
Chiavi SSH · password · API key · chiavi di cifratura dati
```

## I due repo della conoscenza

1. **KB stabile** — la verità curata: guide operative, pattern, agenti, workflow
   e una **project-memory per progetto** (stato, gotcha, decisioni). È il repo
   che questo toolkit ti aiuta a costruire.
2. **LLM Wiki** — la memoria di lavoro: pagine compilate dalle sessioni via
   `/kb-ingest`, promozione alla KB via `/kb-promote` quando un pattern matura.
   Vedi `llm-wiki-template/` e `docs/workflow-kb-driven.md`.

⚠️ Errore facile: tenere la wiki **solo in locale**. È un repo Git a tutti gli
effetti — dagli un remote privato dal giorno uno, o la tua memoria di lavoro
non è ripristinabile. (Sì, ci siamo cascati.)

## La guida di ripristino (da scrivere PRIMA del disastro)

Nella KB tieni un file `DEV-MACHINE-RESTORE.md` con:

1. **Prerequisiti**: password manager, `git` + `gh auth login`, chiave SSH dal vault
2. **I cloni della conoscenza**: i due repo di cui sopra, con i path convenzionali
3. **Config Claude Code**: lo snapshot di `~/.claude/CLAUDE.md` (tienilo nel repo KB,
   sincronizzato quando modifichi l'originale) + agenti/skill dal toolkit
4. **Mappa dell'infrastruttura**: quali progetti girano su quali host, come si accede
   (senza segreti: solo *dove sono* i segreti)
5. **Toolchain**: l'elenco di ciò che va installato (runtime, CLI, SDK)
6. **Cosa NON è ripristinabile** — dichiararlo esplicitamente evita panico:
   i transcript locali non tornano, ma se fai ingest regolarmente la conoscenza
   estratta è già nella wiki.

## Le chiavi di cifratura sono un caso speciale

Se i tuoi progetti cifrano dati (es. AES-256-GCM su dati sensibili), la chiave è
**immutabile e irrecuperabile**: persa la chiave, persi i dati. Va nel vault con
un'etichetta chiara, e la guida di ripristino deve nominarla esplicitamente.

## Il collaudo: dry-run del restore (obbligatorio, non opzionale)

"100% ripristinabile" è un claim, finché non lo testi. Il test costa dieci minuti:
crea una cartella vuota che simula la `~/.claude` di una macchina nuova, punta lì
lo script di restore, eseguilo, e VERIFICA IN PROFONDITÀ il risultato — non "le
cartelle ci sono" ma "i file dentro ci sono" (una skill è i suoi `data/` e
`scripts/`, non solo il suo `SKILL.md`).

Il nostro primo dry-run è fallito, trovando in un colpo solo quattro difetti che
un ripristino reale avrebbe scoperto nel momento peggiore:

1. **Lo script moriva a metà in silenzio**: `set -e` + un `cp` su un glob vuoto
   = stop senza errore visibile. Metà del ripristino "riusciva".
2. **Copie superficiali**: copiare solo i `.md` restituisce skill svuotate del
   loro cuore (`data/`, `scripts/`). Sembrano ripristinate; non funzionano.
3. **Sovrascritture distruttive**: lo script toccava file di stato di altri
   sistemi (l'indice della memoria automatica). Un restore non deve MAI
   sovrascrivere ciò che non ha creato lui.
4. **File promessi mai versionati**: il README elencava un file di config che
   non era mai stato committato. La documentazione non è un backup.

Bonus tassonomico emerso dal collaudo — le skill vivono su TRE binari, e solo
due sono protetti di default: (a) le tue, versionate nel repo; (b) quelle di
comunità con lock file, reinstallabili; (c) **quelle installate a mano, che non
stanno da nessuna parte** — censiscile e versionale, o preparati a perderle.

## Test del sistema

Il test onesto non è "ho fatto il backup?" ma: *"aprendo la guida di ripristino
su una macchina vuota, arrivo a lavorare senza chiedere niente a nessuno?"*
Se la risposta è no, manca un pezzo — di solito uno snapshot di config o un
segreto non etichettato nel vault.

## Bonus: recuperare conoscenza mai ingerita

Se hai lavorato mesi senza fare ingest, i transcript locali di Claude Code
(`~/.claude/projects/<progetto>/*.jsonl`) sono una miniera recuperabile: ogni riga
è un JSON con i messaggi utente/assistente. Un **censimento retroattivo** — agenti
di lettura in parallelo, uno per progetto, che estraggono richieste utente e
riepiloghi — ricostruisce lo stato di decine di sessioni in un'ora. Poi si
compila la wiki e si promuove il maturo. (Tecnica descritta in
`docs/workflow-kb-driven.md`.)
