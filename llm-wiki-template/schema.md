# LLM Wiki — Schema e Governance

> Template per il sistema KB-driven a due livelli ispirato al pattern di Andrej Karpathy ("software 2.0 knowledge management").
>
> **Separazione chiave**: questo repo (la **wiki**) cattura la conoscenza *compilata* dalle sessioni quotidiane.
> La conoscenza *stabile e curata* vive in un repo separato (es. il tuo fork di `claude-kb-workflow`).

---

## Pipeline di Conoscenza

```
Sessioni Claude / Git log / Bug risolti / Decisioni prese
        │
        ▼  Operazione: INGEST (/kb-ingest)
    raw/                       ← sorgenti grezze immutabili
        │
        ▼  Compilazione LLM (auto durante ingest)
    wiki/                      ← pagine sintetizzate e intercollegate
        │
        ▼  Promozione manuale (/kb-promote, quando il pattern è maturo)
    KB stabile (repo esterno)  ← conoscenza curata permanente
```

---

## Struttura Directory

```
llm-wiki/
├── schema.md              # Questo file — governance del sistema
├── wiki/
│   ├── index.md           # Indice globale (una riga per pagina)
│   ├── log.md             # Append-only: ogni operazione ingest/lint/promote
│   ├── projects/          # 1 pagina per progetto — stato corrente + lezioni
│   ├── concepts/          # Concetti tecnici emersi dalle sessioni
│   ├── decisions/         # ADR — Architecture Decision Records
│   └── lessons/           # Lezioni apprese da bug, deploy, errori
└── raw/
    ├── sessions/          # Dump di sessioni Claude significative
    ├── status/            # Snapshot di CURRENT_STATUS.md dai progetti
    └── decisions/         # Note grezze su decisioni architetturali
```

---

## Convenzioni Pagine Wiki

### Frontmatter obbligatorio
```
# Titolo
**Aggiornato**: YYYY-MM-DD
**Sorgenti**: raw/sessions/YYYY-MM-DD-*.md, ...
**Tags**: #progetto, #concetto
```

### Tipi di pagina

| Directory | Frequenza aggiornamento | Trigger |
|-----------|------------------------|---------|
| `wiki/projects/` | Dopo ogni sessione sul progetto | `/kb-ingest PROGETTO` |
| `wiki/concepts/` | Quando emerge un pattern nuovo | Manuale o ingest |
| `wiki/decisions/` | Quando si prende una decisione arch. | `/kb-ingest decision` |
| `wiki/lessons/` | Dopo ogni bug risolto / deploy fallito | `/kb-ingest lesson` |

### Cross-reference

> ⚠️ **Regola Obsidian** (se usi Obsidian come vault): usare SEMPRE la sintassi `[[wikilink]]` per link interni.
> I link markdown standard `[testo](path)` non appaiono nel Graph View di Obsidian.

- **Link interni** (wiki → wiki): `[[nome-pagina]]` oppure `[[nome-pagina|Testo alias]]`
- **Link a progetti**: `[[nome-progetto]]`
- **Link a concetti**: `[[nome-concetto]]`
- **Link a KB stabile** (wiki → KB esterna): path relativo standard OK — la KB è fuori dal vault Obsidian
- Mai link assoluti con path locali

---

## Operazione INGEST

```
/kb-ingest [progetto|decision|lesson] [note opzionale]
```

**Steps automatici (vedi `commands/kb-ingest.md`):**
1. Legge gli ultimi commit del progetto (`git log -5`)
2. Legge `CURRENT_STATUS.md` se presente
3. Aggiorna `wiki/projects/{progetto}.md` con: ultimo stato, nuove lezioni, versione corrente
4. Se emergono pattern nuovi → crea/aggiorna `wiki/concepts/`
5. Appende a `wiki/log.md`: `YYYY-MM-DD | INGEST | {progetto} | {sommario}`
6. Aggiorna `wiki/index.md`

**Regola d'oro**: `raw/` è immutabile. Mai modificare file in `raw/` dopo la creazione.

---

## Operazione LINT

```
/kb-lint
```

Health check periodico della wiki. Identifica:
- 🔴 Critico: pagine senza data, link rotti, file orfani
- 🟡 Warn: pagine stale (>30gg), decisioni open (>14gg)
- 🟢 Info: candidati a promozione nella KB stabile

Vedi `commands/kb-lint.md`.

---

## Operazione PROMOTE

```
/kb-promote [concetto]
```

Promuove un concetto maturo dalla wiki alla KB stabile.

**Criteri**:
- Appare in ≥ 2 progetti
- Stabile da ≥ 2 sessioni
- Verificato in produzione

Vedi `commands/kb-promote.md`.

---

## Setup iniziale

1. Clona o copia questa cartella `llm-wiki-template` in una posizione locale (es. `~/llm-wiki/`)
2. Esporta `LLM_WIKI_PATH` nell'ambiente o nel `CLAUDE.md` del tuo workspace
3. Crea i primi file `wiki/index.md`, `wiki/log.md` (vedi template forniti)
4. Esegui `/kb-ingest [nome-progetto]` per il primo ingest
5. (Opzionale) Apri la cartella in Obsidian come vault per la visualizzazione Graph

---

## Filosofia in 3 punti

1. **La conoscenza non è statica**: nasce sporca nelle sessioni, viene sintetizzata in wiki, e solo dopo prove ripetute viene promossa nella KB stabile.
2. **Niente cancellazioni distruttive**: la wiki è append-mostly. Le decisioni superate vengono marcate come "superseded", non rimosse.
3. **La KB stabile è piccola per scelta**: meno regole autorevoli, più segnale e meno rumore.
