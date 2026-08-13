# /kb-query — Interroga la LLM Wiki

Rispondi alla domanda usando la LLM Wiki come fonte primaria: $ARGUMENTS

> **Path della Wiki**: imposta `$LLM_WIKI_PATH` nel tuo workspace (es. `~/llm-wiki/`).

## Steps

1. Leggi `$LLM_WIKI_PATH/wiki/index.md` per orientarti
2. Identifica le pagine rilevanti per la domanda
3. Leggi le pagine pertinenti (progetti, concetti, decisioni, lezioni)
4. Se la risposta non è nella wiki → segnalalo esplicitamente e suggerisci `/kb-ingest`
5. Rispondi citando le pagine usate: `[fonte: wiki/projects/X.md]`

## Comportamento

- **Prima la wiki** — non andare a leggere i progetti direttamente se la wiki ha già la risposta
- **Cita le fonti** — ogni affermazione ha il link alla pagina wiki
- **Segnala gap** — se manca info, di' quale `/kb-ingest` eseguire
- **Non inventare** — se non è nella wiki, dì "non so, esegui `/kb-ingest [progetto]`"

## Esempio

Utente: `/kb-query quali progetti usano PostgreSQL?`
→ Leggi `index.md` → trova progetti rilevanti → leggi loro pagine → rispondi con citazioni.
