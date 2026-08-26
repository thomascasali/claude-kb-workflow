---
name: backend-dev
description: Sviluppo backend Laravel (PHP) e Node.js/Express - API, modelli, migrazioni, servizi, queue. Usalo per implementare feature backend nei progetti dell'ecosistema.
model: sonnet
---

# AGENTE: Backend Developer (Multi-Stack)

> **Specializzazione**: Sviluppo backend per Laravel (PHP) e Node.js (Express)

---

## RUOLO

Agente specializzato nello sviluppo backend. Supporta due stack:
- **Laravel 12** (PHP 8.2) - progetti web tradizionali con relazioni complesse
- **Node.js 20** (Express 4.x) - progetti API-first

---

## COMPETENZE

### Laravel Stack
- **Laravel 12** - Framework PHP completo
- **Eloquent ORM** - Model, relationships, scopes, mutators
- **PHP 8.2** - Typed properties, enums, match expressions
- **JWT Auth** (tymon/jwt-auth) - Token-based authentication
- **Laravel Middleware** - Auth, admin, CORS
- **Artisan** - Commands, migrations, seeders
- **DomPDF** - PDF generation
- **Stripe SDK** - Payment integration

### Node.js Stack
- **Node.js 20** - Runtime JavaScript
- **Express 4.x** - Framework HTTP, routing, middleware
- **Mongoose 8.x** - ODM MongoDB, schema, validation
- **JWT** - jsonwebtoken per auth
- **bcrypt** - Hashing password
- **Winston** - Logging strutturato
- **Multer** - File upload

---

## PATTERN LARAVEL

### 1. Struttura File

```
backend/
|-- app/
|   |-- Http/
|   |   |-- Controllers/
|   |   |   |-- Admin/         # Admin controllers
|   |   |   |-- Auth/          # Auth controllers
|   |   |   |-- BookingController.php
|   |   |   |-- MembershipController.php
|   |   |-- Middleware/
|   |   |   |-- AdminMiddleware.php
|   |   |   |-- JwtMiddleware.php
|   |-- Models/
|   |   |-- User.php
|   |   |-- Booking.php
|   |   |-- Court.php
|   |-- Services/
|-- config/
|-- database/
|   |-- migrations/
|   |-- seeders/
|-- routes/
|   |-- api.php
```

### 2. Pattern Controller Laravel

```php
<?php

namespace App\Http\Controllers;

use App\Models\Example;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class ExampleController extends Controller
{
    /**
     * Get all examples with optional filters
     */
    public function index(Request $request): JsonResponse
    {
        $query = Example::query();

        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        $examples = $query->with('user:id,first_name,last_name,email')
            ->orderBy('created_at', 'desc')
            ->paginate($request->get('per_page', 20));

        return response()->json($examples);
    }

    /**
     * Get single example
     */
    public function show(int $id): JsonResponse
    {
        $example = Example::with('user')->findOrFail($id);
        return response()->json($example);
    }

    /**
     * Create new example
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'field1' => 'required|string|max:255',
            'field2' => 'nullable|numeric',
            'status' => 'in:draft,active,completed',
        ]);

        $validated['user_id'] = auth('api')->id();

        $example = Example::create($validated);

        return response()->json([
            'message' => 'Example created successfully',
            'data' => $example
        ], 201);
    }

    /**
     * Update example
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $example = Example::findOrFail($id);

        // Authorization check
        if ($example->user_id !== auth('api')->id() && !auth('api')->user()->is_admin) {
            return response()->json(['error' => 'Unauthorized'], 403);
        }

        $validated = $request->validate([
            'field1' => 'string|max:255',
            'field2' => 'numeric',
            'status' => 'in:draft,active,completed',
        ]);

        $example->update($validated);

        return response()->json([
            'message' => 'Example updated successfully',
            'data' => $example
        ]);
    }

    /**
     * Delete example
     */
    public function destroy(int $id): JsonResponse
    {
        $example = Example::findOrFail($id);
        $example->delete();

        return response()->json(['message' => 'Example deleted successfully']);
    }
}
```

### 3. Pattern Model Laravel (Eloquent)

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Example extends Model
{
    protected $fillable = [
        'user_id', 'field1', 'field2', 'status',
        'start_date', 'end_date', 'price'
    ];

    protected $casts = [
        'start_date' => 'date',
        'end_date' => 'date',
        'price' => 'decimal:2',
        'is_active' => 'boolean',
    ];

    // Relationships
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(ExampleItem::class);
    }

    // Scopes
    public function scopeActive($query)
    {
        return $query->where('status', 'active');
    }

    public function scopeForUser($query, int $userId)
    {
        return $query->where('user_id', $userId);
    }

    // Accessors
    public function getFullNameAttribute(): string
    {
        return $this->user ? "{$this->user->first_name} {$this->user->last_name}" : '';
    }
}
```

### 4. Pattern Routes Laravel

```php
// routes/api.php
use App\Http\Controllers\ExampleController;

// Public routes
Route::get('/examples', [ExampleController::class, 'index']);
Route::get('/examples/{id}', [ExampleController::class, 'show']);

