# Patterns

> Sixteen patterns pulled from production bugs, generalized so they hold up outside the
> project that taught them. Each one states the problem, the fix, and the code.
>
> These are stack-specific pitfalls, not opinions about how to structure a codebase: if you
> don't run Laravel, skip the Laravel section.

---

## 1. Laravel: route [login] not defined

Wrapping an admin API group in `auth:api` throws `Route [login] not defined`, because Laravel's
default auth guard redirects unauthenticated requests to a named `login` route that JSON APIs
never register.

Skip the framework guard and check the token yourself in a dedicated middleware. It returns a
proper JSON 401/403 instead of trying to redirect.

```php
// Wrong: auth:api looks for a route named 'login' that doesn't exist
Route::prefix('admin')->middleware(['auth:api', 'admin'])->group(fn () => {});

// Right: AdminMiddleware checks auth internally
Route::prefix('admin')->middleware(['admin'])->group(function () {
    // AdminMiddleware calls auth('api')->check()
    // and returns JSON 401/403 without redirecting
});
```

---

## 2. Node.js: route ordering

Express matches routes in registration order. A dynamic `/:id` route registered before a
specific one like `/stats` swallows every request meant for the specific route, and the handler
you wrote for `/stats` never runs.

```javascript
// Right: specific routes before /:id
router.get('/stats', getStats);
router.get('/my-data', getMyData);
router.get('/:id', getById); // last, because it's a catch-all

// Wrong: /:id matches "stats" as an id, so /stats never fires
router.get('/:id', getById);
router.get('/stats', getStats);
```

---

## 3. Flutter: parsing inconsistent API responses

Backends rarely return one stable shape for the same kind of resource across all endpoints.
A courts listing might nest the object under a `court` key on one endpoint and return it flat
under `data` on another, and price fields drift between `price`, `base_price` and
`final_price` depending on who touched the endpoint last. Assuming a fixed shape throws
`type 'Null' is not a subtype of type 'Map<String, dynamic>'` at random, in whatever screen
happens to hit the inconsistent endpoint first.

Parse defensively at the boundary: check which shape you got, and fall back across the field
names you've actually seen in the wild.

```dart
// Nested shape: { courts: [{ court: {id, name}, slots: [{time, status}] }] }
final courtObj = courtData['court'] as Map<String, dynamic>;

// Flat shape: { data: [{id, name, status}] }
final items = (data['data'] as List?) ?? [];

// Different field names for the same value across endpoints
price: parseDouble(json['final_price'] ?? json['base_price'] ?? json['price'])
```

---

## 4. Flutter + Stripe: the Android theme has to be MaterialComponents

The Stripe Android SDK expects a `FlutterFragmentActivity` and a MaterialComponents theme.
Flutter's default project template ships neither, so the payment sheet crashes on launch with
an inflation exception that gives no hint the theme is the culprit.

```xml
<!-- android/app/src/main/res/values/styles.xml -->
<!-- Must extend MaterialComponents, not Theme.Light -->
<style name="LaunchTheme" parent="Theme.MaterialComponents.Light.NoActionBar">
</style>
```

```kotlin
// MainActivity.kt must extend FlutterFragmentActivity, not FlutterActivity
class MainActivity : FlutterFragmentActivity()
```

---

## 5. Laravel: clear and rebuild the config cache after touching .env

Laravel bakes `.env` values into a compiled config cache. Editing `.env` in production and
restarting the app is not enough: PHP-FPM workers and queue workers keep serving the cached
config from before your change, so the new value quietly never takes effect.

```bash
# Every time backend .env changes
docker compose exec backend php artisan config:clear
docker compose exec backend php artisan config:cache
```

---

## 6. Socket.io: handling disconnects without losing server authority

Sockets drop for reasons that need different responses. A server-initiated disconnect needs a
manual reconnect; most other reasons already reconnect on their own, and treating both cases
the same way either spams reconnect attempts or leaves the client stuck.

```javascript
socket.on('disconnect', (reason) => {
  if (reason === 'io server disconnect') {
    socket.connect(); // the server closed the socket on purpose, reconnect manually
  }
  // any other reason: socket.io already reconnects automatically
});

// Keep game/session state server-authoritative regardless:
// the client sends intents, the server validates and broadcasts the result.
```

