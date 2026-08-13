# Workflow KB-driven

> 🇬🇧 English version: [docs/kb-driven-workflow.md](kb-driven-workflow.md)

> Come funziona il sistema a 3 livelli (sessione → wiki → KB stabile) e perché.

---

## Il problema

Quando lavori con un LLM agentico, la conoscenza emerge **continuamente**:

- Risolvi un bug → impari una lezione
- Prendi una decisione → ha un razionale che dimenticherai
- Trovi un pattern → si ripeterà su altri progetti

Senza un sistema, questa conoscenza **evapora** alla fine della sessione.

Le soluzioni naïve falliscono perché:

| Approccio | Perché fallisce |
|-----------|----------------|
| "Salvo tutto in un README giga" | Diventa illeggibile, nessuno lo aggiorna |
| "Tengo memory file per progetto" | Buono per progetto, ma non per pattern cross-progetto |
| "Faccio note sparse sul desktop" | Si perdono, non sono cercabili da Claude |
| "Lascio fare a Claude" | Amnesia tra sessioni |

---

## La soluzione: 3 livelli

```
┌──────────────────────────────────────────────────────────────┐
│  LIVELLO 1: Sessioni reali                                   │
│  Caos quotidiano, decisioni prese al volo, bug risolti       │
│  → Vivono in: commit git, CURRENT_STATUS.md, chat history    │
└──────────────────────────────────────────────────────────────┘
                          │
                          │  /kb-ingest [progetto]
                          ▼
┌──────────────────────────────────────────────────────────────┐
│  LIVELLO 2: LLM Wiki (locale, ~/llm-wiki/)                   │
│  Sintesi viva, mutevole, intercollegata                      │
│  4 tipologie di pagina:                                      │
│   - projects/   (1 per progetto, stato corrente)             │
│   - concepts/   (pattern tecnici emergenti)                  │
│   - decisions/  (ADR — perché hai scelto X invece di Y)      │
│   - lessons/    (bug risolti, deploy falliti, errori)        │
└──────────────────────────────────────────────────────────────┘
                          │
                          │  /kb-promote [concetto]
                          │  (criteri: ≥2 progetti, ≥2 sessioni, prod-verified)
                          ▼
┌──────────────────────────────────────────────────────────────┐
│  LIVELLO 3: KB stabile (questo repo o fork)                  │
│  Conoscenza autorevole, piccola, curata                      │
│  → patterns/, agents/, skills/, workflows/                   │
└──────────────────────────────────────────────────────────────┘
```

---

## Differenze chiave tra wiki e KB stabile

| Aspetto | LLM Wiki (livello 2) | KB stabile (livello 3) |
|---------|----------------------|------------------------|
| **Dimensione** | Cresce continuamente | Piccola per scelta |
| **Stabilità** | Mutevole, si aggiorna a ogni sessione | Cambia raramente |
| **Pubblicabilità** | Privata (contiene dettagli clienti) | Pubblicabile (sanitizzata) |
| **Tipo di conoscenza** | "Cosa sta succedendo ora" | "Cosa abbiamo imparato definitivamente" |
| **Pubblico** | Solo tu (locale) | Community (se forkata) |
| **Aggiornamento** | Frequente, automatico (ingest) | Raro, manuale (promote) |
| **Sintassi** | Obsidian-friendly (`[[wikilinks]]`) | Markdown standard |

---

## I 5 comandi

### `/kb-ingest [target]`

**Quando**: dopo una sessione significativa, dopo aver risolto un bug importante, dopo una decisione architetturale.

**Cosa fa**:
1. Raccoglie sorgenti (git log, CURRENT_STATUS, chat)
2. Salva il raw in `~/llm-wiki/raw/YYYY-MM-DD-*.md` (immutabile)
3. Aggiorna `~/llm-wiki/wiki/projects/[target].md` con sintesi
4. Se emergono pattern nuovi → aggiorna `wiki/concepts/`
5. Logga in `wiki/log.md`

**Esempio**:
```
/kb-ingest taskflow
```

### `/kb-query [domanda]`

**Quando**: vuoi richiamare info dalla wiki invece di andare a leggere il progetto direttamente.

**Cosa fa**:
1. Legge `wiki/index.md`
2. Identifica pagine rilevanti
3. Risponde citando le fonti
4. Se manca info → ti dice quale `/kb-ingest` eseguire

