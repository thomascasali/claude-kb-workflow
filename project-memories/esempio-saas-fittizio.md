# MEMORY: TaskFlow (esempio fittizio)

> **Aggiornato**: 2026-05-19
> **Stato**: production
> **Tags**: #saas #vue #laravel #mysql #stripe
>
> ⚠️ **Questo è un esempio inventato** per mostrare la struttura di una project memory. Nessuna relazione con prodotti reali.

---

## 🎯 Obiettivo del progetto

TaskFlow è un SaaS di task management per team distribuiti. Si differenzia da Trello/Asana per la funzione "deep work timer" integrato e l'analisi del flusso di lavoro settimanale.

Target: team da 5-20 persone, prezzo €8/utente/mese.

---

## 🏗️ Stack

| Layer | Tecnologia | Versione | Note |
|-------|-----------|----------|------|
| Frontend | Vue 3 + Vite + Tailwind | 3.4 | Pinia per state, vue-router 4 |
| Backend | Laravel | 12 | JWT auth (tymon/jwt-auth), API-only |
| Database | MySQL | 8.0 | InnoDB, charset utf8mb4 |
| Mobile | — | — | Solo PWA per ora |
| Hosting | VPS Linux + Docker + Traefik | Ubuntu 24.04 | Let's Encrypt automatico |
| CI/CD | GitHub Actions | — | Build + test + deploy su tag |
| Pagamenti | Stripe | API 2025-01 | Subscriptions con webhook |
| Email | AWS SES | — | Transactional + digest settimanale |

---

## 🔗 Link utili

- **Repo**: [github.com/orgname/taskflow](#) (fittizio)
- **Production**: https://app.taskflow.example
- **Staging**: https://staging.taskflow.example
- **Documentazione**: `docs/` nel repo
- **Issue tracker**: GitHub Issues
- **CLAUDE.md del progetto**: `taskflow/CLAUDE.md`

---

## 📐 Decisioni architetturali chiave

### Decisione 1: Multi-tenancy via foreign key (no schema-per-tenant)
- **Data**: 2025-02-10
- **Contesto**: Decidere come isolare i dati tra team
- **Opzioni considerate**:
  - A) Schema-per-tenant (un DB per team)
  - B) Foreign key + global scopes
  - C) Database condiviso senza isolamento esplicito
- **Scelta**: B
- **Motivazione**: Complessità infrastrutturale di A non giustificata sotto i 1000 team. Global scope su `team_id` su tutti i model garantisce isolamento.
- **Trade-off accettati**: Migrazione futura a schema-per-tenant se cresciamo molto (rivedere a 500 team)

### Decisione 2: Stripe webhook idempotency via Redis cache
- **Data**: 2025-03-05
- **Contesto**: Stripe può inviare lo stesso webhook più volte (network retry)
- **Scelta**: Cache event ID Stripe in Redis con TTL 24h prima di processare
- **Motivazione**: Evita double-charge su scenari di rete instabile
- **Riferimento**: Pattern KB su idempotency

---

## 🐛 Bug ricorrenti / lezioni apprese

| Data | Bug | Causa radice | Soluzione | Pattern KB |
|------|-----|--------------|-----------|-----------|
| 2025-04-12 | Notifiche email duplicate dopo deploy | Job queue resa idle ma worker zombie | Aggiunto `php artisan queue:restart` nel deploy.sh | — |
| 2025-05-03 | Frontend mostra 401 al refresh dopo login | JWT in localStorage non letto da Vue prima del primo render | Spostato auth check in `router.beforeEach` con redirect a `/loading` | — |
| 2025-06-20 | Stripe webhook lento (5s+) per eventi grandi | Loop sincrono su line items invece di queue job | Dispatched a job, webhook risponde 200 entro 200ms | — |
| 2026-01-15 | Vite build OOM su CI | Bundle troppo grande, code-splitting mancante | Aggiunto `manualChunks` in vite.config.ts | #3 build statico |

---

## 📋 Stato attuale (rolling)

**Ultima sessione**: 2026-05-19

**Cosa è stato fatto recentemente**:
- Migrazione da Pinia 2 a 3 (breaking change su `setup` stores)
- Implementato dark mode con preferenza salvata in user settings
- Refactor Stripe controller per gestire `customer.subscription.trial_will_end`

**Prossimi passi pianificati**:
- [ ] Implementare 2FA con TOTP
- [ ] Migrazione MySQL 8.0 → 8.4 (testare su staging prima)
- [ ] Pannello admin per metriche utilizzo

**Bloccanti**:
- Decisione di prodotto su 2FA: TOTP o magic link? (in discussione con team)

---

## 🚨 Pattern critici applicabili

Pattern generali dal repo `claude-kb-workflow/patterns/patterns.md`:

- [x] #1 — Laravel: AdminMiddleware invece di auth:api + admin
- [x] #5 — Laravel config:cache dopo modifiche .env
- [x] #7 — Docker bind mount permessi sovrascritti

Convenzioni personali da `claude-kb-workflow/patterns/field-notes-it.md`:

- [x] #1 — deploy.sh è LOCALE
- [x] #2 — Git → deploy workflow obbligatorio
- [x] #3 — Frontend è build statico (rebuild dopo modifiche)
- [x] #4 — VITE_API_URL senza doppio /api
- [x] #8 — Deploy flags per performance
- [x] #11 — File da non committare (CONTEXT.md, .env)

---

## ⚠️ Cose da NON fare in questo progetto

- ❌ Non modificare lo schema `subscriptions` senza coordinare con il team Stripe — il webhook handler è strettamente accoppiato
- ❌ Non eseguire `php artisan migrate:fresh` in staging senza aver fatto un dump prima — staging ha dati reali di test acquisiti
- ❌ Non disabilitare il rate limiting su `/api/auth/login` — abbiamo subito tentativi di credential stuffing nel marzo 2025
- ❌ Non aggiungere `@route` dinamiche dopo le `:id` route (vedi patterns.md #2)

---

## 📝 Note libere

- Il dominio `taskflow.example` è solo per questo esempio fittizio. In un vero progetto inserisci il dominio reale.
- Stripe events maneggiati: `customer.subscription.{created,updated,deleted}`, `invoice.payment_{succeeded,failed}`, `customer.subscription.trial_will_end`.
- Backup DB: cron giornaliero alle 03:00 UTC, retention 30 giorni.
- Email digest settimanale parte ogni lunedì alle 09:00 timezone utente.
