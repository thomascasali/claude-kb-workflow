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

echo "=== scanner: nomi di cartella con comandi ==="
# Su bash 5.1 [[ -v a[$k] ]] eseguiva il $(...) del nome durante lo scan.
OUTSIDE="$WORK/fuori"
mkdir -p "$OUTSIDE"
INJ='x$(touch PWNED)y'
mkdir -p "$OUTSIDE/$INJ/sotto" "$OUTSIDE/@" "$OUTSIDE/a]b"
printf 'k = "%s"\n' "$VN" > "$OUTSIDE/$INJ/sotto/s.txt"
printf 'pulito\n' > "$OUTSIDE/@/p.txt"
printf 'pulito\n' > "$OUTSIDE/a]b/p.txt"
(cd "$OUTSIDE" && bash "$SCAN" "$INJ" "@" "a]b" >/dev/null 2>&1)
check "cartella con \$(...), path relativo -> exit 3" 3 $?
(cd "$OUTSIDE" && bash "$SCAN" . >/dev/null 2>&1)
check "cartella con \$(...), scan con . -> exit 3" 3 $?
(cd "$OUTSIDE" && bash "$SCAN" "$OUTSIDE" >/dev/null 2>&1)
check "cartella con \$(...), path assoluto -> exit 3" 3 $?
OUT="$(find "$OUTSIDE" "$R" -name PWNED)"
check "nessun comando eseguito dal nome della cartella" "" "$OUT"
rm -rf "$OUTSIDE"

echo "=== scanner: lotti di argomenti ed errori di grep ==="
BD="$WORK/lotti"
mkdir -p "$BD"
for i in 1 2 3 4 5 6; do printf 'pulito %s\n' "$i" > "$BD/f$i.txt"; done
SECRET_SCAN_BATCH_BYTES=1 bash "$SCAN" "$BD" >/dev/null 2>&1
check "un file per lotto, nessun match -> exit 0" 0 $?
printf 'k = "%s"\n' "$VN" > "$BD/f4.txt"
OUT="$(cd "$BD" && SECRET_SCAN_BATCH_BYTES=1 bash "$SCAN" . 2>&1)"
check "un file per lotto, match in un solo lotto -> exit 3" 3 $?
check "un file per lotto: output" "./f4.txt:1:OPENAI_KEY" "$OUT"
printf 'pulito\n' > "$BD/f4.txt"

# grep o find che falliscono non sono mai un falso pulito. Il grep finto fallisce
# solo sulla chiamata indicata e passa le altre al grep vero.
REAL_GREP="$(command -v grep)"
STUB="$WORK/stub"
mkdir -p "$STUB"
cat > "$STUB/grep" <<EOF
#!/bin/bash
case " \$* " in
    *" \$STUB_GREP_FAIL_ON "*) echo "grep: finto errore" >&2; exit 2 ;;
esac
exec "$REAL_GREP" "\$@"
EOF
chmod +x "$STUB/grep"
PATH="$STUB:$PATH" STUB_GREP_FAIL_ON="-IcHZ" bash "$SCAN" "$BD" >/dev/null 2>&1
check "grep fallito nel controllo dei NUL -> exit 2" 2 $?
PATH="$STUB:$PATH" STUB_GREP_FAIL_ON="-nHEa" bash "$SCAN" "$BD" >/dev/null 2>&1
check "grep fallito su una regola -> exit 2" 2 $?
rm -f "$STUB/grep"
printf '#!/bin/bash\nexit 1\n' > "$STUB/find"
chmod +x "$STUB/find"
PATH="$STUB:$PATH" bash "$SCAN" "$BD" >/dev/null 2>&1
check "find fallito -> exit 2" 2 $?
rm -f "$STUB/find"
bash "$SCAN" "$WORK/non-esiste" >/dev/null 2>&1
check "nessun path esistente -> exit 2" 2 $?
rm -rf "$BD"

# Molti file, senza forzare i lotti. Su Linux la riga di comando unica supererebbe
# i 2 MB ("Argument list too long"); su Git Bash creare e leggere file costa molto,
# quindi meno file (lì il limite non scatta: il caso resta come prova dei lotti).
case "${OSTYPE:-}" in
    msys*|cygwin*) MANY=1500; PAD="" ;;
    *) MANY=9000; PAD="$(printf 'n%.0s' {1..220})" ;;