**Esempio**:
```
/kb-query quali progetti usano PostgreSQL?
```

### `/kb-promote [concetto]`

**Quando**: un concetto in `wiki/concepts/` è apparso in ≥2 progetti, è stato verificato in produzione, ed è stabile da ≥2 sessioni.

**Cosa fa**:
1. Verifica i criteri di promozione
2. Sposta/copia il pattern dalla wiki alla KB stabile
3. Aggiunge nota di promozione nella wiki
4. Logga su entrambi i repo

**Esempio**:
```
/kb-promote docker-bind-mount-perm
```

### `/kb-lint`

**Quando**: settimanalmente, o quando senti che la wiki sta diventando rumorosa.

**Cosa fa**:
1. Scansiona tutte le pagine wiki
2. Segnala critico (pagine senza data, link rotti), warn (pagine stale, decisioni open), info (candidati a promozione)
3. Produce un report e logga

### `/kb-output [pagina] --slides|--summary|--report`

**Quando**: vuoi presentare il contenuto a qualcuno (cliente, studente, te stesso futuro).

**Cosa fa**:
1. Esporta una pagina come slide deck Marp, sommario testuale, o report multi-progetto
2. Output in `wiki/output/` (in .gitignore)

---

## Setup pratico

### 1. Crea la tua wiki locale

```bash
cp -r llm-wiki-template ~/llm-wiki
export LLM_WIKI_PATH=~/llm-wiki
```

Aggiungi l'export al tuo `.bashrc` / `.zshrc` / profilo PowerShell.

### 2. (Opzionale) Apri come vault Obsidian

[Obsidian](https://obsidian.md) è un editor markdown che riconosce `[[wikilinks]]` e mostra il graph delle connessioni.

- File → Open vault → seleziona `~/llm-wiki/`
- Plugin consigliati: **Marp Slides** (per `/kb-output`), **Tag Wrangler**, **Better Search**

### 3. Primo ingest

In Claude Code, da un progetto qualsiasi:

```
/kb-ingest nome-progetto
```

Questo crea la prima pagina `wiki/projects/nome-progetto.md`. Aprila in Obsidian per vedere il risultato.

### 4. Lavora normalmente

Continua a usare Claude Code come prima. Ogni tanto, dopo sessioni importanti:

```
/kb-ingest nome-progetto
```

Dopo qualche settimana, esegui:

```
/kb-lint
```

Per vedere se ci sono pattern maturi da promuovere.

---

## Cosa va in wiki e cosa in KB stabile?

### Vai in **wiki** (privata) tutte queste:

- Stato corrente del progetto
- Decisioni con cliente specifico
- Endpoint, hostname, IP reali
- Nomi clienti e dettagli business
- Bug risolti su questo progetto specifico
- Configurazioni infrastrutturali concrete

### Vai in **KB stabile** (pubblicabile) solo queste:

- Pattern di codice cross-progetto
- Antipattern generici
- Architetture astratte (es. "come strutturare un controller Laravel")
- Workflow generici (es. "deploy con Docker+Traefik")
- Lezioni applicabili a chiunque

**Regola d'oro**: se la conoscenza menziona un cliente o un sistema reale, **resta in wiki**. Solo dopo astrazione e generalizzazione, può salire alla KB stabile.

---

## Ispirazione: il pattern Karpathy

Andrej Karpathy ha discusso pubblicamente di come la conoscenza in sistemi LLM debba essere stratificata in modo analogo a come funziona la memoria umana:

- **Memoria di lavoro** (conversazione corrente)
- **Memoria episodica** (singole sessioni / esperienze)
- **Memoria semantica** (concetti astratti consolidati)

Il workflow KB-driven applica questa idea ai progetti software:

- Sessione = memoria di lavoro
- LLM Wiki = memoria episodica
- KB stabile = memoria semantica

---

## Anti-pattern da evitare

### ❌ "Promuovo tutto subito alla KB stabile"

Se la KB stabile cresce troppo, perde la sua autorevolezza. Solo pattern verificati. La wiki può crescere quanto vuole.

### ❌ "Non eseguo mai /kb-ingest"

Allora il sistema non lavora. La wiki vive solo se la nutri. Suggerimento: hook che esegue `/kb-ingest` automaticamente a fine sessione importanti.

### ❌ "Eseguo /kb-ingest dopo ogni messaggio"

Troppo rumore. La wiki perde valore. Una buona cadenza è: dopo bug fix significativi, dopo decisioni, a fine giornata se la sessione è stata produttiva.

### ❌ "Modifico raw/"

I file in `raw/` sono **immutabili per design**. Modificarli rompe il modello "sorgenti grezze + sintesi viva". Se hai correzioni, fai un nuovo ingest che le incorpora.

### ❌ "Tengo la wiki su Git pubblico"

La wiki contiene dettagli clienti per definizione. **Tienila in un repo privato** o solo locale. La KB stabile (sanitizzata) può essere pubblica.

### ❌ "Tengo la wiki SOLO in locale"

L'errore opposto: senza un remote (privato!) la tua memoria di lavoro non sopravvive alla macchina. Dagli un repo privato dal giorno uno. Vedi `docs/disaster-recovery-conoscenza.md`.

---

## Recovery: il censimento retroattivo (se hai smesso di fare ingest per mesi)

Capita: lavori intensamente per settimane su N progetti e la wiki resta indietro.
Niente panico — i **transcript locali** di Claude Code sono una sorgente recuperabile:
`~/.claude/projects/<progetto>/*.jsonl`, una riga JSON per messaggio.

⚠️ **Privacy prima di tutto**: i transcript contengono per definizione più dati sensibili
della wiki (credenziali incollate, nomi clienti, dettagli infrastruttura). I report del
censimento e i raw che ne derivano vanno SOLO in repo privati, mai in KB pubbliche.

La tecnica (collaudata su ~15 progetti in una sessione):

1. **Mappa il gap**: per ogni progetto, confronta l'ultima data in `wiki/log.md` con le
   date dei transcript (o della cronologia sessioni). Ti esce la lista progetto → periodo scoperto.
2. **Fan-out di agenti di lettura** (uno per progetto, in parallelo): ogni agente estrae
   dai `.jsonl` SOLO i testi utente e i riepiloghi dell'assistente (mai i tool-result,
   troppo voluminosi — `grep`/`jq`/Python) e riassume: cosa è stato fatto, stato, decisioni, gotcha.
