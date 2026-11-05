#!/bin/bash
# ============================================================================
# scripts/restore-test.sh — collaudo end-to-end di backup.sh + restore.sh
# ============================================================================
#
# Verifica che il ripristino funzioni davvero con il formato che produce
# scripts/backup.sh, su una HOME temporanea vuota. Mai la vera ~/.claude.
#
# Cosa fa (tutto sotto una cartella temporanea, rimossa a fine esecuzione):
#   1. Costruisce una finta ~/.claude di partenza con file inventati
#      (agenti, pattern, workflow, skill con sottocartelle, comandi, più
#      elementi che il backup deve escludere).
#   2. Copia scripts/ in un finto repo temporaneo e lancia lì backup.sh.
#   3. Lancia restore.sh dal finto repo in una HOME nuova e vuota e confronta
#      il risultato con la finta ~/.claude di partenza.
#   4. Prova le garanzie di restore.sh: senza --force non sovrascrive, con
#      --force sovrascrive lasciando una copia di sicurezza, --dry-run non
#      scrive nulla.
#   5. Ripristina il repo vero (in sola lettura) in un'altra HOME vuota e
#      controlla che ogni agente, pattern, workflow e comando arrivi a
#      destinazione.
#   6. Controlla che settings.json della vera ~/.claude (se esiste) non sia
#      cambiato (hash e data di modifica prima/dopo; il contenuto non viene
#      mai letto né stampato).
#
# Uso: bash scripts/restore-test.sh [--keep]
#   --keep   non cancella la cartella temporanea (per ispezione).
#
# Codici d'uscita: 0 tutti i controlli passati · 1 almeno un controllo
# fallito · 2 errore d'uso o d'ambiente.
#
# Richiede bash e gli strumenti standard (cp, cmp, find, mktemp, sha256sum o
# shasum, git). Testato solo con Git Bash su Windows.
# ============================================================================

set -u

KEEP=0
case "${1:-}" in
    "") ;;
    --keep) KEEP=1 ;;
    *) echo "uso: restore-test.sh [--keep]" >&2; exit 2 ;;
esac

REAL_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for c in cp cmp find mktemp git; do
    command -v "$c" >/dev/null 2>&1 || { echo "[FAIL] comando richiesto non trovato: $c" >&2; exit 2; }
done

# --- vera ~/.claude: impronta prima (solo settings.json, mai letto) ----------
REAL_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
REAL_SETTINGS="$REAL_HOME/settings.json"
file_sha() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
    else echo "nessun-tool-hash"; fi
}
file_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo "?"; }
if [[ -f "$REAL_SETTINGS" ]]; then
    REAL_BEFORE="$(file_sha "$REAL_SETTINGS") $(file_mtime "$REAL_SETTINGS")"
else
    REAL_BEFORE="assente"
fi

# --- area di lavoro temporanea ----------------------------------------------
T="$(mktemp -d)" || { echo "[FAIL] mktemp fallito" >&2; exit 2; }
cleanup() { [[ $KEEP -eq 1 ]] || rm -rf "$T"; }
trap cleanup EXIT

# Da qui in poi nessuno strumento deve poter vedere la vera home: HOME e
# CLAUDE_CONFIG_DIR puntano nell'area temporanea; git è isolato dalla
# configurazione dell'utente e non risale verso repo antenati.
export HOME="$T/home"
export USERPROFILE="$HOME"
export CLAUDE_CONFIG_DIR="$HOME/.claude"
mkdir -p "$HOME"
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$T/gitconfig"
export GIT_TERMINAL_PROMPT=0
export GIT_CEILING_DIRECTORIES="$(dirname "$T")"
printf '[user]\n\tname = Test\n\temail = test@example.invalid\n[core]\n\tautocrlf = false\n' > "$GIT_CONFIG_GLOBAL"

SRC_HOME="$T/src-claude"      # finta ~/.claude di partenza
FAKE_REPO="$T/repo"           # finto repo: riceve backup.sh, poi è la sorgente di restore.sh
DST_HOME="$T/dst-claude"      # HOME vuota in cui si ripristina
LOG="$T/out.log"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  [PASS] %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  [FAIL] %s\n' "$1"; }
check() {   # check "etichetta" atteso reale
    if [[ "$3" == "$2" ]]; then ok "$1"; else bad "$1 (atteso [$2], trovato [$3])"; fi
}
same() {    # same "etichetta" fileA fileB
    if [[ -f "$2" && -f "$3" ]] && cmp -s "$2" "$3"; then ok "$1"; else bad "$1"; fi
}
absent() {  # absent "etichetta" percorso
    if [[ ! -e "$2" ]]; then ok "$1"; else bad "$1 (esiste: $2)"; fi
}

