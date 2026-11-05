# Fonte unica: dove vive ogni tipo di informazione

> 🇬🇧 English version: [docs/single-source-of-truth.md](single-source-of-truth.md)

> Ogni informazione ha una sola casa. Gli altri posti la richiamano con un link, non la copiano.

## Perché

Con una wiki, una KB stabile, le project memory, i docs dei repo e l'auto-memory di Claude Code,
lo stesso fatto tende a finire in quattro posti. Poi una copia viene aggiornata e le altre
restano indietro senza che nessuno se ne accorga. Il rimedio è una tabella scritta una volta:
per ogni tipo di informazione, qual è la fonte e cosa possono contenere gli altri posti.

## La tabella

| Tipo di informazione | Fonte unica | Cosa possono contenere gli altri posti |
|---|---|---|
| **Stato corrente di un progetto**: fase, versione (dal tag git), cosa è live, prossimi passi, data | `wiki/projects/<slug>.md`, sezione "Stato corrente" | index: una riga; project memory: un link alla pagina wiki |
| **Fatti stabili di un progetto**: stack, repo, deploy, URL, comandi, gotcha, decisioni chiave | KB `project-memories/<slug>.md` | pagina wiki: una riga con il link alla project memory |
| **Review log** di un progetto | KB `project-memories/<slug>.md`, sezione "Review log" | niente; mai nei `docs/` del repo (vedi [review log incrementale](review-log-incrementale.md)) |
| **Istruzioni operative** per lavorare in un repo | il `CLAUDE.md` del repo | niente versioni né stato: quelli stanno nella pagina wiki |
| **Documentazione del progetto**: architettura, ADR del progetto, manuali | i `docs/` del repo | wiki: un link, o un riassunto fatto all'ingest |
| **Feedback e preferenze** tue su come Claude deve lavorare su un progetto | l'auto-memory locale di Claude Code | solo questo; un fatto generale, o già scritto nella sua fonte, non si salva lì |
| **Inventario e stato delle risorse condivise**: server, DNS, account, backup | `wiki/infra/<risorsa>.md` | project memory e pagine progetto: solo il link |
| **Procedure operative** sulle risorse condivise e guide riusabili | KB `knowledge-base/<GUIDA>.md` (più `workflows/` e skill) | pagina wiki infra o concept: un link alla guida |
| **Pattern trasversale non ancora guida** | `wiki/concepts/<slug>.md` | niente |
| **Decisione architetturale trasversale** | `wiki/decisions/` | project memory: elenco di link |
| **Post-mortem o lezione datata** | `wiki/lessons/` | log: una riga |
| **Cronologia e panoramica storica** | una pagina di riepilogo nella wiki, più git | niente |
| **Secret** | il password manager, o il `.env` sul server | ovunque altrove: solo dove stanno, mai il valore |
| **Nota da sessione temporanea** (per esempio cloud o usa-e-getta) | `docs/kb-handoff/` nel repo del progetto | consolidata nella wiki al prossimo ingest locale, poi rimossa |

`wiki/infra/` non c'è nel template di partenza. Creala quando hai risorse condivise da inventariare.

## Regole che tengono onesta la tabella

1. **Link, non copia.** Se stai per incollare un numero di versione in un secondo file, metti un link.
2. **Stato e fatti sono file diversi.** "Cosa è live oggi" cambia ogni settimana e sta nella wiki. "Su che stack gira" cambia di rado e sta nella project memory.
3. **Un concept promosso diventa uno stub.** Dopo `/kb-promote` il concept in wiki tiene un breve rimando alla guida KB, e i nuovi gotcha si scrivono solo nella guida. Vedi il [workflow KB-driven](workflow-kb-driven.md).
4. **L'auto-memory resta piccola.** Quella di Claude Code serve per feedback e preferenze. Se un fatto appartiene a una riga qui sopra, scrivilo lì.
5. **I secret sono l'eccezione.** Anche il rimando dice dove sta il secret, non cosa contiene.

## Adattarla

La tabella è un punto di partenza. Rinomina i posti secondo il tuo setup e togli le righe che non servono.
Conta che ogni riga abbia esattamente una fonte, e che tu sappia rispondere a "dove lo aggiorno?" senza pensarci.