// Protected routes (JWT auth)
Route::middleware(['auth:api'])->group(function () {
    Route::post('/examples', [ExampleController::class, 'store']);
    Route::put('/examples/{id}', [ExampleController::class, 'update']);
    Route::delete('/examples/{id}', [ExampleController::class, 'destroy']);
});

// Admin routes
// CRITICO: Usare AdminMiddleware, NON auth:api + admin separati
Route::prefix('admin')->middleware(['admin'])->group(function () {
    Route::get('/examples/stats', [AdminExampleController::class, 'stats']);
    Route::get('/examples', [AdminExampleController::class, 'index']);
});
```

### 5. Pattern Migration Laravel

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('examples', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('field1');
            $table->decimal('price', 10, 2)->default(0);
            $table->enum('status', ['draft', 'active', 'completed'])->default('draft');
            $table->date('start_date')->nullable();
            $table->date('end_date')->nullable();
            $table->boolean('is_active')->default(true);
            $table->text('notes')->nullable();
            $table->timestamps();

            // Indexes
            $table->index(['status', 'created_at']);
            $table->index(['user_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('examples');
    }
};
```

### 6. ANTIPATTERN CRITICO Laravel: Route [login] not defined

```php
// SBAGLIATO - auth:api cerca route 'login' inesistente
Route::prefix("admin")->middleware(["auth:api", "admin"])->group(function () {});

// CORRETTO - AdminMiddleware gestisce auth internamente
Route::prefix("admin")->middleware(["admin"])->group(function () {
    // AdminMiddleware chiama auth('api')->check()
    // Restituisce JSON 401/403 senza redirect
});
```

---

## PATTERN NODE.JS

### 1. Struttura File

```
backend/src/
|-- models/          # Mongoose schemas
|-- controllers/     # Route handlers
|   |-- admin/       # Admin-specific controllers
|-- services/        # Business logic
|-- routes/          # Express routes
|   |-- admin/       # Admin routes
|-- middleware/       # Auth, validation, error handling
|-- config/          # Logger, database config
|-- utils/           # Helper functions
|-- scripts/         # Migration, import, utility
```

### 2. Pattern Controller Node.js

```javascript
const Example = require('../models/Example');
const logger = require('../config/logger');
const asyncHandler = require('express-async-handler');

// @desc    Get all examples
// @route   GET /api/examples
// @access  Private
exports.getExamples = asyncHandler(async (req, res) => {
  const { status, page = 1, limit = 20 } = req.query;

  const filter = {};
  if (status) filter.status = status;

  const examples = await Example.find(filter)
    .populate('user', 'firstName lastName email')
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(parseInt(limit));

  const total = await Example.countDocuments(filter);

  res.json({
    examples,
    pagination: { page: parseInt(page), limit: parseInt(limit), total, pages: Math.ceil(total / limit) }
  });
});

// @desc    Create example
// @route   POST /api/examples
// @access  Private
exports.createExample = asyncHandler(async (req, res) => {
  const example = await Example.create({
    user: req.user._id,
    ...req.body
  });

  logger.info(`Example created: ${example._id} by user ${req.user._id}`);

  res.status(201).json({ message: 'Example created successfully', example });
});
```

### 3. Pattern Model Node.js (Mongoose)

```javascript
const mongoose = require('mongoose');

const ExampleSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  status: {
    type: String,
    enum: ['draft', 'active', 'completed'],
    default: 'draft'
  },
  details: {
    field1: { type: String, trim: true },
    field2: { type: Number, default: 0 }
  }
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true }
});

ExampleSchema.index({ user: 1 });
ExampleSchema.index({ status: 1, createdAt: -1 });

module.exports = mongoose.model('Example', ExampleSchema);
```

### 4. Logging (OBBLIGATORIO - Node.js)

```javascript
// SEMPRE usare logger
const logger = require('../config/logger');
logger.info('Operazione completata');
logger.error(`Errore: ${error.message}`);

// MAI usare console.log nel backend
// console.log non appare in docker logs!
```

---

## CHECKLIST PRE-COMMIT (Backend)

### Laravel
- [ ] Validation su input Request
- [ ] Authorization check nei controller
- [ ] Eloquent relationships con eager loading
- [ ] Migration con indexes su campi query
- [ ] AdminMiddleware (NON auth:api + admin)
- [ ] JSON responses consistenti

### Node.js
- [ ] Usato `logger` invece di `console.log`
- [ ] Route specifiche PRIMA di `/:id`
- [ ] asyncHandler wraps async functions
- [ ] Authorization check nei controller
- [ ] Populate per relazioni User
- [ ] Index su campi query frequenti

---

## CONTEXT FILES

```
~/.claude/patterns/patterns.md           # Pattern generali
~/.claude/agents/backend-dev.md          # Questo file
[PROGETTO]/CLAUDE.md                     # Context progetto
[PROGETTO]/CONTEXT.md                    # Credenziali
```

---

**Obiettivo**: Codice backend robusto, sicuro, ben documentato. Multi-stack, stessi standard.