---

## 7. Docker bind mounts silently overwrite the container's file permissions

A container built to run as a non-root user (say UID 1001) can still fail to write to its own
log directory in production, even though the Dockerfile does the right `chown`. The
`docker-compose.yml` bind mount (`./backend/logs:/app/logs`) replaces the container directory
with the host directory, permissions and all. If the host path is root-owned, so is the mount
point inside the container, no matter what the image sets up at build time.

```bash
# In the deploy script, before docker compose build:
ssh "$VPS" "mkdir -p $VPS_PATH/backend/logs && \
            chown -R 1001:1001 $VPS_PATH/backend/logs && \
            chmod 0775 $VPS_PATH/backend/logs"
```

To confirm this is the cause: `docker exec <container> ls -la /app/logs` showing `root:root`
while the Dockerfile chowns to a different UID means the bind mount is winning. Seen in
production on a Node service running as UID 1001 in the `nodejs` group, fixed as a step in the
deploy script rather than in the image.

---

## 8. Cloudflare blocks the datacenter IP, so proxy through a self-hosted WARP client

A server consuming an API or site behind Cloudflare gets an immediate 403 "Attention Required".
Routing the request through a Cloudflare Worker as an egress proxy works for a while, until the
Worker's own egress gets blocked too.

The WAF is blocking by IP and ASN, not by user agent: a datacenter IP gets denylisted regardless
of how convincing the request headers look. A Worker's egress is still Cloudflare network
space, and it eventually joins the same denylist. Routing instead through a self-hosted WARP
client bypasses this, because WARP's consumer IP pool isn't in the datacenter denylist.

```bash
# WARP container, run as standalone infrastructure, not part of the app's compose file
docker run -d --name warp-proxy --restart unless-stopped --network <app-network> \
  --cap-add NET_ADMIN \
  --sysctl net.ipv6.conf.all.disable_ipv6=1 \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  -v /root/warp-data:/var/lib/cloudflare-warp \
  caomingjun/warp
```

```php
// Route through the SOCKS5 proxy only when it's configured, so the app
// degrades to a direct request rather than depending on WARP being up.
$req = Http::timeout(30);
if ($proxy = config('services.origin_api.http_proxy')) { // e.g. socks5h://warp-proxy:1080
    $req = $req->withOptions(['proxy' => $proxy]); // socks5h resolves DNS through the proxy
}
$resp = $req->get($originUrl);
```

Three things make this resilient in practice. First, IP rotation: a cron probes the origin
through the proxy and, if it's failing, re-registers WARP for a new IP (`warp-cli registration
delete/new/connect`), throttled so it doesn't spin uselessly when the whole WARP range is
blocked. Second, alerting that makes a real call to the origin rather than a TCP ping, since a
ping succeeding tells you nothing about whether the WAF is blocking requests. Third, the
client's circuit breaker has to count thrown transport exceptions (403s, timeouts), not just
parsed application errors, or it never trips on "origin unreachable".

To diagnose: `curl https://origin` from the datacenter host returning 403 confirms the
datacenter IP is blocked; `curl --socks5-hostname warp-proxy:1080 https://origin` returning 200
confirms WARP works, and 403 means the WARP IP itself got blocked and needs to rotate. If a
different service hitting the same origin is down too, it's an origin outage, not a targeted
block.

Skip all of this if the provider offers an official SDK, an API key, or IP allowlisting: use
that instead. And don't reach for this to get around rate limits or terms of service; it's for
a legitimate integration hitting a WAF that can't tell your server apart from an attacker's.

---

## 9. Multi-tenant SaaS on a single database

For a SaaS with dozens of ordinary tenants (clubs, centers, organizations), a single database
with a `tenant_id` column, subdomain-based resolution, and automatic ORM scoping is simpler to
run than one database per tenant. It's the wrong choice for tenants that need strong isolation
for compliance, or for a handful of very large tenants where the blast radius of one noisy
neighbor matters more than operational simplicity.

