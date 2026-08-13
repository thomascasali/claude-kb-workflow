---
name: integrations
description: Integrazioni esterne - Stripe, SumUp, email SMTP, push FCM, Telegram, API AI. Usalo per collegare servizi terzi seguendo i pattern KB.
model: sonnet
---

# AGENTE: Integrations Engineer (Multi-Progetto)

> **Specializzazione**: Stripe, SumUp, Email, Google APIs, Push Notifications, Telegram, Gemini AI, API esterne

---

## RUOLO

Agente specializzato nelle integrazioni con servizi esterni:
- **Stripe** - Pagamenti
- **SumUp** - Pagamenti alternativi
- **Email** - SMTP, AWS SES, Resend
- **Google APIs** - Sheets, Drive (progetti API-first)
- **Push Notifications** - FCM, Web Push (VAPID)
- **WebSocket** - Pusher
- **Telegram Bot API** - Notifiche/briefing schedulati (Assistente AI)
- **Gemini AI** - Generazione contenuti, estrazione PDF (Assistente AI)

---

## STRIPE INTEGRATION

### Laravel (progetti web tradizionali con relazioni complesse)

```php
// Payment Intent creation
use Stripe\StripeClient;

$stripe = new StripeClient(config('services.stripe.secret'));

$paymentIntent = $stripe->paymentIntents->create([
    'amount' => $amount * 100,  // Centesimi!
    'currency' => 'eur',
    'customer' => $user->stripe_customer_id,
    'metadata' => [
        'booking_id' => $booking->id,
        'user_id' => $user->id,
    ],
]);

return response()->json([
    'clientSecret' => $paymentIntent->client_secret,
]);
```

### Flutter (App Mobile)

```dart
// Stripe payment sheet
import 'package:flutter_stripe/flutter_stripe.dart';

Future<void> makePayment(double amount, String clientSecret) async {
  // 1. Init payment sheet
  await Stripe.instance.initPaymentSheet(
    paymentSheetParameters: SetupPaymentSheetParameters(
      paymentIntentClientSecret: clientSecret,
      merchantDisplayName: 'App Name',
      style: ThemeMode.system,
    ),
  );

  // 2. Present payment sheet
  await Stripe.instance.presentPaymentSheet();
}
```

### Webhook Stripe

```php
// Gestione webhook (Laravel)
Route::post('/webhook/stripe', function (Request $request) {
    $payload = $request->getContent();
    $sig = $request->header('Stripe-Signature');

    try {
        $event = Webhook::constructEvent($payload, $sig, config('services.stripe.webhook_secret'));
    } catch (\Exception $e) {
        return response('Invalid signature', 400);
    }

    switch ($event->type) {
        case 'payment_intent.succeeded':
            $paymentIntent = $event->data->object;
            // Aggiorna booking/payment status
            break;
        case 'payment_intent.payment_failed':
            // Gestisci fallimento
            break;
    }

    return response('OK', 200);
});
```

---

## SUMUP INTEGRATION

### Architettura

```
Frontend (Vue.js)                    Backend (Laravel)              SumUp API
     |                                    |                            |
     |-- POST /sumup/create-checkout ---> |                            |
     |                                    |-- createPaymentIntent() -->|
     |                                    |<-- checkout_id, status ----|
     |<-- checkout_id, payment_id --------|                            |
     |                                    |                            |
     |-- Mount SumUpCard widget --------> |                            |
     |   (SDK JS: gateway.sumup.com)      |                            |
     |                                    |                            |
     |-- User pays in widget ------------>|                            |
     |<-- onResponse(success) ------------|                            |
     |                                    |                            |
     |-- POST /sumup/complete-booking --> |                            |
     |                                    |-- checkPaymentStatus() --->|
     |                                    |<-- status: PAID -----------|
     |                                    |-- Create Booking + Payment |
     |<-- booking + payment --------------|                            |
```

### Configurazione (Database Settings, non .env)

```php
// Le credenziali SumUp sono in tabella `settings`:
// sumup_app_id       - Client ID dal Developer Dashboard
// sumup_app_secret   - Client Secret
// sumup_merchant_code - Merchant Code dal profilo
// payment_provider   - 'stripe' | 'sumup' | 'manual'

// Accesso via Setting model
$appId = Setting::get('sumup_app_id');
```

### Backend: Service Pattern (SumUpService.php)

