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

# Perimetro wiki: wiki/projects/** e raw/** attivano la regola in prosa.
mkdir -p "$R/wiki/projects" "$R/raw/sessions"
printf -- '- Password: %s\n' "$PW" > "$R/wiki/projects/x.md"
OUT="$(bash "$SCAN" "$R/wiki/projects/x.md" 2>&1)"
check "wiki/projects: prosa con password -> exit 3" 3 $?
check "wiki/projects: output = file:riga:REGOLA" "wiki/projects/x.md:1:SECRET_ASSIGNMENT_PROSE" "$OUT"
printf -- '- Password: %s\n' "$PW" > "$R/raw/sessions/s.md"
bash "$SCAN" "$R/raw/sessions/s.md" >/dev/null 2>&1
check "raw: prosa con password -> exit 3" 3 $?
rm -rf "$R/wiki" "$R/raw"

# Scope salvato con CRLF (clone con autocrlf): le regole devono agganciarsi.
sed 's/$/\r/' "$R/scripts/lib/secret-scope.txt" > "$WORK/scope-crlf.txt"
printf -- '- Password: %s\n' "$PW" > "$R/project-memories/nota.md"
printf -- '- Password: %s\n' "$PW" > "$R/docs/nota.md"
OUT="$(SECRET_SCOPE_FILE="$WORK/scope-crlf.txt" bash "$SCAN" "$R/project-memories" "$R/docs" 2>&1)"
check "scope con CRLF: prosa solo nella cartella di memoria" "project-memories/nota.md:1:SECRET_ASSIGNMENT_PROSE" "$OUT"
rm -f "$R/project-memories/nota.md" "$R/docs/nota.md"

echo "=== scanner: file con NUL, UTF-16, nomi particolari ==="
VN="$(fake_secret)"
# NUL dentro il file: prima dava exit 0 ("Binary file matches").
{ printf 'riga uno\n'; printf 'k = "%s"' "$VN"; printf '\000\000coda\n'; } > "$R/nul.dat"
OUT="$(bash "$SCAN" "$R/nul.dat" 2>&1)"
check "file con NUL e secret -> exit 3" 3 $?
check "file con NUL: output = file:riga:REGOLA" "nul.dat:2:OPENAI_KEY" "$OUT"
if [[ "$OUT" == *"$VN"* ]]; then bad "NUL: il valore NON deve comparire"; else ok "NUL: il valore non compare"; fi
{ printf 'niente\000qui\n'; } > "$R/nul-clean.dat"
bash "$SCAN" "$R/nul-clean.dat" >/dev/null 2>&1
check "file con NUL senza secret -> exit 0" 0 $?
{ printf 'k = "%s"\000\n' "$VN"; } > "$R/finto.png"
bash "$SCAN" "$R/finto.png" >/dev/null 2>&1
check "binario noto per estensione -> saltato (exit 0)" 0 $?
rm -f "$R/nul.dat" "$R/nul-clean.dat" "$R/finto.png"

if command -v iconv >/dev/null 2>&1; then
    printf 'riga uno\nk = "%s"\n' "$VN" | iconv -f UTF-8 -t UTF-16 > "$R/u16.txt"
    OUT="$(bash "$SCAN" "$R/u16.txt" 2>&1)"
    check "UTF-16 con BOM e secret -> exit 3" 3 $?
    check "UTF-16 con BOM: output = file:riga:REGOLA" "u16.txt:2:OPENAI_KEY" "$OUT"
    printf 'riga uno\nk = "%s"\n' "$VN" | iconv -f UTF-8 -t UTF-16LE > "$R/u16le.txt"
    bash "$SCAN" "$R/u16le.txt" >/dev/null 2>&1
    check "UTF-16LE senza BOM e secret -> exit 3" 3 $?
    printf 'tutto pulito\n' | iconv -f UTF-8 -t UTF-16 > "$R/u16-clean.txt"
    bash "$SCAN" "$R/u16-clean.txt" >/dev/null 2>&1
    check "UTF-16 senza secret -> exit 0" 0 $?
    rm -f "$R/u16.txt" "$R/u16le.txt" "$R/u16-clean.txt"
else
    echo "  [SKIP] iconv non installato: test UTF-16 saltati"
fi