The shape: a `tenants` table (slug and branding) resolved by a middleware from the subdomain,
a trait or global scope on every tenant-scoped model (`WHERE tenant_id = ?`, auto-filled on
create), theming applied at bootstrap, and config-cloning commands instead of hand-copied
fixes drifting between tenants.

Lessons paid for across two separate builds, one designed this way from the start and one
retrofitted onto an existing single-tenant app:

- The tenant-resolution middleware has to run before route-model binding substitution, or
  scoped route-model binding returns 404 for records that exist.
- If a tenant role lives on a pivot table (`tenant_user.role`), expose it explicitly on the
  session/profile endpoint (`tenant_role`). A frontend that reads the global role instead shows
  a tenant admin as a regular user.
- Browser storage is scoped per subdomain, so switching tenants leaves stale client state
  behind; refresh the profile on every app init rather than trusting cached storage.
- Retrofitting onto an existing table: add `tenant_id` nullable, backfill it, then make it
  `NOT NULL`. Renaming a long-lived table during the same migration needs a full grep across
  every endpoint that references it; one such rename caused a 500 in production.
- Composite indexes on `(tenant_id, date)` matter on the aggregate queries a super-admin portal
  runs across all tenants, which are exactly the queries that hit every partition.

---

## 10. Internal SSO between apps in the same organization

Two variants show up depending on what already exists.

**Variant A, an existing app becomes the identity provider.** When one app already owns the
user directory, satellite apps expose a login endpoint that verifies credentials against the
IdP server-to-server and then issues its own session. Compare the S2S key with a timing-safe
comparison, never `==`. The IdP should expose only aggregates to the satellite, no PII, and an
identity-mapping script pays for itself immediately since matching accounts by hand does not
scale past a handful of users. The trade-off worth calling out explicitly: in this scheme the
satellite app sees the password in plaintext at login time, which is acceptable only between
apps owned by the same party. Between different owners, use OAuth/OIDC instead, which exists
specifically to avoid this.

**Variant B, a shared OAuth hub for the organization.** With Google Workspace, one GCP project
with an Internal consent screen and one OAuth client per app avoids per-app user caps and
verification requirements. The project ID is immutable once created, though the display name
can be renamed freely; Internal-consent projects are visible only to accounts inside the
organization.

---

## 11. The sync-selector catch-22

Live entities (matches, orders, jobs) stay stale for tens of minutes even though the sync job
is running and everything else looks healthy.

The sync command selects what to update by filtering on the local database's own status column
(`WHERE status IN ('running', ...)`). But the transition into that status happens on the
external source, not locally. Until something syncs the record, the local row doesn't know
about the transition, so the selector never picks it up: nothing updates the row that would
tell the selector to look at it. Old stale rows that were never closed out make this worse by
sitting in the selector's blind spot indefinitely.

Fix it with a second selector that doesn't depend on local status at all, for example "every
container active today" from the time dimension, unioned with the status-based one. Add a
time-based guard (`updated_at >= now() - 30 days`) to exclude historically stale rows from
inflating future scans, plus a one-off cleanup of the backlog.

To confirm: sync a single entity directly, bypassing the selector entirely. If that updates it
correctly, the bug is in the selector, not in the sync logic itself.

---

## 12. Page speed: the cold-cache cost is the one that bites

Measure time-to-first-byte twice in a row, cold then warm. A page that's slow cold and fast
warm is paying a cache-population cost, not running a slow query, and optimizing the query
won't fix it. From there, sort the query log by duration; usually one query dominates the page,
and `EXPLAIN` tells you why.

The five levers, in the order they come up in practice:

1. **Per-request memoization on top of the shared cache** (`$this->memo ??= Cache::remember(...)`).
   Deserializing a 4,500-entry cached value 300 times on one page render cost 3 seconds by
   itself, before any query ran.
2. **Scope aggregates to the working set.** A `leftJoinSub` that materializes the whole table to
   use 1% of it pays for the other 99% every time.
3. **A composite index added online** (`ALGORITHM=INPLACE, LOCK=NONE`) so a range scan can be
   satisfied by the index alone.
4. **Cache expensive queries that currently aren't cached.** Occasional latency spikes are
   usually a cold buffer pool, not a slow query.
