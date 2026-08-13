# /kb-output — Esporta wiki page come presentazione Marp

Esporta una pagina della LLM Wiki in formato slide deck Marp: $ARGUMENTS

> **Path**: `$LLM_WIKI_PATH` per la wiki sorgente.

## Parsing argomenti

- Formato: `/kb-output [pagina] [--slides|--summary|--report]`
- Esempi:
  - `/kb-output flutter-architecture --slides`
  - `/kb-output nome-progetto --summary`
  - `/kb-output --slides` (senza pagina = genera slides per tutti i concepts)

## Steps

### Modalità `--slides` (default)

1. **Leggi** la pagina wiki specificata da `$LLM_WIKI_PATH/wiki/`
   - Se è un progetto: `wiki/projects/[pagina].md`
   - Se è un concetto: `wiki/concepts/[pagina].md`

2. **Genera** un file Marp nella cartella `$LLM_WIKI_PATH/output/`:
   - Nome file: `YYYY-MM-DD-[pagina].md`
   - Frontmatter obbligatorio:
     ```markdown
     ---
     marp: true
     theme: default
     paginate: true
     backgroundColor: #1a1a2e
     color: #eee
     style: |
       section { font-family: 'Segoe UI', sans-serif; }
       h1 { color: #e94560; }
       h2 { color: #0f3460; }
       code { background: #16213e; }
     ---
     ```
   - **Struttura slide per progetto**:
     - Slide 1: Titolo + Stack + Data
     - Slide 2: Quick Reference (repo, server, comandi deploy)
     - Slide 3-N: Stato corrente, sezioni principali
     - Slide finale: Open Questions + Link KB
   - **Struttura slide per concetto**:
     - Slide 1: Titolo + definizione
     - Slide 2-N: Pattern principali con code blocks
     - Slide finale: Progetti che usano questo concetto `[[wikilinks]]`

3. **Mostra** il comando di esportazione da eseguire:
   ```bash
   # Preview nel browser
   npx @marp-team/marp-cli $LLM_WIKI_PATH/output/[file].md -o output.html --allow-local-files

   # PDF
   npx @marp-team/marp-cli $LLM_WIKI_PATH/output/[file].md --pdf -o output.pdf

   # PPTX
   npx @marp-team/marp-cli $LLM_WIKI_PATH/output/[file].md --pptx -o output.pptx
   ```

### Modalità `--summary`

Genera un riassunto testuale della pagina in 5-10 bullet points.
Utile per quick review prima di una sessione su quel progetto.

### Modalità `--report`

Genera un report multi-progetto con:
- Tabella tutti i progetti (stato, ultima sessione, open issues)
- Sezione concetti emersi con numero di progetti che li usano
- Sezione decisioni aperte

Output: `$LLM_WIKI_PATH/output/YYYY-MM-DD-report.md`

## Note

- La cartella `output/` è in `.gitignore` — i file generati non vengono committati
- Per usare Marp in Obsidian: installa il plugin "Marp Slides" e usa `Ctrl+Shift+M` per preview
- Il tema dark (`backgroundColor: #1a1a2e`) è ottimale per presentazioni a schermo