# --- 1. finta ~/.claude -------------------------------------------------------
echo "== 1. finta ~/.claude di partenza"
mkdir -p "$SRC_HOME"/{agents,patterns,workflows,commands} \
         "$SRC_HOME/skills/demo-skill/references" "$SRC_HOME/skills/notebooklm"
printf '# agente uno\n'          > "$SRC_HOME/agents/uno.md"
printf '# agente due\n'          > "$SRC_HOME/agents/due.md"
printf '# pattern\n'             > "$SRC_HOME/patterns/p.md"
printf '# workflow\n'            > "$SRC_HOME/workflows/w.md"
printf -- '---\nname: demo-skill\n---\n' > "$SRC_HOME/skills/demo-skill/SKILL.md"
printf '# riferimento\n'         > "$SRC_HOME/skills/demo-skill/references/ref.md"
printf 'dato di autenticazione finto\n' > "$SRC_HOME/skills/notebooklm/auth.txt"
printf '# comando kb\n'          > "$SRC_HOME/commands/kb-demo.md"
printf '# comando altrui\n'      > "$SRC_HOME/commands/altro-plugin.md"
printf '{"finto": true}\n'       > "$SRC_HOME/settings.json"

# --- 2. backup.sh in un finto repo -------------------------------------------
echo "== 2. backup.sh nel finto repo"
mkdir -p "$FAKE_REPO"
cp -r "$REAL_REPO/scripts" "$FAKE_REPO/scripts"
git -C "$FAKE_REPO" init -q
CLAUDE_CONFIG_DIR="$SRC_HOME" bash "$FAKE_REPO/scripts/backup.sh" > "$LOG" 2>&1
check "backup.sh exit 0" 0 $?
same "backup: agents/uno.md copiato" "$SRC_HOME/agents/uno.md" "$FAKE_REPO/agents/uno.md"
same "backup: skill con sottocartella" "$SRC_HOME/skills/demo-skill/references/ref.md" "$FAKE_REPO/skills/demo-skill/references/ref.md"
same "backup: comando kb-*" "$SRC_HOME/commands/kb-demo.md" "$FAKE_REPO/commands/kb-demo.md"
absent "backup: skill notebooklm esclusa" "$FAKE_REPO/skills/notebooklm"
absent "backup: comando non kb-* escluso" "$FAKE_REPO/commands/altro-plugin.md"
absent "backup: settings.json non copiato" "$FAKE_REPO/settings.json"

# --- 3. restore in una HOME vuota -------------------------------------------
echo "== 3. restore.sh in una HOME vuota"
CLAUDE_CONFIG_DIR="$DST_HOME" bash "$FAKE_REPO/scripts/restore.sh" > "$LOG" 2>&1
check "restore.sh exit 0" 0 $?
cat "$LOG"
same "restore: agents/uno.md" "$SRC_HOME/agents/uno.md" "$DST_HOME/agents/uno.md"
same "restore: agents/due.md" "$SRC_HOME/agents/due.md" "$DST_HOME/agents/due.md"
same "restore: patterns/p.md" "$SRC_HOME/patterns/p.md" "$DST_HOME/patterns/p.md"
same "restore: workflows/w.md" "$SRC_HOME/workflows/w.md" "$DST_HOME/workflows/w.md"
same "restore: skill SKILL.md" "$SRC_HOME/skills/demo-skill/SKILL.md" "$DST_HOME/skills/demo-skill/SKILL.md"
same "restore: skill sottocartella" "$SRC_HOME/skills/demo-skill/references/ref.md" "$DST_HOME/skills/demo-skill/references/ref.md"
same "restore: comando kb-demo" "$SRC_HOME/commands/kb-demo.md" "$DST_HOME/commands/kb-demo.md"
absent "restore: niente skill notebooklm" "$DST_HOME/skills/notebooklm"
absent "restore: niente comando altrui" "$DST_HOME/commands/altro-plugin.md"
absent "restore: niente settings.json" "$DST_HOME/settings.json"
absent "restore: nessuna copia di sicurezza su HOME vuota" "$DST_HOME/backups"

