# Pattern Critici Cross-Progetto

> Riferimento rapido per i pattern fondamentali applicabili a TUTTI i progetti.

---

## 1. deploy.sh e' LOCALE (CRITICAL - Tutti i progetti)

```bash
# CORRETTO - deploy.sh e' sul PC locale, NON sul VPS
cd D:/progetti/progetto-web-1.example && ./deploy.sh

# SBAGLIATO - deploy.sh non esiste sul VPS!
ssh root@VPS "./deploy.sh"
```

---

## 2. Git -> Deploy Workflow (CRITICAL)

```bash
# SEMPRE: commit -> push -> deploy
# Le modifiche DEVONO essere su Git prima del deploy!

git add . && git commit -m "fix: description" && git push origin main
./deploy.sh --backend-only

# SBAGLIATO: Modificare file -> deploy senza commit/push
# Risultato: Deploy NON vede le modifiche!
```

---

## 3. Frontend e' Build Statico (CRITICAL)

```
Modifiche Vue/React NON visibili dopo git pull senza rebuild!
Serve SEMPRE: ./deploy.sh --frontend-only

Le variabili VITE_* vengono BAKED nel bundle durante build.
Modifiche .env frontend richiedono rebuild completo.
```

---

## 4. VITE_API_URL (CRITICAL - Vue & React)

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

## 5. Laravel: Route [login] not defined (CRITICAL)

```php
// SBAGLIATO - auth:api cerca route 'login' inesistente
Route::prefix("admin")->middleware(["auth:api", "admin"])->group(fn() => {});

// CORRETTO - AdminMiddleware gestisce auth internamente
Route::prefix("admin")->middleware(["admin"])->group(fn() => {
    // AdminMiddleware chiama auth('api')->check()
    // Restituisce JSON 401/403 senza redirect
});
```

---

## 6. Node.js: Route Ordering (CRITICAL)

```javascript
// CORRETTO - Specifiche PRIMA di /:id
router.get('/stats', getStats);     // FIRST
router.get('/my-data', getMyData);  // SECOND
router.get('/:id', getById);        // LAST (dynamic)

// SBAGLIATO - /:id cattura tutto!
router.get('/:id', getById);        // Matcha "stats"!
router.get('/stats', getStats);     // Mai raggiunto
```

---

## 7. Node.js: Logger (non console.log)

```javascript
// CORRETTO
const logger = require('../config/logger');
logger.info('Operation completed');
logger.error(`Error: ${error.message}`);

// SBAGLIATO - Non appare in docker logs
console.log('Message');
```

---

## 8. MongoDB: User e' Single Source of Truth

```javascript
// CORRETTO - Dati identita' SOLO da User via populate
const player = await Player.findById(id).populate('user');
const name = player.user.firstName;  // Da User!

// SBAGLIATO - NON creare campi duplicati in Player/Coach/Delegate!
// Player.name, Player.email -> NON ESISTONO, vengono da User
```

---

## 9. React: AuthContext (currentUser, NON user)

```jsx
// CORRETTO
const { currentUser, isAuthenticated, isAdmin } = useAuth();

// SBAGLIATO
const { user } = useAuth();  // NON esiste!
```

---

## 10. Flutter: API Response Parsing (CRITICAL)

```dart
// API puo' restituire formati diversi. VERIFICARE SEMPRE!

// Formato nested (availability grid)
// { courts: [{ court: {id, name}, slots: [{time, status}] }] }
final courtObj = courtData['court'] as Map<String, dynamic>;

// Formato flat (lista semplice)
// { data: [{id, name, status}] }
final items = (data['data'] as List?) ?? [];

// Price: gestire nomi campo diversi
price: parseDouble(json['final_price'] ?? json['base_price'] ?? json['price'])
```

---

## 11. Flutter: MaterialComponents Theme (per Stripe)

```xml
<!-- android/app/src/main/res/values/styles.xml -->
<!-- DEVE usare MaterialComponents, NON Theme.Light! -->
<style name="LaunchTheme" parent="Theme.MaterialComponents.Light.NoActionBar">
</style>
```

```kotlin
// MainActivity.kt - DEVE estendere FlutterFragmentActivity!
class MainActivity: FlutterFragmentActivity()
```

---

## 12. Deploy Flags (CRITICAL - Performance)

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

## 13. Percorsi File Windows

```
# CORRETTO - Percorsi assoluti con backslash
C:\progetti\progetto-web-1.example\frontend\src\file.vue

# SBAGLIATO - Percorsi relativi
frontend/src/file.vue
```