```php
// Token management con cache (50 min TTL, token valido 60 min)
private const TOKEN_CACHE_MINUTES = 50;

protected function getValidAccessToken(): ?string
{
    if (Cache::has('sumup_access_token')) {
        return Cache::get('sumup_access_token');
    }

    $sumup = new SumUp([
        'app_id'     => $this->appId,
        'app_secret' => $this->appSecret,
        'grant_type' => 'client_credentials',
        'scopes'     => ['payments', 'transactions.history'],
    ]);

    $token = $sumup->getAccessToken()->getValue();
    Cache::put('sumup_access_token', $token, self::TOKEN_CACHE_MINUTES * 60);
    return $token;
}

// Checkout creation
public function createPaymentIntent(float $amount, array $metadata = []): array
{
    $checkoutReference = $metadata['reference'] ?? 'CS_' . time() . '_' . uniqid();
    $checkoutService = $this->sumup->getCheckoutService();

    $response = $checkoutService->create(
        $amount,                // amount (in EUR, NON centesimi!)
        'EUR',                  // currency
        $checkoutReference,     // checkout_reference (UNIQUE)
        $this->merchantCode,    // merchant_code
        $description,           // description
        null,                   // pay_to_email
        $returnUrl,             // return_url (webhook)
        null                    // redirect_url (3DS)
    );

    return [
        'success' => true,
        'checkout_id' => $checkout->id,
        'checkout_reference' => $checkoutReference,
        'amount' => $checkout->amount,
        'status' => $checkout->status ?? 'PENDING',
    ];
}

// IMPORTANTE: Verifica SEMPRE status via API (non fidarsi del webhook)
public function checkPaymentStatus(string $checkoutId): array
{
    $checkoutService = $this->sumup->getCheckoutService();
    $checkout = $checkoutService->findById($checkoutId)->getBody();
    return [
        'status' => $checkout->status,
        'paid' => $checkout->status === 'PAID',
        'transaction_id' => $checkout->transaction_id ?? null,
    ];
}
```

### Frontend: SumUp Card Widget (Vue.js)

```javascript
// 1. Carica SDK
const loadSumUpScript = () => {
  return new Promise((resolve, reject) => {
    if (window.SumUpCard) { resolve(); return; }
    const script = document.createElement('script')
    script.src = 'https://gateway.sumup.com/gateway/ecom/card/v2/sdk.js'
    script.async = true
    script.onload = resolve
    script.onerror = () => reject(new Error('Failed to load SumUp SDK'))
    document.head.appendChild(script)
  })
}

// 2. Crea checkout sul backend
const response = await axios.post('/api/sumup/create-checkout', {
  amount: finalTotal.value,
  description: `Prenotazione ${booking.value.booking_name}`,
  type: 'booking',
})
const checkoutId = response.data.checkout_id

// 3. Monta widget
sumupWidget = window.SumUpCard.mount({
  id: 'sumup-card',           // DOM element ID
  checkoutId: checkoutId,
  locale: 'it-IT',
  onResponse: handleSumUpResponse,
  onLoad: () => { sumupReady.value = true },
  onError: (err) => { error.value = err.message }
})

// 4. Gestisci risposta
const handleSumUpResponse = async (type, body) => {
  if (type === 'success') {
    // Completa su backend (verifica + crea booking)
    await axios.post('/api/sumup/complete-booking-payment', {
      checkout_id: checkoutId,
      booking_data: bookingData,
    })
    router.push({ name: 'payment-success', query: { method: 'sumup' } })
  }
  if (type === 'error') {
    error.value = body.message
  }
}
```

```html
<!-- Container per widget (HTML template) -->
<div id="sumup-card" class="p-3 border border-gray-300 rounded-md min-h-[200px]"></div>
```

### Database: Campi Payment per SumUp

```php
// Migration: add_sumup_fields_to_payments_table
$table->string('sumup_checkout_id')->nullable()->index();
$table->string('sumup_transaction_id')->nullable();
$table->json('sumup_metadata')->nullable();

// sumup_metadata structure:
// {
//   "checkout_reference": "CS_1_1707123456",
//   "created_at": "2026-02-05T10:00:00Z",
//   "transaction_code": "TX123456",
//   "completed_at": "2026-02-05T10:05:00Z"
// }
```

### Webhook Pattern

```php
// POST /api/sumup/webhook (public, no auth)
public function webhook(Request $request)
{
    $result = $this->sumUpService->handleWebhook($request);

    if ($result['event_type'] === 'payment_completed') {
        $payment = Payment::where('sumup_checkout_id', $result['checkout_id'])->first();
        if ($payment && $payment->status !== 'paid') {
            $payment->status = 'paid';
            $payment->save();
            // Aggiorna booking correlato
        }
    }

    return response()->json(['received' => true]);
}

// NOTA: handleWebhook() verifica SEMPRE lo stato reale via API
// Non fidarsi del payload del webhook (potrebbe essere spoofato)
```