esac
MD="$WORK/molti"
mkdir -p "$MD"
for ((i = 0; i < MANY; i++)); do
    printf 'pulito\n' > "$MD/$PAD-$i.txt"
done
bash "$SCAN" "$MD" >/dev/null 2>&1
check "$MANY file puliti -> exit 0" 0 $?
printf 'k = "%s"\n' "$VN" > "$MD/$PAD-$((MANY - 1)).txt"
bash "$SCAN" "$MD" >/dev/null 2>&1
check "$MANY file, secret nell'ultimo -> exit 3" 3 $?
rm -rf "$MD"

echo "=== scanner: NUL come confine, UTF-32, NUL dopo molto testo ==="
{ printf 'abc\000%s\n' "$VN"; } > "$R/confine.dat"
OUT="$(bash "$SCAN" "$R/confine.dat" 2>&1)"
check "NUL subito prima del secret -> exit 3" 3 $?
check "NUL subito prima del secret: output" "confine.dat:1:OPENAI_KEY" "$OUT"
rm -f "$R/confine.dat"
if command -v iconv >/dev/null 2>&1; then
    { printf '\377\376\000\000'; printf 'riga\nk = "%s"\n' "$VN" | iconv -f UTF-8 -t UTF-32LE; } > "$R/u32le.txt"
    OUT="$(bash "$SCAN" "$R/u32le.txt" 2>&1)"
    check "UTF-32LE con BOM e secret -> exit 3" 3 $?
    check "UTF-32LE con BOM: output" "u32le.txt:2:OPENAI_KEY" "$OUT"
    { printf '\000\000\376\377'; printf 'riga\nk = "%s"\n' "$VN" | iconv -f UTF-8 -t UTF-32BE; } > "$R/u32be.txt"
    OUT="$(bash "$SCAN" "$R/u32be.txt" 2>&1)"
    check "UTF-32BE con BOM: output" "u32be.txt:2:OPENAI_KEY" "$OUT"
    { printf '\377\376\000\000'; printf 'tutto pulito\n' | iconv -f UTF-8 -t UTF-32LE; } > "$R/u32clean.txt"
    bash "$SCAN" "$R/u32clean.txt" >/dev/null 2>&1
    check "UTF-32 senza secret -> exit 0" 0 $?
    printf 'riga\nk = "%s"\n' "$VN" | iconv -f UTF-8 -t UTF-32LE > "$R/u32nobom.txt"
    bash "$SCAN" "$R/u32nobom.txt" >/dev/null 2>&1
    check "UTF-32LE senza BOM e secret -> exit 3" 3 $?
    printf 'riga\nk = "%s"\n' "$VN" | iconv -f UTF-8 -t UTF-16BE > "$R/u16be.txt"
    bash "$SCAN" "$R/u16be.txt" >/dev/null 2>&1
    check "UTF-16BE senza BOM e secret -> exit 3" 3 $?
    # La riga 1 è ASCII da 200 KB: il primo NUL sta ben oltre la prima riga.
    { head -c 200000 /dev/zero | LC_ALL=C tr '\000' 'a'; printf '\n'
      printf 'k = "%s"\n' "$VN" | iconv -f UTF-8 -t UTF-16LE; } > "$R/coda.log"
    OUT="$(bash "$SCAN" "$R/coda.log" 2>&1)"
    check "200 KB ASCII e coda UTF-16 con secret -> exit 3" 3 $?
    check "200 KB ASCII e coda UTF-16: output" "coda.log:2:OPENAI_KEY" "$OUT"
    rm -f "$R"/u32*.txt "$R/u16be.txt" "$R/coda.log"
fi

echo "=== scanner: binari ==="
BEGIN_PEM='-----BEG''IN PRIVATE KEY-----'
# Una DLL contiene davvero stringhe del genere. Estensione nota, anche maiuscola.
{ printf 'MZ\220\000\003\000'; printf '%s\n' "$BEGIN_PEM"; } > "$R/lib.bin"
bash "$SCAN" "$R/lib.bin" >/dev/null 2>&1
check "DLL rinominata .bin -> exit 0" 0 $?
for n in x.BIN x.Jar x.wasm x.DOCX x.DLL; do
    printf 'k = "%s"\n' "$VN" > "$R/$n"
    bash "$SCAN" "$R/$n" >/dev/null 2>&1
    check "estensione binaria $n -> saltato" 0 $?
    rm -f "$R/$n"