---

## 14. VPS Fish Shell (VPS Provider A)

```bash
# Alcuni provider VPS usano fish come shell di default - usare bash -c per comandi bash
ssh root@<VPS_A_IP> "bash -c 'cd /root/progetto-web-1.example && docker compose ps'"

# Provider B usa bash - comandi diretti OK
ssh root@<VPS_B_IP> "cd /opt/progetto-api-1.example && docker compose ps"
```

---

## 15. File NON Committare Mai

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

## 16. Laravel Config Cache

```bash
# SEMPRE dopo modifiche .env backend
docker compose exec backend php artisan config:clear
docker compose exec backend php artisan config:cache
```

---

---

## 17. Socket.io: Gestione Disconnessioni (ProgettoRealtime)

```javascript
// CORRETTO - Gestire riconnessione con stato
socket.on('disconnect', (reason) => {
  if (reason === 'io server disconnect') {
    socket.connect(); // Riconnessione manuale
  }
  // else riconnessione automatica
});

// Game state: SEMPRE server-authoritative
// Client invia azioni, server valida e broadcast
```

---

## 18. PostgreSQL: JSONB per Dati Strutturati (ProgettoRealtime)

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

## 19. Firebase/Firestore: Stream vs Future (ProgettoMobile1)

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

## 20. ESP32/IoT: MQTT Topics Convention (ProgettoIoT2)

```
// Topic structure: project/location/sensor_type
orto/interno/temperatura
orto/esterno/temperatura
orto/suolo/umidita

// SEMPRE: QoS 1 per dati sensori (at least once delivery)
// WiFiManager per configurazione rete senza hardcoding
```

---

## 21. Docker bind mount: perm sovrascritti dall'host (CRITICAL - tutti i progetti con volumi)

**Sintomo**: Container Node/PHP/etc. gira come utente non-root (es. UID 1001), Dockerfile fa `chown` corretto ma a runtime la cartella è ancora `root:root` e il processo non puo' scrivere.

**Causa**: `docker-compose.yml` ha un bind mount tipo `./backend/logs:/app/logs`. Il bind mount **sovrascrive** completamente i perm del Dockerfile con quelli della cartella host. Se la cartella host è root-owned, lo è anche dentro al container.

**Fix**: chown della cartella host con UID/GID dell'utente container, idealmente nel `deploy.sh`:

```bash
# In deploy.sh, prima del docker compose build:
ssh $VPS "mkdir -p $VPS_PATH/backend/logs && \
          chown -R 1001:1001 $VPS_PATH/backend/logs && \
          chmod 0775 $VPS_PATH/backend/logs"
```

**Diagnosi**: se `docker exec <container> ls -la /app/logs` mostra `root:root` ma Dockerfile chown a UID 1001 → cercare bind mount in `docker-compose.yml`.

**Riferimento concreto**: ProgettoApi2 — `./backend/logs:/app/logs` con utente `progetto-api-2` (UID 1001 in `nodejs` group). Risolto in `deploy.sh` Step 1b.

---

## 22. Cloudflare WAF blocca l'IP datacenter -> proxy WARP self-hosted (CRITICAL - scraping/API esterne da VPS)

**Sintomo**: un servizio/VPS in datacenter consuma un'API o un sito protetti da Cloudflare e riceve **403 "Attention Required"** immediato. Mettere un Cloudflare Worker come proxy egress funziona per un po', poi **anche l'egress del Worker** viene bloccato 403.

**Causa**: il WAF blocca per **IP/ASN datacenter**, non per User-Agent. Quando il bypass e' un Worker, fa egress dalla rete Cloudflare stessa -> l'avversario puo' aggiungere quel range al denylist. UA "browser realistic" non aiuta: e' blocco di rete, non di fingerprint.

**Fix**: instradare le richieste attraverso un container **WARP self-hosted** che espone un proxy SOCKS5. L'IP del pool **consumer** WARP non e' nel denylist datacenter -> richiesta DIRETTA all'origine passa.

```bash
# Container WARP (infra "pet", non nel docker-compose del progetto)
docker run -d --name warp-proxy --restart unless-stopped --network <rete-app> \
  --cap-add NET_ADMIN \
  --sysctl net.ipv6.conf.all.disable_ipv6=1 \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  -v /root/warp-data:/var/lib/cloudflare-warp \
  caomingjun/warp
```

