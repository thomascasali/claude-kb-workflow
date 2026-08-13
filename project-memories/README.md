# Project Memories

> Una "project memory" è una scheda riassuntiva del progetto che Claude legge a ogni nuova sessione, per non perdere il contesto. È il **vero antidoto all'amnesia** tra sessioni.

## Come funzionano

Ogni progetto ha un file `MEMORY.md` (o equivalente) che vive **nel progetto stesso** (non in questo repo) e descrive:

- Stack tecnologico
- Hosting / Deploy
- Decisioni architetturali chiave
- Bug ricorrenti / lezioni apprese
- Stato attuale e prossimi passi
- Link a wiki / KB / documentazione

Il file viene letto automaticamente da Claude Code se posizionato in:
- `<progetto>/CLAUDE.md` (alternativa al MEMORY.md)
- `<progetto>/.claude/memory/MEMORY.md`
- `~/.claude/projects/<slug>/MEMORY.md`

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

✅ Tieni le project memory **dentro il progetto** (`<progetto>/CLAUDE.md` o equivalente) e versionale lì.
✅ Usa questo repo solo per template e esempi formativi.
✅ Se devi sincronizzare memory tra macchine, usa un repo **privato** separato.