done
rm -f "$R/lib.bin"
# Estensione ignota: decide la firma in testa al file.
sig_case() {   # sig_case <etichetta> <firma per printf>
    { printf "$2"; printf '\000%s\n' "$BEGIN_PEM"; } > "$R/ignoto.dat"
    bash "$SCAN" "$R/ignoto.dat" >/dev/null 2>&1
    check "firma $1, estensione ignota -> saltato" 0 $?
    rm -f "$R/ignoto.dat"
}
sig_case PE 'MZ\220\000'
sig_case ELF '\177ELF'
sig_case zip 'PK\003\004'
sig_case wasm '\000asm'
# Non sono binari: niente firma, o testo che ci assomiglia.
printf 'k = "%s"\n' "$VN" > "$R/bin"
bash "$SCAN" "$R/bin" >/dev/null 2>&1
check "file di nome 'bin', senza estensione -> exit 3" 3 $?
rm -f "$R/bin"
{ printf 'MZ note\000\n'; printf 'k = "%s"\n' "$VN"; } > "$R/mz.dat"
bash "$SCAN" "$R/mz.dat" >/dev/null 2>&1
check "testo che inizia per MZ, con NUL e secret -> exit 3" 3 $?
rm -f "$R/mz.dat"
if command -v iconv >/dev/null 2>&1; then
    printf 'MZ riga\nk = "%s"\n' "$VN" | iconv -f UTF-8 -t UTF-16LE > "$R/mz16.dat"
    bash "$SCAN" "$R/mz16.dat" >/dev/null 2>&1
    check "UTF-16 senza BOM che inizia per MZ -> exit 3" 3 $?
    rm -f "$R/mz16.dat"
fi

echo "=== scanner: perimetro della prosa fuori da un repo ==="
OD="$WORK/fuori2"
mkdir -p "$OD/wiki/projects" "$OD/raw" "$OD/project-memories" "$OD/docs"
printf -- '- Password: %s\n' "$PW" > "$OD/wiki/projects/x.md"
OUT="$(cd "$OD" && bash "$SCAN" . 2>&1)"
check "scan con .: wiki/projects" "./wiki/projects/x.md:1:SECRET_ASSIGNMENT_PROSE" "$OUT"
OUT="$(cd "$OD/wiki/projects" && bash "$SCAN" . 2>&1)"
check "scan con . dentro wiki/projects" "./x.md:1:SECRET_ASSIGNMENT_PROSE" "$OUT"
OUT="$(bash "$SCAN" "$OD/wiki/projects/x.md" 2>&1)"
check "path assoluto: wiki/projects" "$OD/wiki/projects/x.md:1:SECRET_ASSIGNMENT_PROSE" "$OUT"
rm -f "$OD/wiki/projects/x.md"
printf -- '- Password: %s\n' "$PW" > "$OD/raw/s.md"
OUT="$(cd "$OD" && bash "$SCAN" . 2>&1)"
check "scan con .: raw" "./raw/s.md:1:SECRET_ASSIGNMENT_PROSE" "$OUT"
OUT="$(bash "$SCAN" "$OD/raw/s.md" 2>&1)"
check "path assoluto: raw" "$OD/raw/s.md:1:SECRET_ASSIGNMENT_PROSE" "$OUT"
rm -f "$OD/raw/s.md"
printf -- '- Password: %s\n' "$PW" > "$OD/project-memories/n.md"
OUT="$(cd "$OD" && bash "$SCAN" . 2>&1)"
check "scan con .: project-memories" "./project-memories/n.md:1:SECRET_ASSIGNMENT_PROSE" "$OUT"
rm -f "$OD/project-memories/n.md"
printf -- '- Password: %s\n' "$PW" > "$OD/docs/n.md"
(cd "$OD" && bash "$SCAN" . >/dev/null 2>&1)
check "scan con .: fuori perimetro -> exit 0" 0 $?
bash "$SCAN" "$OD/docs/n.md" >/dev/null 2>&1
check "path assoluto: fuori perimetro -> exit 0" 0 $?
rm -rf "$OD"

