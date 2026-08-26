<!--
These are the author's operational field notes, in Italian: the deploy scripts, environment
variable naming, VPS providers and personal conventions of one specific multi-project setup.
They are not general-purpose patterns. Nothing here assumes you run the same deploy.sh, the
same VITE_API_URL convention or the same VPS providers, and most of it won't transfer to your
stack as-is.

It's kept in the repo as a worked example of what a personal cross-project conventions file
looks like in practice: the kind of file worth maintaining once you juggle enough unrelated
projects to forget which one uses fish and which uses bash. For patterns meant to be reusable
outside this specific setup, see patterns/patterns.md instead.
-->

# Field Notes — Convenzioni Operative Personali

*In Italian on purpose: these are the author's own operating conventions across his projects, kept here as a worked example of a shared conventions file. The reusable, general patterns live in [patterns.md](patterns.md), in English.*

> Note pratiche del mio setup multi-progetto: deploy, percorsi, provider VPS, credenziali.
> Utili a me come promemoria; a te soprattutto come esempio di formato.

---

## 1. deploy.sh e' LOCALE (Tutti i progetti)

```bash
# CORRETTO - deploy.sh e' sul PC locale, NON sul VPS
cd D:/progetti/progetto-web-1.example && ./deploy.sh

# SBAGLIATO - deploy.sh non esiste sul VPS!
ssh root@VPS "./deploy.sh"
```

---

## 2. Git -> Deploy Workflow

```bash
# SEMPRE: commit -> push -> deploy
# Le modifiche DEVONO essere su Git prima del deploy!

git add . && git commit -m "fix: description" && git push origin main
./deploy.sh --backend-only

# SBAGLIATO: Modificare file -> deploy senza commit/push
# Risultato: Deploy NON vede le modifiche!
```

---

## 3. Frontend e' Build Statico

```
Modifiche Vue/React NON visibili dopo git pull senza rebuild!
Serve SEMPRE: ./deploy.sh --frontend-only

Le variabili VITE_* vengono BAKED nel bundle durante build.
Modifiche .env frontend richiedono rebuild completo.
```

---

## 4. VITE_API_URL (Vue & React)

```javascript
// VITE_API_URL = "https://api.domain.com/api"

// CORRETTO
api.get('/examples')  // -> https://api.domain.com/api/examples

// SBAGLIATO - Doppio /api
api.get('/api/examples')  // -> https://api.domain.com/api/api/examples

// Prefisso VITE_ obbligatorio per Vite
import.meta.env.VITE_API_URL   // CORRETTO
process.env.API_URL             // NON funziona in Vite!
```

---

## 5. Node.js: Logger (non console.log)

```javascript
// CORRETTO
const logger = require('../config/logger');
logger.info('Operation completed');
logger.error(`Error: ${error.message}`);

// SBAGLIATO - Non appare in docker logs
console.log('Message');
```

---

## 6. MongoDB: User e' Single Source of Truth

```javascript
// CORRETTO - Dati identita' SOLO da User via populate
const player = await Player.findById(id).populate('user');
const name = player.user.firstName;  // Da User!

// SBAGLIATO - NON creare campi duplicati in Player/Coach/Delegate!
// Player.name, Player.email -> NON ESISTONO, vengono da User
```

---

## 7. React: AuthContext (currentUser, NON user)

```jsx
// CORRETTO
const { currentUser, isAuthenticated, isAdmin } = useAuth();

// SBAGLIATO
const { user } = useAuth();  // NON esiste!
```

---

## 8. Deploy Flags (Performance)

```bash
# Modifiche backend PHP/Node.js -> --backend-only (15s)
./deploy.sh --backend-only

# Modifiche frontend Vue/React -> --frontend-only (30-60s)
./deploy.sh --frontend-only

# Nuove dipendenze (composer/npm) -> --no-cache (5min)
./deploy.sh --no-cache

# NON usare --no-cache per semplici modifiche codice!
```

---

## 9. Percorsi File Windows

```
# CORRETTO - Percorsi assoluti con backslash
C:\progetti\progetto-web-1.example\frontend\src\file.vue

# SBAGLIATO - Percorsi relativi
frontend/src/file.vue
```

---

## 10. VPS Fish Shell (VPS Provider A)