```php
// Client HTTP: quando il proxy e' settato, richiesta DIRETTA via SOCKS5
// (env letta dentro config/*.php -> cache-safe, funziona anche in php-fpm)
$req = Http::timeout(30);
if ($proxy = config('services.<svc>.http_proxy')) {   // es. socks5h://warp-proxy:1080
    $req = $req->withOptions(['proxy' => $proxy]);     // socks5h = DNS lato proxy
}
$resp = $req->get($originUrl);
```

**Resilienza**: (1) **auto-rotazione IP** con un cron che sonda l'origine via proxy e, se KO, ri-registra WARP (`warp-cli registration delete/new/connect`) per un nuovo IP (con throttle: se l'INTERO range WARP e' bloccato la rotazione non aiuta). (2) **alert** che fa una *vera* chiamata all'origine (non un ping TCP) e notifica su fallimento. (3) il **circuit-breaker** lato client deve contare anche le **eccezioni di trasporto** thrown (403/timeout), non solo gli errori applicativi parsati, altrimenti non scatta sul caso "origine irraggiungibile".

**Diagnosi**: `curl https://origin` dal VPS = 403 -> IP datacenter bloccato; `curl --socks5-hostname warp-proxy:1080 https://origin` = 200 -> WARP ok / 403 -> IP WARP bloccato (ruota). Se anche un competitor che usa la stessa origine e' vuoto -> outage origine, non blocco mirato.

**Quando NO**: se esiste auth/SDK ufficiale o whitelist IP -> usa quelli. Niente abuso di rate (rate-limit + jitter + circuit-breaker). Niente scraping di contenuti coperti da ToS/copyright.

