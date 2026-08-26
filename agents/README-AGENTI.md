# Sistema Agenti Cross-Progetto

> Agenti universali per tutti i progetti. Ogni agente supporta multi-stack e multi-progetto.

---

## Quick Start

1. **Identifica il task** -> Scegli l'agente dal Decision Tree
2. **Leggi l'agente** -> `~/.claude/agents/[agente].md`
3. **Integra con progetto** -> Combina con CLAUDE.md del progetto specifico
4. **Segui i pattern** -> `~/.claude/patterns/patterns.md` (+ `field-notes-it.md` per le mie convenzioni)

---

## Stack Supportati

Gli agenti coprono i seguenti stack — ognuno è documentato con sezioni dedicate dove serve distinguere:

| Categoria | Tecnologie |
|-----------|-----------|
| **Backend PHP** | Laravel 11/12 + Eloquent + JWT |
| **Backend Node** | Node.js 20 + Express + Mongoose / Prisma |
| **Frontend** | Vue.js 3 + Vite, React 18/19 + Vite |
| **Mobile** | Flutter 3.x (Provider o Riverpod) |
| **Database** | MySQL 8, PostgreSQL 16, MongoDB 7, Firestore |
| **Realtime** | Socket.io, WebSocket, Pusher, MQTT, WebRTC |
| **Infra** | Docker + Docker Compose, Traefik 3, Nginx, Linux VPS |
| **CI/CD** | GitHub Actions, Codemagic (Flutter) |
| **Integrazioni** | Stripe, SumUp, Email (SMTP/SES), Push (FCM/APNs), Telegram Bot, Gemini AI |

---

## Lista Agenti

**Orchestratori** (v0.2 — vedi `docs/orchestrazione.md`):

| Agente | Model | Usa per |
|--------|-------|---------|
| **deep-reasoner** | opus | Fasi ad alto ragionamento: architettura, debug complesso, algoritmi |
| **fast-worker** | sonnet | Lavoro meccanico: parti standard, test, formattazione |

**Specialisti di dominio**:

| Agente | Model | Usa per |
|--------|-------|---------|
| **backend-dev** | sonnet | API, Controller, Model, Routes, Services (Laravel + Node.js) |
| **frontend-dev** | sonnet | UI, Pages, Components, State (Vue.js + React) |
| **mobile-dev** | sonnet | App Flutter, Provider, GoRouter, API integration |
| **devops** | sonnet | Deploy, Docker, Traefik, VPS, SSL, Container |
| **database** | sonnet | Schema, Migration, Query, Backup (MySQL/MongoDB/PostgreSQL/Firestore) |
| **integrations** | sonnet | Stripe, Email, Google APIs, Push notifications |
| **realtime-dev** | sonnet | Socket.io, WebSocket, MQTT, WebRTC |
| **ci-cd** | sonnet | GitHub Actions, build mobile, firma, store deploy |
| **reviewer** | opus | Debug, Bug fix, Code review, Performance — **il gate di qualità** |
| **security** | opus | JWT, Auth flows, CORS, Middleware, Data protection |

---

## Decision Tree

```
CODICE BACKEND?
|-- Endpoint Laravel (PHP)    -> backend-dev [Laravel]
|-- Endpoint Node.js          -> backend-dev [Node.js]
|-- Bug backend               -> reviewer + backend-dev
|-- Query lente               -> database
|
CODICE FRONTEND?
|-- Componente Vue.js         -> frontend-dev [Vue]
|-- Componente React          -> frontend-dev [React]
|-- Bug frontend              -> reviewer + frontend-dev
|-- Styling/UX                -> frontend-dev
|
APP MOBILE?
|-- Nuova schermata Flutter   -> mobile-dev
|-- Bug app                   -> reviewer + mobile-dev
|-- API integration           -> mobile-dev + backend-dev
|-- Build/Release             -> mobile-dev + devops
|
INFRASTRUTTURA?
|-- Deploy                    -> devops
|-- Container issues          -> devops + reviewer
|-- SSL/Network               -> devops
|-- CI/CD                     -> devops
|
DATI?
|-- Import/Export             -> database
|-- Migration                 -> database
|-- Query MySQL               -> database [MySQL]
|-- Query MongoDB             -> database [MongoDB]
|-- Backup/Restore            -> database + devops
|
INTEGRAZIONI?
|-- Stripe payments           -> integrations
|-- Email (SMTP/SES)          -> integrations
|-- Google Sheets/Drive       -> integrations
|-- Push notifications        -> integrations
|
SICUREZZA?
|-- JWT/Auth issues           -> security
|-- CORS problems             -> security + devops
|-- Permission/Roles          -> security + backend-dev
|
NON SO?
|-- Inizia con               -> reviewer (diagnosi)
```

