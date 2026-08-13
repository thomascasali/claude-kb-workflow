# /kb-ingest — Ingest sessione nella LLM Wiki

Esegui un ingest nella LLM Wiki per il progetto o argomento specificato: $ARGUMENTS

> **Path della Wiki**: questa skill assume la variabile `$LLM_WIKI_PATH` puntata alla tua wiki locale (es. `~/llm-wiki/` o `D:/percorso/llm-wiki/`). Imposta la variabile in `.env` o nel `CLAUDE.md` del workspace.

## Steps

1. **Leggi schema** `$LLM_WIKI_PATH/schema.md` per le convenzioni

2. **Raccogli sorgenti** in base all'argomento:
   - Se è un progetto (es. `nome-progetto`):
     - `git -C <path-progetto> log --oneline -10`
     - Leggi `CURRENT_STATUS.md` se esiste
     - Leggi `CLAUDE.md` header per stato corrente
   - Se è `decision [titolo]`: usa le note fornite dall'utente
   - Se è `lesson [descrizione]`: usa la descrizione del bug/problema risolto

3. **Salva raw** in `$LLM_WIKI_PATH/raw/` con nome `YYYY-MM-DD-[slug].md`:
   - Formato: metadata header (fonte, data raccolta) + contenuto grezzo
   - NON modificare mai i file in `raw/` dopo la creazione

4. **Aggiorna wiki page** `$LLM_WIKI_PATH/wiki/projects/[progetto].md`:
   - Crea se non esiste, aggiorna se esiste
   - Struttura: Quick Reference → Stato Corrente → Lezioni Apprese → Open Questions → Link KB
   - Mantieni la storia: non cancellare sezioni passate, aggiungi sotto
   - ⚠️ **Sintassi link obbligatoria per Obsidian** (se usi Obsidian come vault):
     - Link interni wiki: `[[nome-pagina]]` o `[[nome-pagina|Testo]]`
     - Link esterni (KB stabile, GitHub, docs): markdown standard `[testo](url)`
   - **Frontmatter obbligatorio** all'inizio del file:
     ```
     **Aggiornato**: YYYY-MM-DD
     **Stack**: [tecnologie principali]
     **Tags**: #progetto #[stack-tag]
     ```

5. **Se emergono pattern nuovi**: crea/aggiorna `$LLM_WIKI_PATH/wiki/concepts/[concetto].md`
   - Usa `[[wikilink]]` per linkare i progetti che usano quel concetto
   - Aggiungi il concetto all'indice in `wiki/index.md`

6. **Aggiorna** `$LLM_WIKI_PATH/wiki/index.md`:
   - Aggiorna la riga del progetto nella tabella con data odierna e sommario

7. **Appendi a** `$LLM_WIKI_PATH/wiki/log.md`:
   ```
   | YYYY-MM-DD | INGEST | [target] | [1 riga: cosa è cambiato] |
   ```

8. **Commit** (opzionale se richiesto):
   ```
   git -C $LLM_WIKI_PATH add -A && git commit -m "wiki: ingest [target] - YYYY-MM-DD"
   ```

## Nota

Non duplicare info già nella **KB stabile**. La wiki cattura lo stato *dinamico*
(sessione corrente, open issues, decisioni recenti). La KB cattura pattern *stabili*.

I criteri di promozione da wiki → KB stabile sono definiti in `/kb-promote`.