# --- 4. garanzie: non sovrascrive / --force / --dry-run ----------------------
echo "== 4. garanzie di restore.sh"
printf '# modificato in locale\n' > "$DST_HOME/agents/uno.md"
CLAUDE_CONFIG_DIR="$DST_HOME" bash "$FAKE_REPO/scripts/restore.sh" > "$LOG" 2>&1
check "senza --force: exit 0" 0 $?
check "senza --force: il file locale resta" "# modificato in locale" "$(cat "$DST_HOME/agents/uno.md")"
absent "senza --force: nessuna copia di sicurezza" "$DST_HOME/backups"

CLAUDE_CONFIG_DIR="$DST_HOME" bash "$FAKE_REPO/scripts/restore.sh" --force > "$LOG" 2>&1
check "--force: exit 0" 0 $?
same "--force: file ripristinato" "$SRC_HOME/agents/uno.md" "$DST_HOME/agents/uno.md"
SAFE="$(find "$DST_HOME/backups" -type f -name uno.md 2>/dev/null | head -1)"
if [[ -n "$SAFE" && "$(cat "$SAFE")" == "# modificato in locale" ]]; then
    ok "--force: copia di sicurezza della versione locale"
else
    bad "--force: copia di sicurezza della versione locale"
fi

EMPTY_HOME="$T/dry-claude"
CLAUDE_CONFIG_DIR="$EMPTY_HOME" bash "$FAKE_REPO/scripts/restore.sh" --dry-run > "$LOG" 2>&1
check "--dry-run: exit 0" 0 $?
absent "--dry-run: non crea la cartella di destinazione" "$EMPTY_HOME"

bash "$FAKE_REPO/scripts/restore.sh" --opzione-sbagliata >/dev/null 2>&1
check "argomento sconosciuto: exit 2" 2 $?

# --- 5. il repo vero, in sola lettura ----------------------------------------
echo "== 5. restore del repo vero in una HOME vuota"
REAL_DST="$T/real-dst-claude"
bash "$REAL_REPO/scripts/restore.sh" --home "$REAL_DST" > "$LOG" 2>&1
check "restore del repo vero: exit 0" 0 $?
MISSING=0; TOTAL=0
for f in "$REAL_REPO"/agents/*.md; do
    n="${f##*/}"; TOTAL=$((TOTAL+1))
    if [[ "$n" == "README-AGENTI.md" ]]; then dest="$REAL_DST/$n"; else dest="$REAL_DST/agents/$n"; fi
    cmp -s "$f" "$dest" || MISSING=$((MISSING+1))
done
for f in "$REAL_REPO"/patterns/*.md; do TOTAL=$((TOTAL+1)); cmp -s "$f" "$REAL_DST/patterns/${f##*/}" || MISSING=$((MISSING+1)); done
for f in "$REAL_REPO"/workflows/*.md; do TOTAL=$((TOTAL+1)); cmp -s "$f" "$REAL_DST/workflows/${f##*/}" || MISSING=$((MISSING+1)); done
for f in "$REAL_REPO"/commands/kb-*.md; do TOTAL=$((TOTAL+1)); cmp -s "$f" "$REAL_DST/commands/${f##*/}" || MISSING=$((MISSING+1)); done
for d in "$REAL_REPO"/skills/*/; do
    [[ -f "$d/SKILL.md" ]] || continue
    TOTAL=$((TOTAL+1)); cmp -s "$d/SKILL.md" "$REAL_DST/skills/$(basename "$d")/SKILL.md" || MISSING=$((MISSING+1))
done
check "repo vero: $TOTAL file verificati, mancanti o diversi" 0 "$MISSING"

# --- 6. la vera ~/.claude non è cambiata -------------------------------------
echo "== 6. vera ~/.claude intatta"
if [[ -f "$REAL_SETTINGS" ]]; then
    REAL_AFTER="$(file_sha "$REAL_SETTINGS") $(file_mtime "$REAL_SETTINGS")"
else
    REAL_AFTER="assente"
fi
check "settings.json della vera home: hash e mtime invariati" "$REAL_BEFORE" "$REAL_AFTER"

echo ""
if [[ $FAIL -eq 0 ]]; then
    echo "ESITO: OK — $PASS controlli passati, 0 falliti"
    [[ $KEEP -eq 1 ]] && echo "Cartella temporanea conservata: $T"
    exit 0
fi
echo "ESITO: FALLITO — $PASS passati, $FAIL falliti"
[[ $KEEP -eq 1 ]] && echo "Cartella temporanea conservata: $T"
exit 1
