# Workflow: Task Comuni Cross-Progetto

> Guida pratica per i task piu' frequenti con scelta agente e sequenza operazioni.

---

## MATRICE TASK -> AGENTE

| Task | Agente Primario | Agenti Supporto |
|------|-----------------|-----------------|
| Nuovo endpoint API | backend-dev | reviewer |
| Nuova pagina web | frontend-dev | reviewer |
| Nuova schermata app | mobile-dev | reviewer |
| Deploy modifiche | devops | - |
| Fix bug backend | reviewer | backend-dev |
| Fix bug frontend | reviewer | frontend-dev |
| Fix bug app | reviewer | mobile-dev |
| Import dati | database | backend-dev |
| Migration DB | database | backend-dev |
| Pagamento Stripe | integrations | backend-dev, mobile-dev |
| Email notification | integrations | backend-dev |
| Auth/Login issue | security | backend-dev |
| CORS problem | security | devops |
| Performance issue | reviewer | database |
| Setup nuovo progetto | devops | security, database |

---

## WORKFLOW 1: Nuova Feature Full-Stack (Web)

```
1. PIANIFICAZIONE
   -> Agente: reviewer
   -> Task: analisi requisiti, impatto codebase

2. DATABASE (se necessario)
   -> Agente: database
   -> Task: migration, nuove tabelle/collection

3. BACKEND
   -> Agente: backend-dev
   -> Task: model, controller, routes, validation

4. FRONTEND
   -> Agente: frontend-dev
   -> Task: pagine, componenti, services API

5. REVIEW
   -> Agente: reviewer
   -> Task: code review completo

6. DEPLOY
   -> Agente: devops
   -> Task: deploy production, verify
```

---

## WORKFLOW 2: Nuova Feature con App Mobile

```
1. BACKEND
   -> Agente: backend-dev
   -> Task: API endpoints necessari

2. APP MOBILE
   -> Agente: mobile-dev
   -> Task: screen, provider, model, API integration

3. TEST
   -> flutter analyze + test su device fisico

4. DEPLOY BACKEND
   -> Agente: devops
   -> Task: ./deploy.sh --backend-only

5. BUILD APP
   -> flutter build apk --release (o appbundle)
```

---

## WORKFLOW 3: Bug Fix Urgente

```
1. DIAGNOSI
   -> Agente: reviewer
   -> Task: metodologia debug 6-step
   -> Tempo: 15 min max

2. FIX
   -> Agente: backend-dev | frontend-dev | mobile-dev
   -> Task: implementa fix minimo

3. DEPLOY RAPIDO
   -> Agente: devops
   -> Task: deploy con flag appropriato (--backend-only tipicamente)

4. VERIFICA
   -> Agente: reviewer
   -> Task: test in production, monitoring logs
```

---

## WORKFLOW 4: Setup Pagamento Stripe

```
1. BACKEND
   -> Agente: backend-dev + integrations
   -> Task: PaymentIntent, webhook, price calculation

2. FRONTEND WEB
   -> Agente: frontend-dev + integrations
   -> Task: Stripe Elements, checkout flow

3. APP MOBILE
   -> Agente: mobile-dev + integrations
   -> Task: flutter_stripe, payment sheet

4. TEST
   -> Stripe test mode, test cards
   -> Webhook con Stripe CLI

5. SECURITY CHECK
   -> Agente: security
   -> Task: webhook signing, amount server-side
```

---

## WORKFLOW 5: Import Dati da Excel/CSV

```
1. ANALISI
   -> Agente: database
   -> Task: analisi struttura file, mapping campi

2. SCRIPT
   -> Agente: database + backend-dev
   -> Task: script import con validation, error handling

3. ESECUZIONE
   -> Push script su Git
   -> Eseguire nel container Docker su VPS

4. VERIFICA
   -> Agente: database
   -> Task: count documenti, verifica integrita'
```

---

## WORKFLOW 6: Deploy (Decision Tree)

```
Che tipo di modifica?
|
|-- Solo backend (PHP/Node.js)
|   -> ./deploy.sh --backend-only (15s)
|
|-- Solo frontend (Vue/React/CSS)
|   -> ./deploy.sh --frontend-only (30-60s)
|
|-- Solo app mobile
|   -> flutter build apk --release (no deploy server)
|
|-- Backend + Frontend
|   -> ./deploy.sh (3-4min)
|
|-- Nuove dipendenze
|   -> ./deploy.sh --no-cache (5min)
|
SEMPRE: git add -> commit -> push PRIMA del deploy!
```

---

## WORKFLOW 7: Auth/Login Issue

```
1. DIAGNOSI
   -> Agente: security + reviewer
   -> Task: verificare JWT, middleware, CORS

2. BACKEND
   -> Agente: security + backend-dev
   -> Task: fix auth middleware, token generation

3. FRONTEND/APP
   -> Agente: frontend-dev | mobile-dev
   -> Task: fix token storage, interceptor, redirect

4. TEST
   -> curl con token valido/invalido
   -> Test login/logout/refresh flow
```

---

## WORKFLOW 8: Code Review

```
1. CHECKLIST BACKEND
   [ ] Error handling completo
   [ ] Validation input
   [ ] Authorization checks
   [ ] Logging (no console.log in Node.js)
   [ ] Query con paginazione
   [ ] Eager loading/populate

2. CHECKLIST FRONTEND
   [ ] Loading/error/empty states
   [ ] Responsive design
   [ ] VITE_API_URL corretto
   [ ] No console.log in production

3. CHECKLIST MOBILE
   [ ] flutter analyze zero errori
   [ ] Model.fromJson null safe
   [ ] API format verificato

4. CHECKLIST DEPLOY
   [ ] Commit + push prima del deploy
   [ ] Flag deploy corretto
```

---

## TEMPLATE PROMPT RAPIDI

### Backend Veloce
```
Task: [descrizione]
Stack: [Laravel | Node.js]
Endpoint: [METHOD /path]
Auth: [public | protected | admin]
```

### Frontend Veloce
```
Task: [descrizione]
Stack: [Vue.js | React]
Tipo: [page | component | service]
```

### Mobile Veloce
```
Task: [descrizione]
Screen: [nome schermata]
API: [endpoint da integrare]
```

### Debug Veloce
```
Bug: [errore]
Stack: [Laravel | Node.js | Vue | React | Flutter]
Endpoint: [path se applicabile]
Errore: [status code / messaggio]
```

### Deploy Veloce
```
Modifiche: [backend | frontend | entrambi | app]
Files: [lista breve]
Progetto: [ProgettoWeb1 | ProgettoWeb2 | ProgettoWeb3 | ProgettoApi1 | ProgettoApi2 | ProgettoRealtime | ProgettoMobile1 | ProgettoIoT1]
```

---

## METRICS DI SUCCESSO

Per ogni task completato, verifica:

**Backend**: Endpoint risponde, auth funziona, logging presente, error handling completo
**Frontend**: Renderizza, stati gestiti, responsive, no console errors
**Mobile**: flutter analyze OK, stati gestiti, API verified
**Deploy**: Container running, no errors in logs, endpoint raggiungibile
**Database**: Dati corretti, relazioni preservate, query performanti

---

**Usa questa guida per task quotidiani veloci e consistenti su tutti i progetti.**