3. **Compila la wiki** dai report: pagine progetto nuove/aggiornate, righe indice, log.
4. **Salva un raw unico** del censimento (i report condensati sono la sorgente grezza).
5. **Promuovi** ciò che nel frattempo è maturato (spesso il censimento rivela pattern
   apparsi in 2+ progetti senza che te ne accorgessi).

Gotcha tecnico: su Windows leggi i `.jsonl` con `PYTHONIOENCODING=utf-8` (cp1252 crasha
su emoji/accenti).

---

## FAQ

### "Funziona solo con Claude Code?"

No — a strati. La **pipeline wiki→KB è tool-agnostica**: markdown + git +
convenzioni, operabile da Cursor, Codex CLI, Gemini CLI, aider o da un umano
(il pattern di Karpathy non nomina nessun tool). I **comandi `/kb-*`** sono
istruzioni in prosa: il contenuto si porta ovunque, cambia solo il meccanismo
di attivazione. I **pattern** sono conoscenza pura. La parte più legata a
Claude Code è la **meccanica dei subagent** (frontmatter, auto-selezione,
model tier) — ma i prompt di ruolo sono testo portabile e la policy (lead
unico, gate reviewer) vale come metodo ovunque. Sintesi: **il motore è
sostituibile, la memoria no** — ed è markdown in un repo git, il formato più
portabile che esista.


**Q: Devo per forza usare Obsidian?**
A: No. La wiki è markdown standard. Obsidian è comodo per il graph view, ma puoi usare VSCode, Logseq, o qualsiasi editor.

**Q: Posso usare la wiki senza la KB stabile?**
A: Sì. Sono indipendenti. Puoi installare solo i comandi `/kb-*` e usare la wiki da sola.

**Q: Posso usare la KB stabile senza la wiki?**
A: Sì. È il caso d'uso più comune. Installi gli agenti, pattern, skill — e ignori i comandi `/kb-*`.

**Q: Come faccio backup della wiki?**
A: Versionala in Git in un repo privato (es. su GitHub privato o GitLab self-hosted).

**Q: Quanto cresce la wiki nel tempo?**
A: Dipende dal volume di lavoro. Per riferimento, una wiki con 20 progetti attivi e 50 concetti pesa circa 5-10 MB di markdown — niente.