echo "=== scanner: report di gitleaks e segnali (gitleaks finto) ==="
FAKE="$WORK/fake"
TD="$WORK/tmpd"
GD="$WORK/glsrc"
mkdir -p "$FAKE" "$TD" "$GD"
printf 'pulito\n' > "$GD/a.txt"
GL_LOG="$WORK/gitleaks.log"
cat > "$FAKE/gitleaks" <<'EOF'
#!/bin/bash
while [[ $# -gt 0 ]]; do
    [[ "$1" == "--report-path" ]] && REPORT="$2"
    shift
done
printf '[]' > "$REPORT"
printf '%s\n' "$REPORT" >> "$GL_LOG"
sleep "${GL_SLEEP:-0}"
EOF
chmod +x "$FAKE/gitleaks"
export GL_LOG
PATH="$FAKE:$PATH" TMPDIR="$TD" bash "$SCAN" "$GD" >/dev/null 2>&1
check "con gitleaks finto, cartella pulita -> exit 0" 0 $?
case "$(cat "$GL_LOG")" in
    */gitleaks-report.json) ok "report di gitleaks dentro la cartella di lavoro" ;;
    *) bad "report di gitleaks fuori dalla cartella di lavoro" ;;
esac
check "cartella di lavoro rimossa a fine scan" "" "$(ls -A "$TD")"
: > "$GL_LOG"
PATH="$FAKE:$PATH" TMPDIR="$TD" GL_SLEEP=2 bash "$SCAN" "$GD" >/dev/null 2>&1 &
SCAN_PID=$!
for ((i = 0; i < 300; i++)); do
    [[ -s "$GL_LOG" ]] && break
    sleep 0.1
done
kill -TERM "$SCAN_PID" 2>/dev/null
wait "$SCAN_PID"
check "TERM durante gitleaks -> exit 143" 143 $?
check "TERM: cartella di lavoro e report rimossi" "" "$(ls -A "$TD")"
unset GL_LOG
rm -rf "$FAKE" "$TD" "$GD"

echo "=== hook pre-commit (repo git temporaneo) ==="
G="$WORK/repo2"
make_repo "$G"
SCAN_G="$G/scripts/lib/secret-scan.sh"
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

# Gitlink (submodule) in staging: nessun file da leggere, va saltato, non exit 2.
# Il commit del submodule non esiste in questo repo: git show fallirebbe.
git -C "$G" update-index --add --cacheinfo "160000,0123456789abcdef0123456789abcdef01234567,sub"
(cd "$G" && bash "$SCAN_G" --repo "$G" --staged >/dev/null 2>&1)
check "--staged con un gitlink -> exit 0" 0 $?
printf 'k = "%s"\n' "$VALUE3" > "$G/conlink.txt"
git -C "$G" add conlink.txt
OUT="$(cd "$G" && bash "$SCAN_G" --repo "$G" --staged 2>/dev/null)"
check "--staged con gitlink e secret -> exit 3" 3 $?
check "--staged con gitlink e secret: output" "conlink.txt:1:OPENAI_KEY" "$OUT"
git -C "$G" reset -q >/dev/null 2>&1
rm -f "$G/conlink.txt"

# Rename e cambio di tipo restano scansionati.
printf 'pulito\n' > "$G/old.txt"
git -C "$G" add old.txt
git -C "$G" commit -q -m "base" >/dev/null 2>&1
printf 'k = "%s"\n' "$VALUE3" > "$G/old.txt"
git -C "$G" mv old.txt new.txt
git -C "$G" add new.txt
OUT="$(cd "$G" && bash "$SCAN_G" --repo "$G" --staged 2>/dev/null)"
check "--staged, rename con secret: output" "new.txt:1:OPENAI_KEY" "$OUT"
git -C "$G" reset -q --hard >/dev/null 2>&1

echo ""
echo "Totale: $PASS ok, $FAIL falliti"
[[ $FAIL -eq 0 ]]
