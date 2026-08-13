# /kb-lint — Health-check della LLM Wiki

Esegui un controllo qualità completo della LLM Wiki in `$LLM_WIKI_PATH`.

## Steps

1. **Leggi schema** `$LLM_WIKI_PATH/schema.md`
2. **Leggi index** `$LLM_WIKI_PATH/wiki/index.md`
3. **Scansiona** tutte le pagine in `wiki/projects/`, `wiki/concepts/`, `wiki/decisions/`, `wiki/lessons/`

## Checks da eseguire

### 🔴 CRITICO
- Pagine `wiki/projects/` senza data aggiornamento
- Link interni che puntano a file inesistenti
- File in `wiki/` non referenziati in `index.md`

### 🟡 WARN
- Pagine `wiki/projects/` non aggiornate da >30 giorni (confronta con `wiki/log.md`)
- Concetti in `wiki/concepts/` non linkati da nessun progetto
- Decisioni in `wiki/decisions/` con stato "open" da >14 giorni
- Progetti nello schema.md senza pagina wiki corrispondente

### 🟢 INFO
- Pattern in `wiki/concepts/` candidati a promozione nella KB stabile
  (criteri: appare in ≥2 progetti, stabile da ≥2 sessioni, verificato in prod)
- Pagine `wiki/lessons/` non ancora linkate a pattern KB
- Suggerimenti di merge per pagine simili

## Output

Produci un report strutturato:
```
## 🔴 CRITICO (N problemi)
- [file] → [problema] → [azione suggerita]

## 🟡 WARN (N avvisi)
- [file] → [avviso] → [azione suggerita]

## 🟢 INFO (N suggerimenti)
- [concetto] → candidato promozione a KB/patterns/

## Statistiche
- Pagine totali: N
- Progetti tracciati: N/N
- Ultimo ingest: [data da log.md]
- Prossimo lint consigliato: [data + 7gg]
```

Appendi a `wiki/log.md`:
```
| YYYY-MM-DD | LINT | — | [N critico, N warn, N info] |
```