```bash
# Alcuni provider VPS usano fish come shell di default - usare bash -c per comandi bash
ssh root@<VPS_A_IP> "bash -c 'cd /root/progetto-web-1.example && docker compose ps'"

# Provider B usa bash - comandi diretti OK
ssh root@<VPS_B_IP> "cd /opt/progetto-api-1.example && docker compose ps"
```

---

## 11. File NON Committare Mai

```bash
# PRIVATI - Solo locali (in .gitignore)
CONTEXT.md           # Contiene password!
CURRENT_STATUS.md    # Stato lavoro
.env                 # Credenziali!
backend/.env         # Credenziali!
google-service-account.json  # Service account key

# PUBBLICI - Su Git
CLAUDE.md            # Istruzioni progetto
.env.example         # Template senza valori
```

---

## 12. PostgreSQL: JSONB per Dati Strutturati

```sql
-- Game logs salvati in JSONB per futura analisi AI
CREATE TABLE game_logs (
  id SERIAL PRIMARY KEY,
  game_data JSONB NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Query su campi JSONB
SELECT * FROM game_logs WHERE game_data->>'winner' = 'team1';
```

---

## 13. Firebase/Firestore: Stream vs Future

```dart
// CORRETTO - Stream per dati real-time
final tasksProvider = StreamProvider((ref) {
  return FirebaseFirestore.instance
    .collection('tasks')
    .snapshots()
    .map((snap) => snap.docs.map(Task.fromFirestore).toList());
});

// CORRETTO - Future per operazioni one-shot
Future<void> createTask(Task task) async {
  await FirebaseFirestore.instance.collection('tasks').add(task.toMap());
}
```

---

## 14. ESP32/IoT: MQTT Topics Convention

```
// Topic structure: project/location/sensor_type
orto/interno/temperatura
orto/esterno/temperatura
orto/suolo/umidita

// SEMPRE: QoS 1 per dati sensori (at least once delivery)
// WiFiManager per configurazione rete senza hardcoding
```

---

## Quick Reference: Quale Pattern per Quale Progetto

> Nota: gli esempi usano nomi progetto anonimizzati (ProgettoWeb1, ProgettoApi2...). I pattern
> cross-progetto trasversali (ex multi-tenant, SSO, WARP, webhook, ecc.) sono stati spostati in
> [patterns/patterns.md](patterns.md) e non compaiono più in questa tabella.

| Pattern | ProgettoWeb1 | ProgettoWeb2 | ProgettoWeb3 | ProgettoApi1 | ProgettoApi2 | ProgettoRealtime | ProgettoMobile1 | ProgettoIoT1 | ProgettoIoT2 |
|---------|-----------|---------|----------------|-------|------------|---------------|----------|-----------------|--------------|
| #1 deploy.sh locale | Si | Si | Si | Si | Si | Si | - | Si | - |
| #2 Git -> Deploy | Si | Si | Si | Si | Si | Si | - | Si | - |
| #3 Build statico | Si | Si | Si | Si | Si | Si | - | Si | - |
| #4 VITE_API_URL | Si (Vue) | Si (Vue) | Si (Vue) | Si (React) | Si (React) | Si (React) | - | Si (React) | - |
| #5 Logger | - | - | - | Si (Node.js) | Si (Node.js) | Si (Node.js) | - | Si (Node.js) | - |
| #6 User SSoT | - | - | - | Si (MongoDB) | Si (MongoDB) | - | - | - | - |
| #7 currentUser | - | - | - | Si (React) | Si (React) | Si (React) | - | - | - |
| #8 Deploy flags | Si | Si | Si | Si | Si | Si | - | Si | - |
| #9 Percorsi Windows | Si | Si | Si | Si | Si | Si | Si | Si | Si |
| #10 Fish shell | Si (VPS Provider A) | Si (VPS Provider A) | Si (VPS Provider A) | - (VPS Provider B) | - (VPS Provider B) | Si (VPS Provider A) | - | - | - |
| #11 File da non committare | Si | Si | Si | Si | Si | Si | Si | Si | Si |
| #12 PostgreSQL JSONB | - | - | - | - | - | Si | - | Si | - |
| #13 Firestore streams | - | - | - | - | - | - | Si | - | - |
| #14 MQTT IoT | - | - | - | - | - | - | - | - | Si |
