# Contribuire a claude-kb-workflow

Grazie per il tuo interesse! Questo progetto cresce con i contributi della community.

> Lingua dei contributi: **italiano o inglese**. La documentazione è bilingue: inglese come porta d'ingresso, italiano nativo. Le traduzioni EN di agenti/skill sono il contributo più gradito.

---

## Tipi di contributo

### 🤖 Nuovo agente

Un agente è uno specialista di dominio. Aggiungi un agente quando esiste un **dominio tecnico** non coperto dai 10 esistenti.

Esempi validi: `data-engineer` (Spark/Airflow/DBT), `ml-engineer` (PyTorch/HuggingFace), `embedded-dev` (ESP32/STM32/Arduino), `blockchain-dev`.

Esempi NON validi: "agente per progetto X specifico" (quello va nel `CLAUDE.md` del tuo progetto, non qui).

**Template**: vedi `agents/README-AGENTI.md` sezione "Estendere il sistema".

**Checklist PR**:
- [ ] File `agents/<nome>.md` con sezioni: RUOLO, COMPETENZE, PATTERN, ANTIPATTERN, CHECKLIST PRE-COMMIT, CONTEXT FILES
- [ ] Aggiunto al `agents/README-AGENTI.md` (tabella + decision tree)
- [ ] Almeno 3 pattern e 2 antipattern con esempi di codice reali
- [ ] Nessun riferimento a clienti/progetti specifici

---

### 🧠 Nuova skill

Una skill è una **metodologia o competenza riusabile** che Claude attiva via trigger.

Esempi: `code-review-pre-pr`, `refactor-with-tests`, `security-audit-quick`.

**Checklist PR**:
- [ ] Cartella `skills/<nome>/SKILL.md` con frontmatter (`name`, `description`)
- [ ] La `description` ha trigger positivi E negativi (cosa attiva / cosa NON attiva)
- [ ] La skill è autocontenuta (non dipende da skill non standard)
- [ ] (Opzionale) Cartella `references/` per pattern aggiuntivi

**Esempio di frontmatter ben tarato**:
```yaml
---
name: nome-skill
description: Frase imperativa che descrive quando attivare. Da usare quando l'utente fa X, Y, Z. NON da usare per task A, B.
---
```

---

### 📐 Nuovo pattern

Un pattern è un **lesson learned da produzione**. Se regge fuori dal mio setup specifico va in `patterns/patterns.md`; se è una convenzione personale (script di deploy, naming env, provider VPS) va in `patterns/field-notes-it.md`.

**Criteri di accettazione**:
- ✅ Hai osservato il pattern in **almeno 2 progetti diversi**, oppure è un gotcha già pagato che costerebbe almeno 1 ora a chi lo reincontra
- ✅ Hai esempio di codice **prima/dopo** (sbagliato/corretto)
- ✅ Hai una **causa radice spiegata** (non solo "fai così")
- ❌ Non è già coperto da pattern esistenti

**Formato**:
```markdown
## N. Nome Pattern (CRITICAL - quando applica)

**Sintomo**: ...

**Causa**: ...

\`\`\`language
// SBAGLIATO
codice_problematico

// CORRETTO
codice_giusto
\`\`\`

**Diagnosi**: come accorgersi del problema

**Riferimento**: stack o scenario in cui emerge
```

---

### 📜 Nuovo workflow

Un workflow è una **sequenza ordinata di passi** per un task ricorrente. Vai in `workflows/common-tasks.md`.

Esempi: "Setup nuovo microservizio", "Migrazione DB con zero downtime", "Onboarding nuovo dev".

---

### 🐛 Bug nei trigger / falsi positivi

Hai notato che una skill si attiva su task dove non dovrebbe (o viceversa)?

**Apri una Issue** con:
- Nome skill o agente
- Prompt esatto che ha causato il comportamento sbagliato
- Comportamento atteso
- (Opzionale) Proposta di fix alla `description`

---

## Processo PR

