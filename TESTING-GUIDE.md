# Guida al Test di claude-kb-workflow

> Questa guida è pensata per **colleghi e studenti** che vogliono provare il toolkit nei propri progetti e fornire feedback prima della pubblicazione pubblica.
>
> Tempo richiesto: **30-45 minuti per il primo test completo**, poi uso quotidiano per qualche giorno.

---

## 🎯 Cosa stiamo testando

Vogliamo capire se il toolkit:

1. **Si installa senza intoppi** su Windows / macOS / Linux
2. **Si attiva nei momenti giusti** (gli agenti e le skill vengono triggerati quando servono)
3. **Non disturba** quando il task è banale (no falsi positivi)
4. **Dà valore reale** rispetto a Claude Code "vanilla" senza toolkit

---

## ✅ Prerequisiti

Prima di iniziare, verifica di avere:

- [ ] **Claude Code installato** ([download](https://claude.com/claude-code))
- [ ] **Git** funzionante (`git --version` da terminale)
- [ ] **Bash** disponibile (Linux/macOS nativo; Windows: Git Bash o WSL)
- [ ] Un **progetto reale tuo** dove fare test (anche piccolo va bene)
- [ ] Almeno 30 minuti senza interruzioni per il primo giro

---

## 📦 Step 1 — Installazione (5 minuti)

### Clona il repo

```bash
# Su Linux/macOS o Git Bash su Windows
git clone https://github.com/thomascasali/claude-kb-workflow.git
cd claude-kb-workflow
```

### Esegui l'installer

```bash
./scripts/install.sh
```

Lo script ti chiederà conferma e copierà:
- 12 agenti in `~/.claude/agents/`
- Pattern in `~/.claude/patterns/`
- Workflow in `~/.claude/workflows/`
- 6 skill in `~/.claude/skills/`
- 5 comandi `/kb-*` in `~/.claude/commands/`

### Riavvia Claude Code

**IMPORTANTE**: chiudi e riapri Claude Code per caricare le nuove configurazioni.

### Verifica installazione

In una sessione nuova di Claude Code:

```
Mostrami il decision tree degli agenti
```

Se vedi una tabella con `backend-dev`, `frontend-dev`, ecc. → **installazione OK**.

Se Claude non sa cosa rispondere → riavvia Claude Code e riprova.

---

## 🧪 Step 2 — Test trigger rapido (10 minuti)

Apri una **sessione nuova** di Claude Code nel tuo progetto. Lancia uno alla volta questi prompt e annota se la skill/agente atteso si attiva.

### Test 1: agente backend

```
Devo aggiungere un endpoint POST /api/users al mio backend. Procedi.
```

**Atteso**: Claude consulta `agents/backend-dev.md` e applica i pattern (validation, auth check, return JSON, ecc.) — non si limita a generare codice generico.

✅ Si attiva? ☐ Sì ☐ No

---

### Test 2: skill debugging-sistematico

```
Ho un bug: dopo l'ultimo deploy il login non funziona, l'utente riceve sempre 401. Aiutami.
```

**Atteso**: Claude **chiede prove** (log, riproduzione, commit recenti) prima di proporre fix. Non va dritto a "prova a fare X".

✅ Si attiva? ☐ Sì ☐ No

---

### Test 3: skill verifica-prima-di-completare

```
Ho appena finito di sistemare il login. Confermami che è pronto per il deploy.
```

**Atteso**: Claude **esegue test/build/curl** prima di dichiarare "pronto". Non scrive "dovrebbe funzionare".

✅ Si attiva? ☐ Sì ☐ No

---

### Test 4: skill brainstorming-design

```
Voglio aggiungere notifiche push al mio progetto. Come procediamo?
```

**Atteso**: Claude pone 2-3 domande mirate prima di scrivere codice (target piattaforma, librerie esistenti, tipo notifiche). Non parte subito a implementare.

✅ Si attiva? ☐ Sì ☐ No

---

### Test 5: anti-trigger (deve NON attivarsi)

```
Rinomina la funzione getUser in fetchUser nel file src/api/users.js
```

**Atteso**: Claude **rinomina direttamente**. NON deve attivare `brainstorming-design` (è un edit puntuale già specificato).

❌ Si attiva qualcosa che non dovrebbe? ☐ Sì (problema) ☐ No (OK)

---

## 🚀 Step 3 — Test su scenario reale (15-30 minuti)

Scegli **un task reale** del tuo progetto. Idealmente uno di questi tipi:

### Scenario tipo A: Bug fix

Trovati un bug nel tuo progetto e chiedi a Claude:

> "Su [mio progetto] osservo [sintomo]. Investiga la causa radice."

**Cosa osservare**:
- ✅ Claude legge i commit recenti, riproduce il bug, identifica la causa prima di proporre fix
- ✅ Se hai un `CLAUDE.md` o `MEMORY.md`, lo legge automaticamente
- ❌ Va dritto a un fix generico senza diagnosi → segnala come problema

---

### Scenario tipo B: Nuova feature

Pensa a una feature che vorresti aggiungere e chiedi:

> "Voglio aggiungere [feature] al mio progetto. Come procediamo?"

**Cosa osservare**:
- ✅ Pone 2-3 domande mirate (non a raffica, non troppo poche)
- ✅ Propone 2-3 approcci con trade-off
- ✅ Aspetta approvazione esplicita prima di scrivere codice
- ❌ Inizia subito a generare codice senza chiedere → segnala come problema

---

### Scenario tipo C: Deploy / verifica

Dopo aver fatto modifiche, chiedi:

> "Ho finito le modifiche. È tutto pronto per il deploy?"

**Cosa osservare**:
- ✅ Esegue verifiche reali (test, build, curl, lint) prima di rispondere
- ✅ Mostra l'output dei comandi
- ❌ Risponde "dovrebbe funzionare" senza prove → segnala come problema

---

## 📝 Step 4 — Raccolta feedback

Dopo 3-5 sessioni di uso reale, compila questo modulo e invialo (via GitHub Discussion, email, o messaggio).

### Modulo feedback

**Nome (facoltativo)**: _________________________
**Ruolo (studente / dev / docente / altro)**: _________________________
**OS usato**: ☐ Windows ☐ macOS ☐ Linux
**Tipo di progetto testato**: _________________________

---

#### Installazione

- È andata liscia? ☐ Sì ☐ No
- Se no, dove si è incagliata? ___________________________

#### Trigger

Per ognuna delle skill/agenti testati:

| Componente | Si attiva quando serve? (1-5) | Falsi positivi? | Note |
|------------|-------------------------------|-----------------|------|
| `backend-dev` (o stack tuo) | | | |
| `debugging-sistematico` | | | |
| `verifica-prima-di-completare` | | | |
| `brainstorming-design` | | | |
| `deploy-production` (se applicabile) | | | |

#### Valore aggiunto

- C'è stato un momento in cui il toolkit ti ha **evitato un errore reale**? Quale?
- C'è stato un momento in cui il toolkit ti **ha dato fastidio** invece di aiutarti? Quale?
- Lo useresti **quotidianamente** dopo questo test?
  - ☐ Sì, sicuramente
  - ☐ Sì, con qualche aggiustamento
  - ☐ Forse, dipende
  - ☐ No, non lo trovo utile per il mio workflow

#### Suggerimenti

- Cosa **manca** che vorresti vedere aggiunto?
- Cosa **toglieresti** perché ridondante o fastidioso?
- Quale parte è **più utile** in assoluto?
- Quale parte è **più confusa** o difficile da usare?

#### Confronto

- Avevi mai usato [Superpowers](https://github.com/obra/superpowers) o framework simili? ☐ Sì ☐ No
- Se sì, come si confronta? ___________________________

---

## 🆘 Hai problemi?

### "Le skill non si attivano"

1. Verifica che `~/.claude/skills/<nome>/SKILL.md` esista e abbia il frontmatter
2. Riavvia Claude Code
3. Apri una sessione nuova (non riusare una vecchia, il contesto influenza i trigger)

### "L'installazione fallisce su Windows"

- Usa **Git Bash**, non CMD o PowerShell nativi
- Verifica che `bash` sia nel PATH: `which bash`
- In alternativa: copia manualmente le cartelle con Esplora File

### "Una skill si attiva quando non dovrebbe"

Questo è il feedback più utile! Apri una Issue su GitHub con:
- Prompt esatto che ha causato il falso positivo
- Nome della skill
- Cosa ti aspettavi invece

### "Non capisco la differenza tra agenti e skill"

- **Agente** = specialista di dominio (es. `backend-dev` per Laravel/Node)
- **Skill** = metodologia o competenza riusabile (es. `debugging-sistematico`)
- Agenti hai 10, skill ne hai 6 — gli agenti sono "chi", le skill sono "come"

### "Il sistema KB-driven non lo capisco"

È opzionale! Per ora ignoralo. Quando hai voglia, leggi [docs/workflow-kb-driven.md](docs/workflow-kb-driven.md) e prova `/kb-ingest nome-progetto`.

---

## 🎓 Per studenti: cosa imparare dal toolkit

Se sei studente (o stai imparando lo sviluppo software), questo toolkit ti offre 4 cose oltre alla pura utility:

1. **Pattern reali di produzione**: i 30 pattern in `patterns/critical-patterns.md` sono bug che hanno fatto perdere ore di lavoro a sviluppatori veri. Leggerli ti vaccina.

2. **Esempi di codice ben strutturato**: ogni agente ha pattern e antipattern con esempi. Ottimo materiale di studio.

3. **Workflow professionali**: i `workflows/common-tasks.md` mostrano come si organizza il lavoro nei team veri (decision tree, checklist, sequenze).

4. **Metodologia**: le 3 skill metodologiche (`debugging-sistematico`, `verifica-prima-di-completare`, `brainstorming-design`) sono **soft skill di senior** distillate in regole pratiche.

**Consiglio**: leggi prima l'agente del tuo stack principale + i pattern critici, poi prova a usare il toolkit su un progetto scolastico.

---

## 🙏 Grazie

Il tuo feedback è prezioso. Pochi giorni di uso reale da parte tua valgono più di mesi di sviluppo astratto da parte mia.

Se hai dubbi, scrivi senza esitazione.
