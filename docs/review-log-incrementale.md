# Review log incrementale: si rivede solo ciò che è cambiato

> 🇬🇧 English version: [docs/incremental-review-log.md](incremental-review-log.md)

> Dopo la prima review di un progetto, ogni review successiva guarda solo il diff dall'ultima registrata.

## Il problema

Se ogni review rilegge tutto il progetto, il reviewer spende il suo contesto su codice già
controllato e i finding rimandati si dimenticano. Se le review si saltano, nulla è controllato.
Un log di cosa è stato rivisto, e a quale commit, risolve entrambe le cose.

## La regola

1. Tieni un **review log** per ogni progetto, nel file di memoria del progetto nella KB (`project-memories/<progetto>.md`), in una sezione chiamata `## Review log`. Mai nei `docs/` del repo (vedi [fonte unica](fonte-unica.md)).
2. Ogni voce registra: **data**, **SHA** rivisto, **esito** e **finding ancora aperti**.
3. Per rivedere, prendi l'ultimo SHA del log e rivedi solo `git diff <ultimo-sha>..HEAD`.
4. Se il log non esiste ancora, fai una review completa. Quella è la prima voce.
5. Passa lo SHA all'agente `reviewer` nel prompt, insieme all'intervallo del diff, così sa cosa è in ambito.
6. A review finita, **aggiungi una voce** con il nuovo SHA di HEAD, l'esito e i finding aperti.

## Esempio di log

```markdown
## Review log

| Data | SHA | Esito | Finding aperti |
|---|---|---|---|
| 2026-09-02 | a1b2c3d | review completa, 3 fix applicati | nessuno |
| 2026-09-20 | e4f5a6b | diff a1b2c3d..e4f5a6b, approvato | rate limit su /export da decidere |
```

## In pratica

```bash
# ultimo SHA dal log: a1b2c3d
git diff a1b2c3d..HEAD --stat     # quanto è grande la modifica
git log --oneline a1b2c3d..HEAD   # quali commit sono in ambito
```

Poi chiedi al lead di far passare quell'intervallo dal gate `reviewer`. Qualche cautela:

- Registra lo SHA effettivamente rivisto, non uno successivo. I commit fatti mentre la review girava appartengono all'intervallo seguente.
- Riporta i finding aperti nella nuova voce finché qualcuno non li chiude, così non si perdono tra una review e l'altra.
- Se la storia è stata riscritta e lo SHA registrato non esiste più, trattalo come log mancante e fai una review completa.