# Nome che inizia per "-" (find e grep lo leggevano come opzione).
printf 'k = "%s"\n' "$VN" > "$R/-dash.txt"
OUT="$(cd "$R" && bash "$SCAN" -- -dash.txt 2>&1)"
check "nome con '-' iniziale (file) -> exit 3" 3 $?
check "nome con '-' iniziale: output" "-dash.txt:1:OPENAI_KEY" "$OUT"
OUT="$(bash "$SCAN" "$R" 2>&1)"
check "nome con '-' iniziale (cartella) -> exit 3" 3 $?
check "nome con '-' iniziale (cartella): output" "-dash.txt:1:OPENAI_KEY" "$OUT"
rm -f "$R/-dash.txt"

# Nome con spazio e apice.
printf 'k = "%s"\n' "$VN" > "$R/sp ace's.txt"
OUT="$(bash "$SCAN" "$R" 2>&1)"
check "nome con spazio e apice -> exit 3" 3 $?
check "nome con spazio e apice: output" "sp ace's.txt:1:OPENAI_KEY" "$OUT"
rm -f "$R/sp ace's.txt"

# Nome con ":" (non creabile su Windows: in quel caso il test si salta).
if printf 'k = "%s"\n' "$VN" > "$R/co:lon.txt" 2>/dev/null; then
    OUT="$(bash "$SCAN" "$R" 2>&1)"
    check "nome con ':' -> exit 3" 3 $?
    check "nome con ':': output" "co:lon.txt:1:OPENAI_KEY" "$OUT"
    HASHC="$(printf '%s' "$(sed -n '1p' "$R/co:lon.txt")" | sha256sum | awk '{print $1}')"
    printf 'co:lon.txt:OPENAI_KEY:%s\n' "$HASHC" > "$R/.secret-allowlist"
    bash "$SCAN" "$R" >/dev/null 2>&1
    check "nome con ':' in allowlist -> exit 0" 0 $?
    rm -f "$R/co:lon.txt" "$R/.secret-allowlist"
else
    rm -f "$R/co:lon.txt"
    echo "  [SKIP] il filesystem non ammette ':' nei nomi: test saltato"
fi

# Allowlist: ultima voce senza newline finale, e allowlist con CRLF.
printf 'k = "%s"\n' "$VN" > "$R/al.txt"
HASHA="$(printf '%s' "$(sed -n '1p' "$R/al.txt")" | sha256sum | awk '{print $1}')"
printf 'al.txt:OPENAI_KEY:%s' "$HASHA" > "$R/.secret-allowlist"
bash "$SCAN" "$R/al.txt" >/dev/null 2>&1
check "allowlist senza newline finale -> exit 0" 0 $?
printf 'al.txt:OPENAI_KEY:%s\r\n' "$HASHA" > "$R/.secret-allowlist"
bash "$SCAN" "$R/al.txt" >/dev/null 2>&1
check "allowlist con CRLF -> exit 0" 0 $?
rm -f "$R/.secret-allowlist" "$R/al.txt"

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

# Nuovi casi: NUL, UTF-16 e nome con "-" iniziale devono bloccare il commit.
VALUE3="$(fake_secret)"
try_block() {   # try_block <etichetta> <file relativo a $G>
    git -C "$G" add -- "$2" >/dev/null 2>&1
    git -C "$G" commit -q -m "$1" >/dev/null 2>&1
    local rc=$?
    if [[ $rc -ne 0 ]]; then ok "$1: commit bloccato"; else bad "$1: commit NON bloccato"; fi
    git -C "$G" reset -q >/dev/null 2>&1
    rm -f "$G/$2"
}
{ printf 'k = "%s"' "$VALUE3"; printf '\000\n'; } > "$G/nul.dat"
try_block "hook, file con NUL" nul.dat
if command -v iconv >/dev/null 2>&1; then
    printf 'k = "%s"\n' "$VALUE3" | iconv -f UTF-8 -t UTF-16 > "$G/u16.txt"
    try_block "hook, file UTF-16" u16.txt
fi
printf 'k = "%s"\n' "$VALUE3" > "$G/-dash.txt"
try_block "hook, nome con '-' iniziale" ./-dash.txt

echo ""
echo "Totale: $PASS ok, $FAIL falliti"
[[ $FAIL -eq 0 ]]
