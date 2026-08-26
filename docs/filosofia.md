# Filosofia di claude-kb-workflow

> Perché questo toolkit esiste e perché è fatto in questo modo.

---

## Il problema che risolve

Lavorare con un LLM agentico su molti progetti diversi ti scontra costantemente contro questi attriti:

1. **Conoscenza confinata al singolo progetto**: la memoria nativa di Claude Code funziona, ma è per-progetto e per-macchina. Quello che impari sul progetto X non arriva mai al progetto Y, e su una macchina nuova riparti da capo.

2. **Variabilità di qualità**: lo stesso prompt produce risposte di qualità diversa a seconda del contesto, della giornata, della fortuna. Manca un "sistema immunitario" che alzi l'asticella.

3. **Stack diversi → pattern diversi**: ogni stack ha pitfall propri (Laravel ha le route con auth:api, React ha gli effetti che si rieseguono, Flutter ha il parsing API variabile, Docker ha i bind mount che sovrascrivono i permessi...). Tenerli a mente è impossibile.

4. **Conoscenza che evapora**: una lezione dolorosa appresa a marzo viene dimenticata a giugno. Senza un sistema di cattura, l'esperienza non si capitalizza.

---

## I 3 principi guida

### 1. L'esperienza precede il metodo

I framework di sviluppo (TDD strict, Scrum strict, Clean Architecture strict) spesso impongono un metodo astratto che funziona benissimo sulla carta e malissimo nella varietà del lavoro reale.

`claude-kb-workflow` parte dall'opposto: **catturare cosa ha funzionato in produzione** e renderlo riusabile. Il metodo emerge dalla pratica, non viene imposto.

Conseguenza pratica: gli agenti contengono **esempi di codice reale** (sanitizzati) accanto agli antipattern osservati. I pattern in `patterns.md` (e le mie convenzioni in `field-notes-it.md`) sono tutti accompagnati da "sintomo / causa / fix verificato".

### 2. La conoscenza si stratifica

Non tutta la conoscenza ha lo stesso peso. Una nota di sessione sparsa ≠ una decisione architetturale ≠ un pattern critico.

Il toolkit propone una **stratificazione esplicita**:

```
Sessioni reali (caos, sporche)
    ↓ /kb-ingest
LLM Wiki (sintesi viva, mutevole)
    ↓ /kb-promote (criteri rigorosi)
KB stabile (verità autorevole, piccola)
```

Solo ciò che ha **superato la prova del tempo** entra nella KB stabile. Questo evita:
- La proliferazione di "best practices" non verificate
- L'inflazione di regole che nessuno segue più
- Il rumore che soffoca il segnale

### 3. Trigger > regole

Le skill non vengono "applicate" come regole imperative. Si attivano in base a un **trigger** (la `description` del frontmatter) che Claude matcha contro la richiesta utente.

Conseguenza pratica:
- Se una skill ti dà fastidio, **restringi il suo trigger** (modifica la `description`)
- Se una skill non si attiva quando vorresti, **allarga il suo trigger**
- Il sistema è auto-regolabile dall'utente, non imposto dall'autore

Questo è opposto alla filosofia di framework rigidi tipo Superpowers che usano frasi come "ALWAYS find root cause", "NO COMPLETION CLAIMS WITHOUT VERIFICATION". Quelle sono regole imperative. Noi preferiamo trigger contestuali.

---

## Anti-filosofia

Cose che `claude-kb-workflow` **non vuole essere**:

### ❌ Un framework completo

Non è "tutto o niente". Puoi installare solo gli agenti che ti servono. Puoi ignorare il sistema KB-driven se non ti convince. Puoi cancellare le skill che non usi.

### ❌ Una sostituzione del cervello

Gli agenti suggeriscono pattern, non decidono per te. Le decisioni architetturali, di prodotto, di business restano tue. Il toolkit è un **assistente**, non un decisore.

### ❌ Una garanzia di qualità

Se l'utente scrive prompt cattivi, il toolkit non li salva. Se l'utente ignora i suggerimenti degli agenti, il toolkit non lo costringe. Il toolkit **amplifica** ciò che l'utente già fa bene, non corregge cattive abitudini di base.

### ❌ Una collezione di best practice "ufficiali"

Niente qui dentro pretende di essere LA verità. Sono pattern che hanno funzionato per chi ha contribuito al repo. Possono essere sbagliati per il tuo contesto. **Usa il giudizio.**

---

## La forma del repo riflette la filosofia

| Scelta strutturale | Riflesso filosofico |
|--------------------|---------------------|
| Agenti separati per dominio | Specializzazione > generalismo astratto |
| Pattern con sintomo/causa/fix | Esperienza concreta > teoria |
| Skill con trigger descrittivi | Auto-regolazione > regole imposte |
| KB stabile separata da wiki | Stabilizzazione progressiva > collezione indiscriminata |
| Project memories nel progetto (non qui) | Conoscenza specifica resta privata |
| MIT license | Forka e adatta — è il tuo toolkit |

---

## Per chi è questo toolkit

✅ **Sviluppatori che lavorano su molti progetti diversi** — la stratificazione della conoscenza ti capitalizza l'esperienza.

✅ **Solo-dev e piccoli team** — non hai un team che fa code review formali ogni giorno, ma vuoi mantenere disciplina.

✅ **Docenti** — i pattern e gli agenti sono materiale didattico concreto, non teoria astratta.

✅ **Studenti** — esempi reali di come si organizza il lavoro nei team veri.

❌ **Team grandi con processi consolidati** — probabilmente avete già strumenti più sofisticati. Forse pescate idee qua e là, ma non è pensato per voi.

❌ **Chi vuole un metodo "chiavi in mano" che gli dica esattamente cosa fare in ogni momento** — questo è Superpowers, non noi.

---

## Stato e maturità

Il toolkit è in **versione 0.1**. Significa:

- I pattern sono testati da anni di lavoro reale, ma in pochi contesti (mio)
- Le skill metodologiche sono adattate da Superpowers (collaudato in inglese) ma ancora non massivamente provate in italiano
- Il sistema KB-driven è funzionante ma ha visto poca diffusione

**Per questo stiamo facendo testing con colleghi e studenti prima della pubblicazione pubblica.**

Il feedback della community è ciò che farà passare il toolkit da 0.1 a 1.0.

---

## Ispirazioni

- **[obra/superpowers](https://github.com/obra/superpowers)** — l'idea che le skill metodologiche siano un cittadino di prima classe del workflow agentico
- **Andrej Karpathy** — riflessioni pubbliche su come catturare conoscenza in sistemi LLM (raw → compiled → stable)
- **Pragmatic Programmer** (Hunt/Thomas) — la disciplina dell'evidenza, della verifica, del catturare "ricette" da esperienza reale
- **Anni di bug in produzione** — il vero compilatore di questo repo