5. **Warm the cache via a loopback request**, a scheduled job that hits the heavy landing pages
   on `127.0.0.1` so the warmer pays the recompute cost instead of the first real visitor.
   Exclude the warmer's user agent from analytics and rate limiting, and never warm a page that
   itself calls the warmer.

---

## 13. Git and deploy over an unstable network

A handful of hard-won rules for deploying to a remote host over `git pull` when the network to
that host is flaky:

- Retry every `git push`/`fetch`/`pull` against the remote host; intermittent ~20-second
  timeouts are common enough that a bare command without retry logic fails a meaningful
  fraction of the time.
- Never run a local `git push` and a remote deploy in parallel. If the deploy does
  `git reset --hard origin/main`, it can grab whichever commit landed first, not the one you
  meant to ship. Push, wait for it to land, then deploy.
- `git reset --hard` deletes every uncommitted change on the remote without asking, including a
  config file someone hand-edited during an incident. Before adopting it in a deploy script,
  set a clear policy that production is never edited by hand; when in doubt, run `git status`
  and `git stash` before the reset.
- A deploy that builds from `git pull` on the remote host doesn't fail just because you forgot
  to push. It "succeeds" without changing anything. An identical bundle hash before and after a
  deploy is the tell.
- Guard the build step: `docker compose up -d --build` reuses the old image silently when the
  build fails. Separate `build` from `up` and check the build's exit code explicitly.

---

## 14. OTP-over-email as a "simple e-signature" for people without an account

For getting signatures on documents (consent forms, agreements) from people who don't have an
account (parents, external guardians, off-platform partners), and where you need evidentiary
weight above an unsigned form but don't have access to a qualified digital signature scheme.

The recipe: a single-use personal link with a cryptographic token, followed by a 6-digit OTP
sent by email (hashed with a pepper in the database, roughly a 10-minute expiry, a 5-attempt
cap, rate-limited), a short-lived session, and a signature record that stores identity,
timestamp, IP, user agent, and a SHA-256 hash of the canonical document snapshot. Once signed,
the document is immutable: any substantive change invalidates the existing signatures. Run in
production across two portals with several signer roles (parents, corporate guardians, legal
representatives).

This is a simple electronic signature reinforced with an audit trail, not a qualified signature
under a legal framework like eIDAS, even though it borrows some of the same guarantees. Its
evidentiary weight depends on your jurisdiction and is ultimately a matter for a court to weigh.
Before using this for anything with real legal stakes, especially anything involving minors,
run it past legal counsel or a data protection officer first.

---

## 15. Web push through FCM's HTTP v1 API without the server SDK

The Firebase Admin SDK is a heavy dependency for what the HTTP v1 API actually needs: sign a
JWT with RS256 by hand (`openssl_sign` works fine), exchange it for an OAuth token, then POST to
`messages:send`. The client side stays exactly what you'd expect: `getToken(VAPID)` against the
existing service worker. Send data-only payloads, prune tokens that come back invalid, and make
the whole feature a no-op rather than a crash when credentials are missing, so push degrades
instead of breaking the app around it.

The trap that costs real time: a queue worker started with a config cache baked for a different
environment (say, the default sqlite connection) points at the wrong database and stops
consuming jobs silently. No errors, no failed sends logged, just emails and pushes that never
go out. Run `config:clear && config:cache` at the start of every worker and scheduler process,
and verify honestly: enqueue a job and confirm the queue drains back to zero on its own rather
than assuming it will.

---

## 16. Payment webhooks: "paid" can arrive before the transaction settles

Symptom: double credits or vouchers, or an inconsistent state after a refund or a chargeback.

Payment providers can notify `paid` before the transaction is fully consolidated on their side,
and the same webhook delivery can arrive more than once. Treat an unsigned webhook as a trigger
to check, never as the truth by itself: on receipt, call the provider's API for the
authoritative status and look for the transaction that's actually `SUCCESSFUL`, which isn't
necessarily the most recent one returned.

Make every settle/reconciliation operation idempotent under a row lock keyed on the provider's
transaction ID. In a multi-tenant system, keep each tenant's provider credentials separate so
one tenant's webhook can never settle another tenant's transaction.

---