**Piano C** (se l'intero range WARP cade): proxy residenziale a pagamento, oppure browser headless (pesante).

---

## 23. Multi-tenant single-DB per SaaS white-label (CRITICAL - v0.2)

**Quando**: SaaS con decine di tenant "normali" (club, centri, società). Un DB, colonna `tenant_id`, risoluzione dal sottodominio, scoping automatico ORM. NON per tenant con isolamento forte (compliance) o pochi tenant giganti.

**Architettura**: tabella `tenants` (slug+branding) → middleware di risoluzione (`<slug>.dominio` → tenant nel container) → trait/global scope su OGNI modello tenant-scoped (`WHERE tenant_id=?` + auto-fill al create) → theming a bootstrap → comandi di clonazione config (mai fix a mano replicati).

**Trappole pagate** (due progetti reali, uno by-design e uno retrofit):
- Il middleware di risoluzione DEVE girare **prima** di `SubstituteBindings`, o il route-model binding scoped dà 404.
- Se il ruolo tenant vive in una pivot (`tenant_user.role`), va esposto ESPLICITAMENTE in `/auth/me` (`tenant_role`): il frontend che guarda il ruolo globale mostrerà l'admin come utente normale.
- **localStorage è per-sottodominio**: cambiando tenant lo stato client è stantio → refresh profilo a ogni init.
- Retrofit: `tenant_id` NULLABLE → backfill → NOT NULL; il rename di tabelle "storiche" richiede grep completo sugli endpoint (un rename ha causato 500 in produzione).
- Query aggregate del portale super-admin: indici compositi `(tenant_id, data)` sulle join calde.

---

## 24. SSO interno tra app dello stesso ecosistema (v0.2)

**Variante A — un'app esistente diventa Identity Provider**: quando un'app possiede già utenti/anagrafica, le app satellite espongono un endpoint di login che verifica le credenziali CONTRO l'IdP server-to-server e emette la PROPRIA sessione. Chiave S2S in header dedicato confrontata **timing-safe** (mai `==`). Endpoint dati esposti all'IdP: solo aggregati, **niente PII**. Prevedere lo script di mapping delle identità (fatto a mano è un bagno di sangue). ⚠️ Trade-off: in questo schema **l'app satellite vede la password in chiaro** — accettabile SOLO tra app dello stesso titolare; tra titolari diversi usa OAuth/OIDC, che esiste esattamente per evitarlo.

**Variante B — hub OAuth condiviso per organizzazione** (Google Workspace): UN progetto GCP con consent **Internal** e un client OAuth per app. Evita limiti utenti/verifica per ogni nuova app. Gotcha: il **project ID è immutabile** (il display name si può rinominare senza rompere nulla); progetti Internal visibili SOLO agli account dell'org.

---

## 25. Sync selector catch-22: lo stato locale come filtro verso la sorgente esterna (CRITICAL - v0.2)

**Sintomo**: entità "live" (match, ordini, stati) restano stali per decine di minuti nonostante il sync giri; il sistema è sano.

**Causa**: il comando di sync seleziona cosa aggiornare filtrando **sullo stato del DB locale** (es. `WHERE status IN (running…)`). Ma la transizione `scheduled → running` avviene sulla sorgente esterna: finché nessuno sincronizza, il DB locale non la conosce → il selettore non la vede → catch-22. Aggravante: record stali storici (mai chiusi) inquinano il selettore.

**Fix**: (1) union con un **secondo selettore indipendente dallo stato locale** (es. "contenitori attivi oggi" dalla dimensione temporale); (2) guard temporale che esclude gli stali storici (`updated >= now-30d`) + cleanup one-shot.

**Diagnosi**: smoke-test del sync DIRETTO sulla singola entità (bypassando i selettori): se aggiorna, il bug è al 100% nei selettori, non nel sync.

---

## 26. Page speed: il costo a cache fredda è il vero nemico (v0.2)

**Metodo**: misura TTFB **due volte di fila** (cold vs warm). La firma "alto→basso" = costo di popolamento cache, non query lenta. Poi query log ordinato per tempo (quasi sempre UNA query domina) → EXPLAIN.

**Le 5 leve** (in ordine di frequenza d'uso): (1) **memo per-richiesta** sopra la cache condivisa (`$this->memo ??= Cache::remember(...)` — una deserializzazione da 4.5k voci ripetuta 300×/pagina costava 3s); (2) **scope dell'aggregato al working set** (mai `leftJoinSub` che materializza su tutta la tabella per usarne l'1%); (3) **indice composito ONLINE** (`ALGORITHM=INPLACE, LOCK=NONE`) per range scan covering; (4) cache delle query pesanti *uncached* (gli spike saltuari = buffer pool freddo); (5) **cache warming via loopback** (comando schedulato che colpisce le landing pesanti su 127.0.0.1: il recompute lo paga il warmer, non l'utente — escludi lo user-agent del warmer da analytics e rate-limit, e non warmare pagine che a loro volta chiamano il warmer).

---

## 27. Git e deploy su VPS con rete instabile (CRITICAL - v0.2)

- **Retry obbligatorio** su ogni `git push/fetch/pull` da/verso il VPS (timeout intermittenti ~20s): loop con break sul marker di successo dell'output.
- **Mai** `git push` locale e deploy remoto **in parallelo**: se il deploy fa `git reset --hard origin/main`, può prendere il commit sbagliato. Sequenza: push → attendi → deploy.
- ⚠️ `git reset --hard` **cancella senza conferma ogni modifica non committata sul server** (hotfix a mano, file di config ritoccati): prima di adottarlo in un deploy script, policy chiara "mai editare in produzione"; in dubbio, `git status` + `git stash` prima del reset.
- **Il deploy che builda da `git pull` sul VPS non fallisce se non hai pushato**: "riesce" senza cambiare nulla. Bundle hash identico dopo il deploy = red flag.
- **Build-guard**: `docker compose up -d --build` con build FALLITO riusa silenziosamente l'image vecchia → separare `build` da `up` con `if !` esplicito.

---

## 28. Firma "FEA-like" via OTP email per esterni senza account (v0.2)

**Quando**: far firmare atti (autorizzazioni, patti) a persone SENZA account — genitori, tutor esterni — con valore probatorio da atto amministrativo, senza SPID/firma qualificata.

**Ricetta**: link personale **monouso** (token crittografico) → OTP 6 cifre via email (hash in DB con pepper, scadenza ~10 min, max 5 tentativi, rate-limit) → sessione temporanea breve → firma registrata con identità+timestamp+IP+UA+**impronta SHA-256 dello snapshot canonico** del documento. Documento firmato = immutabile (modifica sostanziale → invalida le firme). Verificato in produzione su due portali scolastici (multi-ruolo: genitori, tutor aziendali, legali rappresentanti).

⚠️ **Disclaimer legale**: tecnicamente questa è una firma elettronica **semplice** rafforzata da audit trail — NON una FEA ai sensi eIDAS, per quanto ne mutui alcune garanzie. Il valore probatorio è rimesso alla valutazione del giudice (art. 20 CAD) e il dominio è regolato: prima di usarla su atti reali (specie se coinvolgono minori) passa da DPO/consulenza legale.

---

## 29. Web push FCM HTTP v1 senza SDK server (v0.2)

**Perché**: l'SDK Admin è una dipendenza pesante per quello che è: JWT RS256 firmato a mano (`openssl_sign`) → OAuth token → `messages:send`. Client: `getToken(VAPID)` sul service worker esistente. Notifiche data-only, prune dei token invalidi, **no-op se le credenziali mancano** (la feature degrada, non rompe).

**La trappola che costa giorni**: queue worker partito con `config:cache` "baked" su un ambiente diverso (es. default sqlite) → guarda un DB SBAGLIATO e **non consuma i job in silenzio**: email/push mai inviate, zero errori. Fix: `config:clear && config:cache` all'avvio di ogni worker/scheduler. Test onesto: accoda un job e verifica che `jobs` torni a 0 da solo.

---

## 30. Webhook di pagamento: `paid` arriva prima della compensazione (v0.2)

**Sintomo**: doppi accrediti/voucher, o stati incoerenti su rimborsi e compensazioni.

**Causa**: il provider (es. SumUp) può notificare `paid` PRIMA che la transazione sia consolidata, e il webhook può arrivare più volte. Il webhook non firmato va trattato come **trigger**, mai come verità: alla ricezione si fa la **verifica autoritativa** via API e si cerca la transazione SUCCESSFUL (non necessariamente l'ultima).

**Fix**: ogni operazione di settle/compensazione **idempotente sotto row lock** (chiave = id transazione provider); credenziali dei provider per-tenant nei sistemi multi-tenant.

---

## Quick Reference: Quale Pattern per Quale Progetto

> Nota: gli esempi nei pattern usano nomi progetto anonimizzati (ProgettoWeb1, ProgettoApi2...); i pattern **#23–30 (v0.2)** sono trasversali e valgono per qualunque progetto dello stack corrispondente, quindi non compaiono nella tabella.

| Pattern | ProgettoWeb1 | ProgettoWeb2 | ProgettoWeb3 | ProgettoApi1 | ProgettoApi2 | ProgettoRealtime | ProgettoMobile1 | ProgettoIoT1 | ProgettoIoT2 |
|---------|-----------|---------|----------------|-------|------------|---------------|----------|-----------------|--------------|
| #1 deploy.sh locale | Si | Si | Si | Si | Si | Si | - | Si | - |
| #2 Git -> Deploy | Si | Si | Si | Si | Si | Si | - | Si | - |
| #3 Build statico | Si | Si | Si | Si | Si | Si | - | Si | - |
| #4 VITE_API_URL | Si (Vue) | Si (Vue) | Si (Vue) | Si (React) | Si (React) | Si (React) | - | Si (React) | - |
| #5 Route [login] | Si (Laravel) | Si (Laravel) | Si (Laravel) | - | - | - | - | - | - |
| #6 Route ordering | - | - | - | Si (Express) | Si (Express) | Si (Express) | - | Si (Express) | - |
| #7 Logger | - | - | - | Si (Node.js) | Si (Node.js) | Si (Node.js) | - | Si (Node.js) | - |
| #8 User SSoT | - | - | - | Si (MongoDB) | Si (MongoDB) | - | - | - | - |
| #9 currentUser | - | - | - | Si (React) | Si (React) | Si (React) | - | - | - |
| #10 API parsing | Si (Flutter) | Si (Flutter) | - | Si (Flutter) | Si (Flutter) | - | Si (Flutter) | - | - |
| #11 MaterialComponents | Si (Flutter) | Si (Flutter) | - | Si (Flutter) | Si (Flutter) | - | Si (Flutter) | - | - |
| #12 Deploy flags | Si | Si | Si | Si | Si | Si | - | Si | - |
| #13 Percorsi Windows | Si | Si | Si | Si | Si | Si | Si | Si | Si |
| #14 Fish shell | Si (VPS Provider A) | Si (VPS Provider A) | Si (VPS Provider A) | - (VPS Provider B) | - (VPS Provider B) | Si (VPS Provider A) | - | - | - |
| #15 File da non committare | Si | Si | Si | Si | Si | Si | Si | Si | Si |
| #16 Config cache | Si (Laravel) | Si (Laravel) | Si (Laravel) | - | - | - | - | - | - |
| #17 Socket.io | - | - | - | - | - | Si | - | - | - |
| #18 PostgreSQL JSONB | - | - | - | - | - | Si | - | Si | - |
| #19 Firestore streams | - | - | - | - | - | - | Si | - | - |
| #20 MQTT IoT | - | - | - | - | - | - | - | - | Si |
| #21 Docker bind perm | Si | Si | Si | Si | Si | Si | - | Si | - |
| #22 WARP IP bypass | - | - | Si (VPS Provider A) | - | - | - | - | - | - |
