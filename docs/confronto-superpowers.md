# claude-kb-workflow nel panorama 2026 (Superpowers, GSD, gstack)

> 🇬🇧 English version: [docs/comparison-2026.md](comparison-2026.md)

> Una valutazione franca dei diversi approcci, scritta da chi ha **adottato e adattato** parti di Superpowers in `claude-kb-workflow`. Aggiornato: **agosto 2026**.

---

## Il panorama 2026 in breve

Nel 2026 gli "skills framework" per Claude Code sono diventati una categoria mainstream.
Tre nomi dominano la conversazione — la sintesi della community: **"gstack pensa, GSD
stabilizza, Superpowers esegue"**:

- **[Superpowers](https://github.com/obra/superpowers)** (~265k ⭐, sviluppo attivissimo) — IL framework metodologico: TDD-strict, plan-driven, guardrail forti. Se scrivi codice professionalmente, è il punto di partenza della categoria.
- **GSD** — orientato alla stabilizzazione del workflow.
- **gstack** — orientato al thinking/multi-prodotto (solo founder con più prodotti).

In parallelo, le **raccolte di agenti si sono commoditizzate**: esistono toolkit con 100-135
agenti pronti. Competere sulla quantità di agenti non ha più senso per nessuno.

**Dove si colloca `claude-kb-workflow`**: in un'altra categoria — il **sistema di memoria**.
Gli skills framework ti dicono *come eseguire* una sessione; questo repo si occupa di *cosa
resta* dopo la sessione: la pipeline wiki→KB (pattern Karpathy, diventato virale ad aprile
2026 — la nostra implementazione gira da quello stesso mese su 15+ progetti reali), i pattern
pagati in produzione, il disaster recovery della conoscenza. **Si installano insieme senza
conflitti: loro il metodo di esecuzione, noi il sistema di memoria.**

---

## TL;DR

| | Superpowers | claude-kb-workflow |
|---|-------------|---------------------|
| **Cos'è** | Framework metodologico | Sistema di memoria: KB + wiki + agenti + pattern |
| **Filosofia** | Imponi un workflow disciplinato | Cattura esperienza e rendila riusabile |
| **Direzione** | Top-down (regole → pratica) | Bottom-up (pratica → regole) |
| **Si occupa di** | Come esegui LA sessione | Cosa resta DOPO la sessione |
| **Target ideale** | Team SaaS con disciplina debole | Solo-dev e piccoli team multi-progetto |
| **Lingua** | English-only | Inglese porta d'ingresso, italiano nativo |

**Non sono concorrenti** — sono complementari per costruzione. Le 3 skill metodologiche in `claude-kb-workflow` sono **adattamenti italianizzati e ammorbiditi** da Superpowers.

> ⚠️ Nota di freschezza: le sezioni di dettaglio qui sotto fotografano Superpowers a
> **maggio 2026** (14 skill). Il progetto evolve rapidamente: verifica sul repo ufficiale
> prima di citare numeri. La filosofia del confronto resta valida.

---

## Cos'è Superpowers

[Superpowers](https://github.com/obra/superpowers) è un **framework di sviluppo agentico** creato da Jesse Vincent. Impone un workflow strutturato a fasi:

```
brainstorming → writing-plans → executing-plans → test-driven-development
→ systematic-debugging → verification-before-completion
→ requesting/receiving-code-review → using-git-worktrees
→ finishing-a-development-branch
```

14 skill totali, con meta-skill `writing-skills`, `using-superpowers`, `subagent-driven-development`, `dispatching-parallel-agents`.

### Punti di forza di Superpowers

✅ **Disciplina**: forza l'agente a non saltare passi (no fix senza root cause, no completion senza verifica)
✅ **Coerenza**: il workflow è sempre lo stesso, prevedibile
✅ **Riduzione errori**: i guardrail forti riducono drasticamente "ho dichiarato fatto ma non funziona"
✅ **TDD-first**: dove TDD è applicabile, garantisce test coverage
✅ **Adatto a team**: la struttura uniforma facilita la collaborazione

### Punti deboli di Superpowers

❌ **Rigidità**: applicare TDD + planning + review formale anche a task da 5 minuti è overhead
❌ **Filosofia "ALWAYS/NEVER"**: regole imperative ("ALWAYS find root cause", "NO COMPLETION CLAIMS WITHOUT VERIFICATION") generano frustrazione su casi edge
❌ **Lingua**: solo inglese
❌ **Stack-agnostic ma quasi**: pensato implicitamente per progetti SaaS con CI/CD maturo, meno adatto a didattica / IoT / scripting
❌ **Onboarding pesante**: 14 skill da assimilare, meta-skill che si auto-referenziano

---

## Cos'è claude-kb-workflow

`claude-kb-workflow` parte da una premessa opposta: **non un framework, ma una memoria condivisa**.

```
12 subagent (2 orchestratori + 10 specialisti) (cosa fare per stack)
+ 30 pattern critici (cosa evitare, da esperienza reale)
+ 6 skill metodologiche (come ragionare, leggermente)
+ Sistema KB-driven (come accumulare conoscenza nel tempo)
```

### Punti di forza di claude-kb-workflow

✅ **Pattern reali**: ogni pattern viene da bug effettivi in produzione, non da teoria
✅ **Stratificazione**: separazione esplicita tra conoscenza fresca (wiki) e conoscenza autorevole (KB)
✅ **Multi-stack**: supporto esplicito a Laravel, Node, Vue, React, Flutter, Docker, MySQL/Mongo/PostgreSQL, IoT
✅ **Italiano**: pensato per la community italiana, accessibile a studenti ITIS
✅ **Modulare**: installi solo le parti che ti servono
✅ **Auto-regolabile**: trigger descrittivi che l'utente può raffinare

### Punti deboli di claude-kb-workflow

❌ **Meno disciplinato**: i trigger contestuali sono più morbidi delle regole imperative — un'agente "sciatto" può ignorarli
❌ **Più maturità richiesta**: l'utente deve sapere quando applicare un pattern e quando no
❌ **Setup KB-driven complesso**: il sistema a 3 livelli (sessione → wiki → KB) richiede investimento iniziale
❌ **Progetto giovane**: molti meno utenti e contesti rispetto a Superpowers
❌ **Niente integrazione con plugin marketplace ufficiale** (per ora)

---

## Come si confrontano sulle 3 skill condivise

In `claude-kb-workflow` sono presenti 3 skill metodologiche **derivate da Superpowers** ma adattate. Vediamole una per una.

### `systematic-debugging` (Superpowers) vs `debugging-sistematico` (kb-workflow)

| | Superpowers | kb-workflow |
|---|-------------|-------------|
| **Lingua** | Inglese | Italiano |
| **Tono** | "NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST" (imperativo) | "I fix sui sintomi falliscono" (principio + esempi) |
| **Trigger** | Generico | Esplicito quando attivare E quando NON attivare |
| **Casi specifici** | No | Sì (Laravel, Node, Flutter, Docker) |
| **Stop rule** | Identica (3 fix falliti → ferma) | Identica |

### `verification-before-completion` (Superpowers) vs `verifica-prima-di-completare` (kb-workflow)

| | Superpowers | kb-workflow |
|---|-------------|-------------|
| **Lingua** | Inglese | Italiano |
| **Tono** | "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE" | "L'evidenza precede la dichiarazione di fatto" |
| **Eccezioni** | Non esplicite | Esplicite (esplorazione, sola ricerca) |
| **Casi specifici** | Generici | Per stack (Laravel test, Flutter analyze, Docker compose config, browser load) |

### `brainstorming` (Superpowers) vs `brainstorming-design` (kb-workflow)

| | Superpowers | kb-workflow |
|---|-------------|-------------|
| **Lingua** | Inglese | Italiano |
| **Quando attivarla** | "Anche progetti semplici beneficiano" | Esplicitamente NON per edit puntuali, fix banali, istruzioni esplicite |
| **Numero domande** | Una alla volta, sequenziale, lunga | 2-3 mirate, no raffica |
| **Approcci proposti** | Generico | 2-3 con trade-off espliciti |
| **Caso "presentazioni didattiche"** | Non esiste | Caso specifico documentato |

**Insight**: la principale differenza pratica è che le versioni adattate sono **meno aggressive sui trigger**. Sono pensate per attivarsi quando servono davvero, non a ogni richiesta.

---

## Cosa Superpowers ha che claude-kb-workflow non ha

| Feature Superpowers | Stato in kb-workflow |
|---------------------|-----------------------|
| `test-driven-development` | Non presente come skill dedicata — principio incluso in `debugging-sistematico` |
| `writing-plans` / `executing-plans` | Non presenti — sostituiti da agent `Plan` nativo + `planning-with-files` community |
| `using-git-worktrees` | Non presente — Claude Code lo supporta nativamente |
| `subagent-driven-development` | Non presente — sostituito da agenti tematici + `Agent` nativo |
| `dispatching-parallel-agents` | Non presente — `Agent` nativo permette parallelismo |
| `requesting-code-review` / `receiving-code-review` | Sostituiti da agente `reviewer` + `/review` / `/ultrareview` nativi |
| `finishing-a-development-branch` | Non presente — workflow git generico |
| `writing-skills` | Sostituito da `anthropic-skills:skill-creator` ufficiale |
| `using-superpowers` (meta) | Inutile senza il framework completo |

In sostanza: 9 skill su 14 di Superpowers sono **duplicate da funzionalità native di Claude Code** o coperte da altri toolkit. Per questo `claude-kb-workflow` non le include.

---

## Cosa claude-kb-workflow ha che Superpowers non ha

| Feature kb-workflow | Stato in Superpowers |
|---------------------|----------------------|
| **12 subagent (2 orchestratori + 10 specialisti) per stack specifici** | Non presenti — Superpowers è stack-agnostic |
| **30 pattern critici da produzione reale** | Non presenti |
| **`deploy-production-skill`** (Docker+Traefik) | Non presente |
| **`flutter-production-skill`** (Firebase, streaming, push) | Non presente |
| **`educational-presentation-skill`** (slide didattiche) | Non presente |
| **Sistema KB-driven a 3 livelli** | Non presente |
| **5 comandi `/kb-*`** | Non presenti |
| **Template project memory** | Non presente |
| **Documentazione in italiano** | Non presente |

In sostanza: kb-workflow è **più completo sul lato "knowledge"** e **meno completo sul lato "metodologia"**.

---

## Possono coesistere?

**Sì, e in `claude-kb-workflow` lo dimostriamo**:

1. Le 3 skill metodologiche di Superpowers (adattate) sono incluse
2. Le altre 11 skill di Superpowers possono essere installate manualmente accanto
3. Il sistema KB-driven non entra in conflitto con il workflow Superpowers — semmai lo arricchisce
4. Gli agenti per stack sono **complementari** alle skill metodologiche di Superpowers

Scenario realistico:
```
Sviluppatore Laravel + Vue + Flutter
├── claude-kb-workflow (questo repo) → installa agenti + pattern + KB-driven
├── Superpowers (opzionale) → installa skill metodologiche aggiuntive (TDD, plans, ecc.)
└── Anthropic skills (ufficiali) → pptx, docx, xlsx, pdf
```

---

## Quale scegliere?

### Scegli Superpowers se:
- Lavori principalmente in inglese
- Vuoi un framework completo "chiavi in mano"
- Apprezzi la disciplina rigida (TDD strict, plan-driven)
- Il tuo stack è generico (SaaS web, niente IoT/didattica/embedded)
- Hai un team che vuole uniformità

### Scegli claude-kb-workflow se:
- Vuoi documentazione e pattern in italiano
- Lavori su molti progetti con stack diversi
- Preferisci accumulare conoscenza nel tempo (KB-driven)
- Hai pattern di produzione reali da catturare
- Vuoi un toolkit modulare (installa solo cosa ti serve)

### Scegli entrambi se (è il caso più comune):
- Vuoi il meglio dei due mondi: **un framework di esecuzione + un sistema di memoria**
- Il tuo problema non è "come lavora l'agente in sessione" ma "perché rifaccio gli
  stessi errori di tre mesi fa" → quella parte nessuno degli skills framework la copre
- Hai tempo di apprendere 2 sistemi (l'onboarding di kb-workflow è più leggero: si
  parte con gli agenti + pattern, la pipeline wiki→KB si aggiunge quando serve)

---

## Riconoscimenti

Grazie a Jesse Vincent ([@obra](https://github.com/obra)) per aver pubblicato Superpowers sotto licenza MIT. Le 3 skill in questo repo (`debugging-sistematico`, `verifica-prima-di-completare`, `brainstorming-design`) sono adattamenti delle sue (`systematic-debugging`, `verification-before-completion`, `brainstorming`) — il merito delle idee è suo, l'adattamento (e gli eventuali peggioramenti) sono di chi ha scritto questo repo.