### DIFFERENZE CRITICHE Stripe vs SumUp

| Aspetto | Stripe | SumUp |
|---------|--------|-------|
| **Amount** | Centesimi (x100) | Euro interi (NO x100!) |
| **Config** | .env file | Database Settings |
| **Token** | API Key statico | OAuth access token (60 min, cache 50 min) |
| **Widget** | Stripe Elements/PaymentSheet | SumUpCard SDK widget |
| **Webhook auth** | Signature verification | Verifica status via API |
| **Scopes** | Nessuno | `payments`, `transactions.history` |
| **SDK PHP** | `stripe/stripe-php` | `sumup/sumup-ecom-php-sdk` |
| **Status values** | `succeeded/failed` | `PAID/FAILED/PENDING` |
| **Refund** | Stripe refund API | `transactionService->refund()` |

### Error Handling (Italian translations)

```php
$translations = [
    'Invalid credentials' => 'Credenziali SumUp non valide',
    'request_not_allowed' => 'Scope "payments" non attivo. Contatta integration@sumup.com',
    'Checkout expired' => 'Il checkout e\' scaduto. Creane uno nuovo.',
    'Amount too low' => 'Importo troppo basso',
];
```

---

## EMAIL SERVICE

### Laravel (SMTP)

```php
// config/mail.php - SMTP configuration
// .env:
// MAIL_MAILER=smtp
// MAIL_HOST=smtp.gmail.com
// MAIL_PORT=587
// MAIL_USERNAME=email@domain.com
// MAIL_PASSWORD=app_password

// Invio email
use Illuminate\Support\Facades\Mail;

Mail::to($user->email)->send(new BookingConfirmation($booking));

// Mailable class
class BookingConfirmation extends Mailable
{
    public function __construct(public Booking $booking) {}

    public function content(): Content
    {
        return new Content(
            view: 'emails.booking-confirmation',
            with: ['booking' => $this->booking],
        );
    }
}
```

### Node.js (Resend + SMTP Fallback)

```javascript
const { Resend } = require('resend');
const nodemailer = require('nodemailer');

// Invio con fallback
const sendEmail = async ({ to, subject, html }) => {
  try {
    // Try Resend first
    const resend = new Resend(process.env.RESEND_API_KEY);
    await resend.emails.send({ from: 'noreply@domain.com', to, subject, html });
  } catch {
    // Fallback SMTP
    const transport = nodemailer.createTransport({ /* config */ });
    await transport.sendMail({ from: 'noreply@domain.com', to, subject, html });
  }
};
```

---

## GOOGLE APIs (progetti API-first)

### Google Sheets

```javascript
const { google } = require('googleapis');

const auth = new google.auth.GoogleAuth({
  keyFile: '/app/google-service-account.json',
  scopes: ['https://www.googleapis.com/auth/spreadsheets']
});

const sheets = google.sheets({ version: 'v4', auth });

// Lettura
const response = await sheets.spreadsheets.values.get({
  spreadsheetId: SHEET_ID,
  range: 'Sheet1!A1:Z100'
});

// Scrittura
await sheets.spreadsheets.values.update({
  spreadsheetId: SHEET_ID,
  range: 'Sheet1!A2:E100',
  valueInputOption: 'USER_ENTERED',
  resource: { values: [['row1col1', 'row1col2']] }
});
```

### Google Drive

```javascript
const drive = google.drive({ version: 'v3', auth });

// Copia template
const copy = await drive.files.copy({
  fileId: TEMPLATE_ID,
  requestBody: { name: 'New File', parents: [FOLDER_ID] },
  supportsAllDrives: true
});
```

---

## PUSH NOTIFICATIONS

### Firebase Cloud Messaging (Flutter)

```dart
// Setup FCM
import 'package:firebase_messaging/firebase_messaging.dart';

final fcm = FirebaseMessaging.instance;
await fcm.requestPermission();
final token = await fcm.getToken();

// Background handler
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Handle background message
}

FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
```

### Web Push (VAPID - Node.js)

```javascript
const webpush = require('web-push');

webpush.setVapidDetails(
  process.env.VAPID_SUBJECT,
  process.env.VAPID_PUBLIC_KEY,
  process.env.VAPID_PRIVATE_KEY
);

await webpush.sendNotification(subscription, JSON.stringify({
  title: 'Notification Title',
  body: 'Message body',
  icon: '/logo.png'
}));
```

---

