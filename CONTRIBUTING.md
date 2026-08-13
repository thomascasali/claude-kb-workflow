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

Un pattern è un **lesson learned da produzione**. Va in `patterns/critical-patterns.md`.

**Criteri di accettazione**:
- ✅ Hai osservato il pattern in **almeno 2 progetti diversi**
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
