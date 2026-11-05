# Project Memories

> Una "project memory" è la scheda dei fatti stabili di un progetto: il contesto che serve a chiunque (umano o agente) apra il progetto, in un posto solo.

## Come funzionano

Ogni progetto ha un file `project-memories/<progetto>.md` nella **tua KB privata** (non in questo repo). Descrive:

- Stack tecnologico
- Hosting / Deploy
- Decisioni architetturali chiave
- Bug ricorrenti / lezioni apprese
- Review log
- Link alla pagina wiki del progetto, che tiene stato corrente e prossimi passi
- Link a documentazione

Stato, versione e prossimi passi non si scrivono qui: la project memory ha solo il link a `wiki/projects/<progetto>.md`. Le istruzioni per lavorare nel repo stanno nel `CLAUDE.md` del repo. La tabella completa è in [`docs/fonte-unica.md`](../docs/fonte-unica.md).

## In questo repo

Questa cartella contiene **solo template ed esempi anonimi** per mostrare il pattern. Le project memory reali sono per definizione private — non andrebbero mai pubblicate in repo open source perché contengono:

- 🔒 Architetture interne di clienti
- 🔒 Decisioni di business
- 🔒 Stack scelti e versionati
- 🔒 (Talvolta) endpoint, hostname, dettagli infrastruttura

## File qui presenti

- [`_template.md`](_template.md) — Template vuoto da copiare per nuovi progetti
- [`esempio-saas-fittizio.md`](esempio-saas-fittizio.md) — Esempio completo su progetto **inventato**

## Anti-pattern

❌ **Non committare** project memory di progetti reali in repo pubblici, neanche se "sembrano anonimi".
❌ **Non mettere** credenziali, password, token, IP reali in queste memory.
❌ **Non duplicare** info che sono già nel `CLAUDE.md` del progetto.

## Pattern consigliato

✅ Tieni le project memory nella KB, in un repo **privato**, e versionale lì.
✅ Usa questo repo solo per template ed esempi formativi.