---

## Combinazioni Comuni

| Scenario | Sequenza |
|----------|----------|
| Feature full-stack | backend-dev -> frontend-dev -> reviewer -> devops |
| Feature con app | backend-dev -> mobile-dev -> reviewer -> devops |
| Bug fix backend | reviewer -> backend-dev -> devops |
| Bug fix frontend | reviewer -> frontend-dev -> devops |
| Bug fix app | reviewer -> mobile-dev |
| Import dati | database -> backend-dev |
| Nuovo workflow | backend-dev -> frontend-dev -> mobile-dev |
| Setup nuovo progetto | devops -> security -> database |
| Auth/Login issues | security -> backend-dev -> frontend-dev |

---

## Struttura File

```
~/.claude/
|-- agents/
|   |-- README-AGENTI.md        # Questa guida
|   |-- deep-reasoner.md        # Opus - fasi di ragionamento
|   |-- fast-worker.md          # Sonnet - lavoro meccanico
|   |-- backend-dev.md          # Laravel + Node.js
|   |-- frontend-dev.md         # Vue.js + React
|   |-- mobile-dev.md           # Flutter/Dart
|   |-- devops.md               # Docker/Deploy/VPS
|   |-- database.md             # MySQL/MongoDB/PostgreSQL/Firestore
|   |-- integrations.md         # Stripe/Email/APIs
|   |-- realtime-dev.md         # Socket.io/WebSocket/MQTT/WebRTC
|   |-- ci-cd.md                # GitHub Actions/store deploy
|   |-- reviewer.md             # Debug/Code Review (gate)
|   |-- security.md             # JWT/Auth/CORS
|-- patterns/
|   |-- patterns.md             # Pattern generalizzati, riusabili (EN)
|   |-- field-notes-it.md       # Convenzioni personali, esempio (IT)
|-- workflows/
|   |-- common-tasks.md         # Workflow comuni
```

---

## Regole

1. **Un task = Un agente primario** - Scegli l'agente piu' adatto
2. **Leggi sempre CLAUDE.md del progetto** - Contiene context specifico
3. **Leggi sempre CONTEXT.md** - Contiene credenziali e password
4. **Segui le checklist** dell'agente prima di committare
5. **Stack detection** - Ogni agente ha sezioni [Laravel] e [Node.js] o equivalenti
6. **Pattern** -> `~/.claude/patterns/patterns.md`
7. **deploy.sh e' LOCALE** - Mai eseguirlo sul VPS!

---

## Riconoscimento Stack Automatico

Per capire quale stack usa il progetto corrente:

| Indicatore | Stack |
|------------|-------|
| `composer.json` | Laravel/PHP |
| `package.json` + Express | Node.js/Express |
| `artisan` | Laravel |
| `pubspec.yaml` | Flutter/Dart |
| `vite.config.js` + Vue | Vue.js |
| `vite.config.js` + React | React |
| `.env` con `DB_CONNECTION=mysql` | MySQL |
| `.env` con `MONGODB_URI` | MongoDB |

---

## Orchestrazione

Il sistema di lavoro è a due livelli:

- **Lead** = orchestratore: pianifica, decompone, sintetizza. Per policy delega
  SOLO il lead: l'annidamento (subagent che delega ad altri subagent) è tecnicamente
  possibile ma moltiplica token/latenza — evitalo (vedi `docs/orchestrazione.md`).
- **deep-reasoner** (Opus) = fasi ad alto ragionamento; **fast-worker** (Sonnet) = lavoro meccanico.
- Gli specialisti di dominio (backend-dev, frontend-dev, mobile-dev, devops, database,
  integrations, realtime-dev, ci-cd, reviewer, security) sono subagent veri: hanno frontmatter
  YAML (`name`/`description`/`model`) e il lead li vede e li sceglie AUTOMATICAMENTE in base alla
  `description` — non serve elencarli in CLAUDE.md né dentro altri agenti.
- La `description` nel frontmatter È il criterio di selezione: tenerla precisa.
- Politica di routing (quando usare chi): definiscila nel tuo `~/.claude/CLAUDE.md` globale
  (es. una sezione "Flusso di orchestrazione" con le fasi ad alto ragionamento su deep-reasoner,
  il lavoro meccanico su fast-worker, e un gate di review obbligatorio prima di dichiarare
  un lavoro finito).
- Backup/versionamento di questi agenti: questo stesso repo (`agents/`) — tienilo aggiornato
  con `git pull` e ricopia in `~/.claude/agents/` quando aggiorni un agente (vedi `scripts/install.sh`).