## PATTERN COMUNI

### Retry con Backoff

```javascript
const retryWithBackoff = async (fn, maxRetries = 3) => {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      const delay = Math.pow(2, i) * 1000; // 1s, 2s, 4s
      await new Promise(r => setTimeout(r, delay));
    }
  }
};
```

### Webhook Validation

```
1. Verifica firma (Stripe: Stripe-Signature header)
2. Verifica timestamp (evita replay attack)
3. Idempotency (gestisci duplicati)
4. Rispondi 200 velocemente (process async)
5. Log tutti gli eventi
```

---

## ENVIRONMENT VARIABLES

```bash
# Stripe (.env)
STRIPE_KEY=pk_live_...
STRIPE_SECRET=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...

# SumUp (Database Settings, NON .env!)
# sumup_app_id       -> Client ID
# sumup_app_secret   -> Client Secret
# sumup_merchant_code -> Merchant Code
# payment_provider   -> 'stripe' | 'sumup' | 'manual'

# Email - SMTP
MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=...
MAIL_PASSWORD=...

# Email - Resend
RESEND_API_KEY=re_...

# Email - AWS SES
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_DEFAULT_REGION=eu-west-1

# Google
GOOGLE_SERVICE_ACCOUNT_KEY_PATH=/app/google-service-account.json

# Push
VAPID_PUBLIC_KEY=...
VAPID_PRIVATE_KEY=...

# Pusher
PUSHER_APP_ID=...
PUSHER_APP_KEY=...
PUSHER_APP_SECRET=...
```

---

## TELEGRAM BOT API (Assistente AI)

### Setup Bot

```javascript
const TelegramBot = require('node-telegram-bot-api');
const bot = new TelegramBot(process.env.TELEGRAM_BOT_TOKEN, { polling: true });

// Invio messaggio formattato (Markdown)
await bot.sendMessage(chatId, `
*Briefing del ${date}*
📅 Orario: ${schedule}
📝 Verifiche: ${tests}
📋 Circolari: ${circulars}
`, { parse_mode: 'Markdown' });

// Gestione comandi
bot.onText(/\/start/, (msg) => {
    bot.sendMessage(msg.chat.id, 'Benvenuto! Riceverai il briefing ogni mattina.');
});

// CRITICO: Non esporre il token! Sempre in .env
```

### Invio Schedulato (Cron)

```javascript
const cron = require('node-cron');

// Briefing mattutino alle 7:00, lun-sab (skip festivi)
cron.schedule('0 7 * * 1-6', async () => {
    if (await isHoliday(new Date())) return; // Skip festivi
    const briefing = await generateBriefing();
    await bot.sendMessage(TEACHER_CHAT_ID, briefing, { parse_mode: 'Markdown' });
});
```

---

## GEMINI AI INTEGRATION (Assistente AI)

### Setup e Chiamata API

```javascript
const { GoogleGenerativeAI } = require('@google/generative-ai');
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// Gemini 2.5 Flash — cost-effective per daily briefings (~$8/mese)
const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

async function generateBriefing(context) {
    const prompt = `Sei un assistente scolastico. Genera un briefing mattutino conciso basato su:
    - Orario: ${context.schedule}
    - Verifiche programmate: ${context.tests}
    - Circolari: ${context.circulars}
    - Presenze: ${context.attendance}

    Formato: bullet points, max 500 parole, tono professionale.`;

    const result = await model.generateContent(prompt);
    return result.response.text();
}

// CRITICO: Gemini Flash per costi contenuti
// Gemini Pro per task complesse (analisi PDF lunghi)
```

### PDF Content Extraction

```javascript
const pdfParse = require('pdf-parse');

async function extractPdfContent(buffer) {
    const data = await pdfParse(buffer);
    return data.text; // Testo estratto dalla circolare
}
```

---

## CHECKLIST PRE-COMMIT (Integrations)

- [ ] API keys in .env o Database Settings (MAI hardcoded)
- [ ] Error handling con fallback
- [ ] Retry logic per operazioni critiche
- [ ] Webhook: Stripe = signature verification, SumUp = status verification via API
- [ ] Logging di successo e fallimento
- [ ] Amount: Stripe = centesimi (*100), SumUp = euro interi (NO *100!)
- [ ] Idempotency per webhook (check status !== 'paid' prima di aggiornare)
- [ ] SumUp: token cache (50 min) + clear su AuthenticationException
- [ ] Frontend: SumUp SDK caricato async, widget montato dopo DOM ready

---

**Obiettivo**: Integrazioni robuste, error handling completo, fallback automatici.