1. **Fork** del repo
2. **Branch** descrittivo: `feat/agent-data-engineer`, `fix/skill-debugging-trigger`, `pattern/cors-preflight`
3. **Implementa** seguendo la checklist del tipo di contributo
4. **Test locale**: installa la tua modifica con `./scripts/install.sh` e prova in Claude Code
5. **Apri PR** descrivendo:
   - Cosa hai aggiunto/modificato
   - Perché (caso d'uso reale che ha portato al contributo)
   - Come hai testato

---

## Cosa non va mai pubblicato

Il repo è pubblico e la cronologia git è per sempre: un segreto committato per sbaglio va considerato compromesso anche se lo cancelli subito dopo.

Non committare mai:
- credenziali di ogni tipo: password, token, chiavi API, chiavi private e certificati, file `.env`, file di credenziali di servizio
- indirizzi IP, nomi di host e percorsi di server o macchine tue o di terzi
- dati di clienti, di utenti o di colleghi, nomi inclusi, anche se anonimizzati male
- il contenuto reale di `~/.claude`: cronologia delle sessioni, memorie personali, `settings.json`, stato di autenticazione delle skill
- nomi di repository privati e dettagli dell'infrastruttura interna di chi contribuisce
- screenshot e log che mostrano uno qualunque dei punti sopra

Negli esempi usa segnaposto evidenti (`your_api_key_here`, `<TOKEN>`, `example.com`).

### Scanner anti-segreti e hook pre-commit

`scripts/lib/secret-scan.sh` cerca nei file i formati noti di chiavi (provider, chiavi PEM, JWT, URL con credenziali) e le assegnazioni del tipo `PASSWORD=...`. Non stampa mai il valore trovato, solo la posizione.

Attiva l'hook una volta per clone:

```bash
git config core.hooksPath .githooks
```

Da quel momento `.githooks/pre-commit` esegue lo scanner sui file in staging e blocca il commit se trova qualcosa. Per scansionare a mano:

```bash
bash scripts/lib/secret-scan.sh .            # tutto il repo
bash scripts/lib/secret-scan.sh --staged     # solo i file in staging
```

Uscita: `0` pulito, `3` trovato qualcosa (righe `file:riga:REGOLA`), `2` errore d'uso. Lo scanner richiede bash 4 o superiore; è stato provato con Git Bash su Windows e con bash 5 su Ubuntu (WSL), non su macOS.

Cosa legge: i file con byte NUL e quelli in UTF-16 con BOM vengono decodificati prima della scansione (serve `iconv`; se manca, lo scanner si ferma con exit `2` invece di dare un falso pulito). I file binari noti per estensione (immagini, archivi, ecc.) sono saltati. Nomi di file con `:` o con `-` iniziale sono gestiti.

Il file `.gitattributes` forza le fine riga LF su script, hook e file di regole (`*.sh`, `.githooks/*`, `scripts/lib/*.txt`, `.secret-allowlist*`), così un clone con `core.autocrlf=true` non rompe lo scanner. Non toglierlo.

`scripts/backup.sh` copia file da `~/.claude` dentro il repo: prima di committare esegui `bash scripts/lib/secret-scan.sh --repo . .` e aggiungi a mano i file che vuoi (`git add <file>`), non tutto in blocco.

Se la segnalazione è un falso positivo (per esempio una password d'esempio in una guida), verifica prima che la riga non contenga un valore vero. Poi aggiungi una voce a `.secret-allowlist` nella radice del repo, nel formato `path:REGOLA:sha256(riga)`. Il modello è in `.secret-allowlist.example`, con il comando per calcolare l'hash. Una voce vale solo per quella riga: se la modifichi, torna a essere segnalata.

Se invece il segreto è vero, non usare l'allowlist: ruotalo presso il provider e rimuovilo dalla cronologia prima di aprire la PR.

Le regole sono in `scripts/lib/secret-patterns.txt`, i perimetri per cartella in `scripts/lib/secret-scope.txt`. Il collaudo è `bash scripts/test/secret-scan.test.sh`.

---

## Cosa NON viene accettato

- ❌ Contributi che includono dati di clienti reali, anche anonimizzati male
- ❌ Pattern teorici senza esperienza pratica alle spalle
- ❌ Agenti troppo specifici (es. "agente per la mia stack proprietaria X")
- ❌ Skill che impongono workflow rigidi senza motivo (la filosofia del repo è "trigger > regole")
- ❌ PR che cambiano la filosofia del progetto senza Discussion preventiva

---

## Code of Conduct

- 🤝 Rispetta gli altri contributor
- 🇮🇹🇬🇧 Lingua libera ma cortese
- 💡 Critica le idee, non le persone
- 🎓 Sii paziente con chi è alle prime armi (è anche un toolkit didattico)
- 🚫 No spam, no auto-promo aggressiva

Vedi [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) per la versione estesa.

---

## Domande?

Apri una **GitHub Discussion** prima di fare PR significative. Spesso un contributo si raffina molto con una conversazione preventiva.
