#!/bin/bash
# ============================================================================
# scripts/test/secret-scan.test.sh — collaudo dello scanner anti-secret e
# dell'hook .githooks/pre-commit.
# ============================================================================
#
# Uso: bash scripts/test/secret-scan.test.sh
# Exit 0 se tutti i controlli passano, 1 altrimenti.
#
# I "secret" sono finti e generati a runtime con caratteri casuali (nessun
# valore di prova è scritto in questo file, quindi lo scanner non lo trova nel
# repo). Tutto avviene in una cartella temporanea, rimossa a fine esecuzione
# con trap: il repo vero non viene toccato e nessun commit viene fatto fuori
# dai repo git temporanei. Git è isolato dalla configurazione dell'utente.
# ============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Isolamento di git: nessuna config utente/di sistema, nessun prompt, e la
# risalita verso un repo antenato è bloccata.
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$WORK/gitconfig"
export GIT_TERMINAL_PROMPT=0
export GIT_CEILING_DIRECTORIES="$(dirname "$WORK")"
printf '[user]\n\tname = Test\n\temail = test@example.invalid\n[core]\n\tautocrlf = false\n' > "$GIT_CONFIG_GLOBAL"
unset SECRET_ALLOWLIST SECRET_SCOPE_FILE SECRET_SCAN_EXTRA_REPO

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); printf '  [PASS] %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  [FAIL] %s\n' "$1"; }
check() {   # check "etichetta" atteso reale
    if [[ "$3" == "$2" ]]; then ok "$1"; else bad "$1 (atteso [$2], trovato [$3])"; fi
}

# Copia minima del toolkit: scanner + regole + hook, in un "repo" di prova.
make_repo() {   # make_repo <dir>
    local d="$1"
    mkdir -p "$d/scripts/lib" "$d/.githooks"
    cp "$REAL_REPO/scripts/lib/"{common.sh,secret-scan.sh,secret-patterns.txt,secret-scope.txt} "$d/scripts/lib/"
    cp "$REAL_REPO/.githooks/pre-commit" "$d/.githooks/pre-commit"
    chmod +x "$d/.githooks/pre-commit"
}

# Secret finto: prefisso di provider + 32 caratteri alfanumerici casuali.
# Il prefisso è spezzato per non comparire intero in questo file.
fake_secret() { printf '%s%s' 'sk''-' "$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)"; }

echo "=== scanner ==="
R="$WORK/repo1"
make_repo "$R"
SCAN="$R/scripts/lib/secret-scan.sh"
VALUE="$(fake_secret)"

printf 'nessun segreto qui\n' > "$R/clean.txt"
bash "$SCAN" "$R/clean.txt" >/dev/null 2>&1
check "file pulito -> exit 0" 0 $?

printf 'riga uno\nchiave = "%s"\n' "$VALUE" > "$R/leak.txt"
OUT="$(bash "$SCAN" "$R/leak.txt" 2>&1)"
check "secret finto -> exit 3" 3 $?
check "output = file:riga:REGOLA" "leak.txt:2:OPENAI_KEY" "$OUT"
if [[ "$OUT" == *"$VALUE"* ]]; then bad "il valore NON deve comparire nell'output"; else ok "il valore non compare nell'output"; fi

bash "$SCAN" >/dev/null 2>&1
check "nessun argomento -> exit 2" 2 $?
bash "$SCAN" --opzione-inesistente >/dev/null 2>&1
check "opzione sconosciuta -> exit 2" 2 $?

# Allowlist: voce per (path, regola, sha256 della riga intera).
LINE="$(sed -n '2p' "$R/leak.txt")"
HASH="$(printf '%s' "$LINE" | sha256sum | awk '{print $1}')"
printf 'leak.txt:OPENAI_KEY:%s\n' "$HASH" > "$R/.secret-allowlist"
bash "$SCAN" "$R/leak.txt" >/dev/null 2>&1
check "riga in allowlist -> exit 0" 0 $?

# Cambiando la riga l'hash non combacia più: torna bloccante.
printf 'riga uno\nchiave = "%s" # modificata\n' "$VALUE" > "$R/leak.txt"
bash "$SCAN" "$R/leak.txt" >/dev/null 2>&1
check "riga modificata, hash diverso -> exit 3" 3 $?
rm -f "$R/.secret-allowlist"

# Regola larga SECRET_ASSIGNMENT_PROSE: solo nelle cartelle di memoria.
PW="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 14)"
mkdir -p "$R/project-memories" "$R/docs"
printf -- '- Password: %s\n' "$PW" > "$R/project-memories/nota.md"
printf -- '- Password: %s\n' "$PW" > "$R/docs/nota.md"
OUT="$(bash "$SCAN" "$R/project-memories" "$R/docs" 2>&1)"
check "prosa: segnalata solo nella cartella di memoria" "project-memories/nota.md:1:SECRET_ASSIGNMENT_PROSE" "$OUT"
if [[ "$OUT" == *"$PW"* ]]; then bad "il valore (prosa) NON deve comparire"; else ok "il valore (prosa) non compare"; fi

# Segnaposto: non devono scattare.
printf 'API_KEY=your_api_key_here\nTOKEN=${TOKEN}\n' > "$R/docs/env.example"
rm -f "$R/project-memories/nota.md" "$R/docs/nota.md" "$R/leak.txt"
bash "$SCAN" "$R/docs" >/dev/null 2>&1
check "segnaposto -> exit 0" 0 $?

echo "=== hook pre-commit (repo git temporaneo) ==="
G="$WORK/repo2"
make_repo "$G"
git -C "$G" init -q
git -C "$G" config core.hooksPath .githooks
VALUE2="$(fake_secret)"

printf 'ciao\n' > "$G/ok.txt"
git -C "$G" add ok.txt
COMMIT_OUT="$(git -C "$G" commit -q -m "file pulito" 2>&1)"
check "commit pulito passa" 0 $?

printf 'x = "%s"\n' "$VALUE2" > "$G/leak.txt"
git -C "$G" add leak.txt
COMMIT_OUT="$(git -C "$G" commit -q -m "con secret" 2>&1)"
RC=$?
if [[ $RC -ne 0 ]]; then ok "commit con secret bloccato (exit $RC)"; else bad "commit con secret NON bloccato"; fi
if [[ "$COMMIT_OUT" == *"leak.txt:1:OPENAI_KEY"* ]]; then ok "l'hook riporta file:riga:REGOLA"; else bad "l'hook non riporta file:riga:REGOLA"; fi
if [[ "$COMMIT_OUT" == *"$VALUE2"* ]]; then bad "il valore NON deve comparire nell'output dell'hook"; else ok "il valore non compare nell'output dell'hook"; fi
check "nessun commit creato dal tentativo bloccato" 1 "$(git -C "$G" rev-list --count HEAD)"

# Con la voce in allowlist lo stesso file passa.
HASH2="$(printf '%s' "$(sed -n '1p' "$G/leak.txt")" | sha256sum | awk '{print $1}')"
printf 'leak.txt:OPENAI_KEY:%s\n' "$HASH2" > "$G/.secret-allowlist"
git -C "$G" add .secret-allowlist
git -C "$G" commit -q -m "con allowlist" >/dev/null 2>&1
check "stesso file con allowlist passa" 0 $?

echo ""
echo "Totale: $PASS ok, $FAIL falliti"
[[ $FAIL -eq 0 ]]
