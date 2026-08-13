# /kb-promote — Promuovi un concetto dalla Wiki alla KB stabile

Promuovi il concetto specificato da `llm-wiki/wiki/concepts/` alla **KB stabile** (questo repo o un fork): $ARGUMENTS

> **Path**: `$LLM_WIKI_PATH` per la wiki, `$KB_PATH` per la KB stabile (es. clone locale di `claude-kb-workflow`).

## Criteri di eleggibilità (verifica prima di procedere)

- [ ] Appare in ≥ 2 progetti diversi
- [ ] Stabile da ≥ 2 sessioni (controlla `wiki/log.md`)
- [ ] Verificato in produzione (non solo teorico)
- [ ] Non già presente in `$KB_PATH/patterns/critical-patterns.md`

## Steps

1. Leggi `$LLM_WIKI_PATH/wiki/concepts/[concetto].md`
2. Verifica i criteri sopra — se non soddisfatti, avvisa l'utente e fermati
3. Identifica destinazione in `$KB_PATH/`:
   - Pattern critico cross-progetto → `patterns/critical-patterns.md` (aggiungi sezione)
   - Pattern specifico per stack → aggiorna agente rilevante `agents/[agente].md`
   - Guida operativa → `knowledge-base/[NOME].md`
4. Aggiungi il pattern con formato coerente agli altri (vedi convenzioni in `CONTRIBUTING.md`)
5. Aggiorna `wiki/concepts/[concetto].md` con nota:
   ```
   > **Promosso** a `KB/[destinazione]` il YYYY-MM-DD
   ```
6. Appendi a `wiki/log.md`:
   ```
   | YYYY-MM-DD | PROMOTE | [concetto] | Promosso a KB/[destinazione] |
   ```
7. Commit su entrambi i repo:
   ```bash
   git -C $LLM_WIKI_PATH commit -m "wiki: promote [concetto]"
   git -C $KB_PATH commit -m "kb: add pattern [concetto] (from llm-wiki)"
   ```

## Filosofia

La promozione è un **rito di stabilizzazione**: una conoscenza nasce sporca nelle sessioni, viene sintetizzata nella wiki, e solo dopo prove ripetute "guadagna" il posto nella KB stabile.

Questo evita il rumore: la KB resta piccola, focalizzata, autorevole. La wiki resta viva, sperimentale, mutevole.
