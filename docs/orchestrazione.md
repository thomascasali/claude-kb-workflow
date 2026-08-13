# Orchestrazione: lead + subagent

> 🇬🇧 English version: [docs/orchestration.md](orchestration.md)

> Il sistema di lavoro multi-agente del toolkit (introdotto nella v0.2).
> Un solo principio: **il modello principale non esegue il lavoro — lo orchestra.**

## Il modello mentale

Nei lavori non banali, la sessione principale di Claude Code agisce da **lead**:

1. **Pianifica** — mostra il piano prima di eseguire
2. **Decompone** — spezza il lavoro in fasi delegabili
3. **Delega** ai subagent — non esegue il lavoro in prima persona
4. **Sintetizza** — integra i risultati tenendo il proprio contesto snello

Il vantaggio non è (solo) la parallelizzazione: è che il contesto del lead resta
pulito e strategico, mentre i dettagli sporchi (file letti, tentativi, output di
test) restano nei contesti usa-e-getta dei subagent.

## Il pool a due livelli + specialisti

```
                    ┌─ deep-reasoner (Opus)    → architettura, debug complesso, algoritmi
  LEAD (orchestra) ─┼─ fast-worker  (Sonnet)   → lavoro meccanico, parti standard, test
                    ├─ 8 specialisti (Sonnet)  → backend-dev, frontend-dev, mobile-dev,
                    │                            devops, database, integrations,
                    │                            realtime-dev, ci-cd
                    └─ 2 specialisti (Opus)    → reviewer, security
```

**Gate obbligatorio**: prima di dichiarare un lavoro finito, il risultato passa da
`reviewer`. È il singolo accorgimento con il miglior rapporto costo/benefici del
sistema: obbliga una seconda lettura con un contesto pulito.

## Le 6 regole non ovvie (imparate a caro prezzo)

1. **Un agente esiste solo se il frontmatter YAML parsa.** Un file in
   `~/.claude/agents/` senza frontmatter (o con frontmatter corrotto) è
   invisibile: non dà errori, semplicemente non viene mai usato.
   ```yaml
   ---
   name: nome-agente
   description: Cosa fa e QUANDO usarlo. È l'unico criterio di selezione del lead.
   model: sonnet   # opus per le fasi di ragionamento; 'inherit' per ereditare
   ---            #  dalla sessione; omesso = modello di default dei subagent
   ```
2. **La `description` è l'unico criterio di auto-selezione.** Il lead vede
   nome+description di ogni agente e sceglie in base a quelle. Se delega male,
   si corregge la description — non il prompt.
3. **Tieni la delega piatta.** L'annidamento (un subagent che delega a sua volta)
   è tecnicamente possibile quando il subagent ha il tool di delega, ma moltiplica
   token e latenza e ti fa perdere il controllo della sintesi: la regola operativa
   è che delega SOLO il lead. Non progettare specialisti "dentro" altri agenti.
4. **Non elencare gli agenti nei prompt o in CLAUDE.md** per "farli scoprire":
   la scoperta è automatica. In CLAUDE.md va solo la *politica di routing*.
5. **La formula del lead va in CLAUDE.md, non nei prompt.** Come standing policy
   viene caricata in ogni sessione; nel prompt restano solo task, vincoli e gate
   extra. Esempio di policy (adattala):
   ```markdown
   ## Flusso di orchestrazione (vale per ogni lavoro non banale)
   Tu sei il lead: pianifica, decomponi, delega ai subagent — non eseguire
   tu il lavoro — e sintetizza. Mostra prima il piano, poi esegui.
   - Ragionamento -> deep-reasoner · Meccanico -> fast-worker
   - Per il resto scegli lo specialista dalla description del pool.
   - Gate obbligatorio: prima di dichiarare finito, passa da `reviewer`.
   - Eccezione: task banali/conversazionali in prima persona, senza cerimonia.
   ```
6. **Nomina un agente nel prompt solo per forzare l'eccezione** — es. "questa
   decisione di schema falla valutare a deep-reasoner e a un secondo motore in
   parallelo, poi sintetizza alla cieca". Il caso ordinario lo gestisce la policy.

## La gerarchia delle leve

| Livello | Contiene | Quando toccarlo |
|---|---|---|
| `~/.claude/CLAUDE.md` | Formula lead + routing + gate reviewer | Solo cambi di metodo |
| `agents/*.md` → `description` | Criterio di selezione | Se il lead delega male/poco |
| Prompt di sessione | Task, vincoli, gate extra | Ogni lavoro |

## Una storia vera (perché il check di salute conta)

Questo sistema è rimasto **inerte per mesi senza che nessuno se ne accorgesse**:
i due agenti principali avevano il frontmatter corrotto da un editor che aveva
escapato il markdown (`\---` al posto di `---`, `&#x20;` al posto degli spazi), e
gli specialisti non avevano frontmatter affatto. Tutto *sembrava* funzionare —
il lead semplicemente improvvisava da solo.

**Check di salute** (30 secondi): chiedi al lead "che subagent hai a disposizione?"
Se i tuoi agenti non compaiono nell'elenco, il frontmatter non parsa. Dopo la
correzione riavvia la sessione (o `claude --continue`, che ricarica il pool senza
perdere la conversazione); in alcuni ambienti il pool si ricarica anche a caldo.

## Quando NON orchestrare

Task banali, fix da una riga, domande conversazionali: farli in prima persona,
senza cerimonia. L'orchestrazione ha un costo (token + latenza) che si ripaga
solo quando il lavoro ha fasi distinte o richiede contesti isolati.
