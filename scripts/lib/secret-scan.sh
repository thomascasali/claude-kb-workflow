#!/bin/bash
# ============================================================================
# scripts/lib/secret-scan.sh — scanner anti-secret, BLOCCANTE
# ============================================================================
#
# Uso:
#   secret-scan.sh [--repo DIR] [--staged] [--rel-root DIR [--rel-prefix P]]
#                  <file|dir...>
#
#   --repo DIR    Repo di riferimento (allowlist e path relativi). Default: il
#                 repo che contiene questo script (due livelli sopra lib/).
#   --staged      Ignora gli argomenti posizionali: scansiona il CONTENUTO IN
#                 STAGING (indice git) dei file staged nel repo git della
#                 directory corrente. Pensato per .githooks/pre-commit.
#   --rel-root DIR
#                 I path scanditi sotto DIR vengono riportati (e cercati in
#                 allowlist) come "<rel-prefix><path relativo a DIR>". Serve per
#                 cartelle temporanee fuori da un repo, il cui nome casuale
#                 altrimenti finirebbe nel path e nessuna voce di allowlist
#                 potrebbe mai combaciare.
#   --rel-prefix PREFIX
#                 Prefisso per --rel-root (default: vuoto). Ignorato senza
#                 --rel-root.
#   <file|dir>    Path da scandire (le directory in modo ricorsivo). Richiesti
#                 se non si passa --staged.
#
# Contratto (non cambiare senza aggiornare i chiamanti):
#   exit 0  nessun secret trovato.
#   exit 3  almeno un secret trovato (dopo allowlist). Su stdout UNA riga per
#           ritrovamento, nel formato esatto
#               file:riga:REGOLA
#           MAI il valore trovato, MAI il contenuto della riga.
#   exit 2  errore d'uso o d'ambiente (argomenti mancanti, regole illeggibili,
#           find o grep falliti su un file o per troppi argomenti): mai un falso
#           "pulito" su qualcosa che non si è riusciti a leggere.
#
# Regole: secret-patterns.txt (formato nell'intestazione di quel file).
# Scope per path: secret-scope.txt (override: variabile SECRET_SCOPE_FILE).
#
# Allowlist dei falsi positivi: "<repo>/.secret-allowlist", una voce per riga:
#     path/relativo/al/repo:REGOLA:sha256(contenuto_della_riga)
# L'hash è della riga intera e non viene mai stampato dallo scanner: calcolalo
# a parte (vedi CONTRIBUTING.md). Vengono caricati l'allowlist del repo di
# riferimento, quella del repo dell'invocazione (con --staged) e quella
# dell'eventuale secondo repo SECRET_SCAN_EXTRA_REPO. La variabile
# SECRET_ALLOWLIST, se impostata, è un override assoluto: è l'UNICO file
# caricato. Il path è relativo alla radice del repo git del file; per un file
# fuori da qualsiasi repo e senza --rel-root è il path come passato.
#
# Lettura dei file: grep in modalità testo (-a), a lotti di argomenti (una riga
# di comando unica supererebbe il limite del sistema con molti file). I file con
# un byte NUL in qualunque punto sono scansionati su copie normalizzate: vedi la
# sezione "file con byte NUL". Saltati: estensioni binarie note (senza distinzione
# di maiuscole) e firme binarie certe in testa al file. I path possono contenere
# ":" o iniziare per "-". Scope e allowlist tollerano CR finali e l'assenza del
# newline finale.
#
# Se `gitleaks` è nel PATH viene eseguito come livello aggiuntivo sugli
# argomenti che sono directory (best-effort: un suo fallimento dà un WARN).
#
# Note di implementazione: scritto per bash 4+ (array associativi, ${x,,}),
# provato solo sulle versioni elencate in CONTRIBUTING.md.
# Usa pipe invece di process substitution annidate, che su Git Bash/MSYS
# possono bloccarsi, e scrive i risultati in variabili globali invece di usare
# $(...) nelle funzioni chiamate per ogni file (una subshell per file è lenta
# e vanifica le cache).
# ============================================================================

set -u

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$_SCRIPT_DIR/common.sh"

PATTERNS_FILE="$_SCRIPT_DIR/secret-patterns.txt"

common_parse_args "$@" || exit 2
set -- ${COMMON_REMAINING_ARGS[@]+"${COMMON_REMAINING_ARGS[@]}"}

STAGED=0
REL_ROOT=""
REL_PREFIX=""
TARGETS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --staged)     STAGED=1; shift ;;
        --rel-root)
            [[ $# -ge 2 ]] || { log_fail "--rel-root richiede un argomento"; exit 2; }
            REL_ROOT="$2"; shift 2 ;;
        --rel-root=*) REL_ROOT="${1#--rel-root=}"; shift ;;
        --rel-prefix)
            [[ $# -ge 2 ]] || { log_fail "--rel-prefix richiede un argomento"; exit 2; }
            REL_PREFIX="$2"; shift 2 ;;
        --rel-prefix=*) REL_PREFIX="${1#--rel-prefix=}"; shift ;;
        --)       shift; TARGETS+=("$@"); break ;;
        -*)       log_fail "opzione sconosciuta: $1"; exit 2 ;;
        *)        TARGETS+=("$1"); shift ;;
    esac
done

# "-v NOME" + assegnazione separata, non "${NOME:-default}": quest'ultima
# forma si auto-matcherebbe come SECRET_ASSIGNMENT (il nome contiene "SECRET")
# quando lo scanner scandisce se stesso.
SCOPE_FILE="$_SCRIPT_DIR/secret-scope.txt"
[[ -v SECRET_SCOPE_FILE ]] && [[ -n "$SECRET_SCOPE_FILE" ]] && SCOPE_FILE="$SECRET_SCOPE_FILE"

if [[ ! -f "$PATTERNS_FILE" ]]; then
    log_fail "regole non trovate: $PATTERNS_FILE"
    exit 2
fi

# Estensioni di binari da saltare senza aprirli. Confronto in minuscolo su una
# mappa: costo costante per file, anche su decine di migliaia di file.
declare -A _BINARY_EXT=()
for _ext in \
    png jpg jpeg gif webp ico bmp tif tiff heic avif psd \
    pdf doc docx xls xlsx ppt pptx odt ods odp \
    zip gz tgz bz2 xz tar 7z rar jar war ear apk aab ipa deb rpm dmg iso msi \
    exe dll so dylib bin o a lib obj pdb wasm class pyc \
    woff woff2 ttf otf eot \
    mp4 mp3 mov avi mkv webm wav flac ogg aac m4a \
    sqlite sqlite3 db; do
    _BINARY_EXT["$_ext"]=1
done
_MAX_BYTES=10485760   # 10MB: oltre, si salta con un WARN.

# File "meta" dello scanner: contengono per forza i nomi delle regole e delle
# parole chiave seguiti da un separatore, e si auto-matcherebbero. Esclusi
# sempre, per basename.
_META_BASENAMES=('.secret-allowlist' '.secret-allowlist.example' 'secret-patterns.txt' 'secret-scope.txt')

is_binary_skip_cheap() {
    local base="${1##*/}" m ext
    for m in "${_META_BASENAMES[@]}"; do
        [[ "$base" == "$m" ]] && return 0
    done
    [[ "$base" == *.* ]] || return 1
    ext="${base##*.}"
    [[ -n "${_BINARY_EXT[${ext,,}]+x}" ]]
}

# Versione completa (basename + dimensione): solo per pochi file, mai in un
# loop su migliaia (un `wc -c` per file è lento su Git Bash/Windows).
is_binary_skip() {
    local f="$1" size
    is_binary_skip_cheap "$f" && return 0
    size=$(wc -c < "$f" 2>/dev/null || echo 0)
    if [[ "$size" -gt "$_MAX_BYTES" ]]; then
        log_warn "saltato (>10MB): $f"
        return 0
    fi
    return 1
}

# Espande i target in una lista piatta di file, saltando .git/ e i binari.
# Un solo `find` per tutti i target, filtro dimensione nativo.
expand_targets() {
    local existing=() t
    for t in "${TARGETS[@]}"; do
        if [[ -e "$t" ]]; then
            # Un nome che inizia per "-" verrebbe letto da find come opzione.
            [[ "$t" == -* ]] && t="./$t"
            existing+=("$t")
        else
            log_warn "non trovato, saltato: $t"
        fi
    done
    if [[ "${#existing[@]}" -eq 0 ]]; then
        log_fail "nessuno dei path indicati esiste"
        exit 2
    fi

    # Su file, non in pipe: l'exit code di find non va perso (una cartella
    # illeggibile non è "nessun secret").
    if ! find "${existing[@]}" -type f -not -path '*/.git/*' -size +10M -print0 \
            > "$WORK_TMP/big.list" 2> "$WORK_TMP/find.err" \
        || ! find "${existing[@]}" -type f -not -path '*/.git/*' -not -size +10M -print0 \
            > "$WORK_TMP/found.list" 2> "$WORK_TMP/find.err"; then
        log_fail "find fallito, scansione incompleta: $(head -n 3 "$WORK_TMP/find.err")"
        exit 2
    fi
    while IFS= read -r -d '' big; do
        log_warn "saltato (>10MB): $big"
    done < "$WORK_TMP/big.list"
    while IFS= read -r -d '' f; do
        is_binary_skip_cheap "$f" || printf '%s\0' "$f"
    done < "$WORK_TMP/found.list"
}

# Path relativo alla radice del repo che contiene $1. Il risultato va in
# _RELPATH_RESULT (globale), il path su cui provare i glob di scope in
# _SCOPEPATH_RESULT: coincidono, salvo per un file fuori da ogni repo, che si
# stampa come passato ma si confronta col path assoluto (così anche una
# scansione con "." aggancia i glob "*/..."). Chiamare come comando semplice,
# MAI con $(...)
# (una subshell perderebbe le cache). Memoizza per directory la forma assoluta
# e la toplevel git; per i file sotto REPO_DIR / EXTRA_REPO_DIR / --rel-root il
# relativo è una pura sottrazione di prefisso, senza invocare git.
declare -A _ABSDIR_CACHE _TOPLEVEL_CACHE
_RELPATH_RESULT=""
_SCOPEPATH_RESULT=""

_looks_absolute_clean() {
    # "/..." (unix) o "X:/..." (Windows), senza segmenti "." / ".." da risolvere.
    case "$1" in
        /*|[A-Za-z]:/*) ;;
        *) return 1 ;;
    esac
    case "$1" in
        */.|*/..|*/./*|*/../*) return 1 ;;
    esac
    return 0
}

# Radici note, risolte una sola volta nella stessa forma (`cd + pwd`) che
# useranno i file, così il confronto per prefisso combacia byte per byte
# ("D:/..." vs "/d/..." sotto MSYS).
_REPO_DIR_ABS="$(cd "$REPO_DIR" 2>/dev/null && pwd)"
_EXTRA_REPO_ABS=""
[[ -n "$EXTRA_REPO_DIR" ]] && _EXTRA_REPO_ABS="$(cd "$EXTRA_REPO_DIR" 2>/dev/null && pwd)"
_EXTRA_ROOT_ABS=""
if [[ -n "$REL_ROOT" ]]; then
    _EXTRA_ROOT_ABS="$(cd "$REL_ROOT" 2>/dev/null && pwd)" || {
        log_fail "--rel-root: cartella non trovata: $REL_ROOT"; exit 2; }
fi

rel_path_for() {
    local f="$1" filebase filedir absdir abs top known

    if _looks_absolute_clean "$f"; then
        abs="$f"
    else
        filebase="${f##*/}"
        filedir="${f%/*}"
        [[ "$filedir" == "$f" ]] && filedir="."   # nessuna "/" nel path dato
        # ${a[$k]+x}, non [[ -v a[$k] ]]: su bash 5.1 -v rivaluta il nome e
        # eseguirebbe un $(...) contenuto nel nome di una cartella.
        if [[ -n "${_ABSDIR_CACHE[$filedir]+x}" ]]; then
            absdir="${_ABSDIR_CACHE[$filedir]}"
        else
            absdir="$(cd -- "$filedir" 2>/dev/null && pwd)"
            _ABSDIR_CACHE["$filedir"]="$absdir"
        fi
        abs="$absdir/$filebase"
    fi

    # --rel-root esplicito: priorità massima.
    if [[ -n "$_EXTRA_ROOT_ABS" && "$abs" == "$_EXTRA_ROOT_ABS"/* ]]; then
        _RELPATH_RESULT="${REL_PREFIX}${abs#"$_EXTRA_ROOT_ABS"/}"
        _SCOPEPATH_RESULT="$_RELPATH_RESULT"
        return 0
    fi

    # Repo noti: nessun git per il caso comune.
    for known in "$_REPO_DIR_ABS" "$_EXTRA_REPO_ABS"; do
        if [[ -n "$known" && "$abs" == "$known"/* ]]; then
            _RELPATH_RESULT="${abs#"$known"/}"
            _SCOPEPATH_RESULT="$_RELPATH_RESULT"
            return 0
        fi
    done

    # Altrove: chiedi a git (memoizzato per directory).
    absdir="${abs%/*}"
    if [[ -n "${_TOPLEVEL_CACHE[$absdir]+x}" ]]; then
        top="${_TOPLEVEL_CACHE[$absdir]}"
    else
        top="$(git -C "$absdir" rev-parse --show-toplevel 2>/dev/null)" || true
        if [[ -n "${top:-}" ]]; then
            top="$(cd "$top" 2>/dev/null && pwd)" || top=""
        fi
        _TOPLEVEL_CACHE["$absdir"]="$top"
    fi
    if [[ -n "${top:-}" ]]; then
        _RELPATH_RESULT="${abs#"$top"/}"
        _SCOPEPATH_RESULT="$_RELPATH_RESULT"
    else
        _RELPATH_RESULT="$f"
        _SCOPEPATH_RESULT="$abs"
    fi
}

# --- filtri anti-segnaposto --------------------------------------------------
looks_like_placeholder() {
    local v="$1" lv
    lv="${1,,}"   # minuscolo, espansione pura (niente subprocess)
    case "$v" in
        '') return 0 ;;
        '""'|"''") return 0 ;;
    esac
    # Un secret vero è lungo: sotto 8 caratteri è quasi certamente un
    # segnaposto corto o un valore innocuo.
    [[ "${#v}" -lt 8 ]] && return 0
    # Un secret vero non inizia mai con questi caratteri: espansione di
    # variabile/template (${...}, $VAR, %VAR%), segnaposto angolare (<...>),
    # enfasi markdown, parentesi.
    case "${v:0:1}" in
        '`'|'*'|'('|'$'|'<'|'%'|'{') return 0 ;;
    esac
    [[ "$lv" =~ ^x+$ ]] && return 0
    [[ "$v"  =~ ^\*+$ ]] && return 0
    [[ "$v"  =~ ^\.+$ ]] && return 0
    # "..." anche come suffisso: convenzione per troncare un esempio.
    [[ "$v" == *...* ]] && return 0
    # Un valore con "(" o "[" è quasi certamente un frammento di codice
    # (os.environ.get(, response.data[, z.string().min(8)), non un secret.
    case "$v" in
        *'('*|*'['*) return 0 ;;
    esac
    # Idiomi "leggi il secret dall'ambiente": il valore vero non è nel codice.
    case "$v" in
        os.environ*|process.env*|os.getenv*|System.getenv*|getenv\(*) return 0 ;;
    esac
    # Redazione a base di soli "#" o "-".
    [[ "$v" =~ ^[#-]+$ ]] && return 0
    case "$lv" in
        changeme|change_me|change-me) return 0 ;;
        your_*|your-*) return 0 ;;
        example|example_*|example-*) return 0 ;;
        sample|sample_*|sample-*) return 0 ;;
        replace|replace_*|replaceme|replace-me) return 0 ;;
        todo|fixme) return 0 ;;
        null|none|n\/a|na) return 0 ;;
        *) return 1 ;;
    esac
}

# Per le regole di FORMATO (flag FMTPLACEHOLDER: GOOGLE_API_KEY,
# URL_WITH_CREDENTIALS) non c'è un valore isolabile: si guarda la riga intera
# cercando segnali forti di segnaposto (6+ X/x consecutive, "{" o "<").
# Falso negativo possibile (un secret vero su una riga con anche "<" o "{"):
# compromesso accettato.
looks_like_format_placeholder_line() {
    local c="$1"
    [[ "$c" =~ [Xx]{6,} ]] && return 0
    [[ "$c" == *'{'* ]] && return 0
    [[ "$c" == *'<'* ]] && return 0
    return 1
}

# Estrae il "valore" (token singolo, senza spazi) di un match SECRET_ASSIGNMENT,
# spogliato della virgoletta di apertura. Solo per il filtro placeholder: non
# va mai stampato. Scrive in _EXTRACT_RESULT (globale, mai $(...)).
# Le tre regex rispecchiano le tre forme della regola in secret-patterns.txt
# (env MAIUSCOLO / chiave minuscola tra virgolette / chiave YAML a inizio
# riga); la parola chiave è un segmento intero delimitato da "_". Gli indici
# dei gruppi: 5 per ENV (1=confine, 2=prefisso, 3=keyword, 4=suffisso,
# 5=valore), 4 per JSON e YAML.
_SECASSIGN_RE_ENV="(^|[^A-Za-z0-9])([A-Z0-9]+_)*(PASSWORD|PASSWD|SECRET|TOKEN|API_?KEY|PRIVATE_KEY)(_[A-Z0-9]+)*[[:space:]]*[:=][[:space:]]*[\"']?([^[:space:]\"']+)"
_SECASSIGN_RE_JSON="\"([a-z0-9]+_)*(password|passwd|secret|token|api_?key|private_key)(_[a-z0-9]+)*\"[[:space:]]*:[[:space:]]*[\"']?([^[:space:]\"',]+)"
_SECASSIGN_RE_YAML="^[[:space:]]*([a-z0-9]+_)*(password|passwd|secret|token|api_?key|private_key)(_[a-z0-9]+)*:[[:space:]]+[\"']?([^[:space:]\"']+)"
# Forma della regola SECRET_ASSIGNMENT_PROSE (case-insensitive), provata solo
# come ultimo fallback.
_SECASSIGN_RE_PROSE="(password|passwd|pwd|secret|token|api[ _-]?key|client[ _-]?secret|private[ _-]?key)[A-Za-z0-9 '-]{0,20}(:|=|[[:space:]]è[[:space:]]|[[:space:]]e'[[:space:]]|[[:space:]]is[[:space:]])[[:space:]]*[\"'\`]?([^[:space:]\"'\`]+)"

_EXTRACT_RESULT=""
extract_assignment_value() {
    local line="$1" v=""
    if [[ "$line" =~ $_SECASSIGN_RE_ENV ]]; then
        v="${BASH_REMATCH[5]}"
    elif [[ "$line" =~ $_SECASSIGN_RE_JSON ]]; then
        v="${BASH_REMATCH[4]}"
    elif [[ "$line" =~ $_SECASSIGN_RE_YAML ]]; then
        v="${BASH_REMATCH[4]}"
    else
        # Fallback PROSE, case-insensitive: nocasematch solo per questo
        # confronto, poi ripristinato (le forme sopra restano case-sensitive).
        local _nocase_was_on=0
        shopt -q nocasematch && _nocase_was_on=1
        shopt -s nocasematch
        if [[ "$line" =~ $_SECASSIGN_RE_PROSE ]]; then
            v="${BASH_REMATCH[3]}"
        fi
        [[ "$_nocase_was_on" -eq 0 ]] && shopt -u nocasematch
        if [[ -z "$v" ]]; then
            # Non dovrebbe succedere: fallback innocuo (tutto dopo il primo
            # separatore) perché un valore vuoto sarebbe un falso "è un
            # segnaposto, scarta".
            v="${line#*[:=]}"
            v="${v#"${v%%[![:space:]]*}"}"
        fi
    fi
    v="${v%\"}"; v="${v%\'}"
    _EXTRACT_RESULT="$v"
}

is_allowlisted() {
    local path="$1" rule="$2" hash="$3" key="${1}:${2}"
    local set="${_ALLOW[$key]:-}"
    [[ -z "$set" ]] && return 1
    local h
    for h in $set; do
        [[ "$h" == "$hash" ]] && return 0
    done
    return 1
}

# --- scope (esclusioni/inclusioni REGOLA per glob di path) -------------------
# Formato in secret-scope.txt. Due azioni: EXCLUDE (la regola non scatta sotto
# il glob) e INCLUDE_ONLY (la regola scatta SOLO sotto il glob; una regola con
# almeno una riga INCLUDE_ONLY è disattivata ovunque altrove).
declare -a SCOPE_GLOBS=() SCOPE_RULES=() SCOPE_ACTIONS=()
declare -A RESTRICTED_RULES=()   # regola -> 1 se ha almeno una riga INCLUDE_ONLY
if [[ -f "$SCOPE_FILE" ]]; then
    while IFS=$'\t' read -r sc_glob sc_action sc_rule || [[ -n "$sc_glob" ]]; do
        sc_rule="${sc_rule%$'\r'}"; sc_action="${sc_action%$'\r'}"; sc_glob="${sc_glob%$'\r'}"
        [[ -z "$sc_glob" || "$sc_glob" == \#* ]] && continue
        case "$sc_action" in
            EXCLUDE|INCLUDE_ONLY) ;;
            *) continue ;;
        esac
        SCOPE_GLOBS+=("$sc_glob")
        SCOPE_RULES+=("$sc_rule")
        SCOPE_ACTIONS+=("$sc_action")
        [[ "$sc_action" == "INCLUDE_ONLY" ]] && RESTRICTED_RULES["$sc_rule"]=1
    done < "$SCOPE_FILE"
fi

# Vero se un EXCLUDE per <regola> combacia con <path>, oppure se la regola è
# "a perimetro ristretto" e nessun INCLUDE_ONLY combacia.
is_rule_excluded_for_path() {
    local path="$1" rule="$2" i included=0
    for i in "${!SCOPE_GLOBS[@]}"; do
        [[ "${SCOPE_RULES[$i]}" == "$rule" ]] || continue
        # shellcheck disable=SC2053
        if [[ "$path" == ${SCOPE_GLOBS[$i]} ]]; then
            [[ "${SCOPE_ACTIONS[$i]}" == "EXCLUDE" ]] && return 0
            [[ "${SCOPE_ACTIONS[$i]}" == "INCLUDE_ONLY" ]] && included=1
        fi
    done
    if [[ -n "${RESTRICTED_RULES[$rule]:-}" && "$included" -eq 0 ]]; then
        return 0
    fi
    return 1
}

# --- regole (TAB-separated: NOME<TAB>REGEX<TAB>FLAG) -------------------------
declare -a RULE_NAMES=() RULE_REGEX=() RULE_FLAGS=()
_RULES_RAW="$(grep -vE '^[[:space:]]*(#|$)' "$PATTERNS_FILE")"
_RULES_RAW="${_RULES_RAW//$'\r'/}"   # file regole salvato con CRLF
while IFS=$'\t' read -r name regex flags; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    RULE_NAMES+=("$name")
    RULE_REGEX+=("$regex")
    RULE_FLAGS+=("${flags:-}")
done <<< "$_RULES_RAW"

if [[ "${#RULE_NAMES[@]}" -eq 0 ]]; then
    log_fail "nessuna regola caricata da $PATTERNS_FILE"
    exit 2
fi

FINDINGS=()   # "path:riga:regola"
STAGED_TMPDIR=""
REPO_TOP=""

# Cartella di lavoro unica (copie in staging, copie normalizzate, elenchi),
# rimossa all'uscita.
WORK_TMP="$(mktemp -d)" || { log_fail "impossibile creare una cartella temporanea"; exit 2; }
trap 'rm -rf "$WORK_TMP"' EXIT
# Senza questi, un segnale chiude la shell senza passare dal trap EXIT e la
# cartella (che può contenere copie dei file e il report di gitleaks) resta.
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

# REALPATHS[i] / REPORTPATHS[i]: file fisico da leggere / path da stampare e
# da usare come chiave dell'allowlist. Riempiti prima, così lo scan gira UNA
# volta per regola su tutti i file insieme (un grep per regola, non per coppia
# file-regola: ogni processo è costoso su Git Bash/Windows).
# _REPORTPATH_OF / _SCOPEPATH_OF: indicizzati per realpath (lookup O(1)).
declare -a REALPATHS=() REPORTPATHS=() SCOPEPATHS=()
declare -A _REPORTPATH_OF=() _SCOPEPATH_OF=()
add_target() {   # add_target <file da leggere> <path da stampare> [path per lo scope]
    local scope="${3:-$2}"
    REALPATHS+=("$1")
    REPORTPATHS+=("$2")
    SCOPEPATHS+=("$scope")
    _REPORTPATH_OF["$1"]="$2"
    _SCOPEPATH_OF["$1"]="$scope"
}

# --- grep a lotti ------------------------------------------------------------
# Limite prudente in byte per lotto. Linux ammette circa 2 MB per riga di comando.
# Su Git Bash grep (programma MSYS) ha retto 16 MB alla prova, ma ogni processo costa
# molto: lotti grandi. Un grep nativo Windows nel PATH (32 KB) darebbe un errore,
# quindi exit 2, non un falso pulito. Un ciclo in bash invece di xargs: xargs riassume
# in 123 sia "nessun match" (grep 1) sia "errore" (grep 2), qui l'exit code resta distinto.
_BATCH_BYTES=100000
case "${OSTYPE:-}" in msys*|cygwin*) _BATCH_BYTES=1000000 ;; esac
if [[ -v SECRET_SCAN_BATCH_BYTES ]] && [[ -n "$SECRET_SCAN_BATCH_BYTES" ]]; then
    _BATCH_BYTES="$SECRET_SCAN_BATCH_BYTES"   # solo per il collaudo
fi
declare -a _BATCH_START=() _BATCH_COUNT=()
make_batches() {
    local i=0 start=0 bytes=0 len p
    _BATCH_START=(); _BATCH_COUNT=()
    for p in "${REALPATHS[@]}"; do
        len=$(( ${#p} + 9 ))   # terminatore e puntatore dell'argomento
        if [[ "$i" -gt "$start" && $(( bytes + len )) -gt "$_BATCH_BYTES" ]]; then
            _BATCH_START+=("$start"); _BATCH_COUNT+=("$(( i - start ))")
            start="$i"; bytes=0
        fi
        bytes=$(( bytes + len ))
        i=$(( i + 1 ))
    done
    if [[ "$i" -gt "$start" ]]; then
        _BATCH_START+=("$start"); _BATCH_COUNT+=("$(( i - start ))")
    fi
}

# run_grep_batched <file output> <comando grep con opzioni...>
# Accoda a <file output> i risultati su tutti i REALPATHS. grep risponde 0 (match)
# o 1 (nessun match); da 2 in su (errore, argomenti troppi per exec) si esce con 2.
run_grep_batched() {
    local out="$1" b rc
    shift
    : > "$out"
    for b in "${!_BATCH_START[@]}"; do
        "$@" -- "${REALPATHS[@]:${_BATCH_START[$b]}:${_BATCH_COUNT[$b]}}" \
            >> "$out" 2> "$WORK_TMP/grep.err"
        rc=$?
        if [[ "$rc" -ge 2 ]]; then
            log_fail "grep fallito (exit $rc), scansione incompleta: $(head -n 3 "$WORK_TMP/grep.err")"
            exit 2
        fi
    done
}

if [[ "$STAGED" -eq 1 ]]; then
    REPO_TOP="$(git rev-parse --show-toplevel 2>/dev/null)"
    if [[ -z "$REPO_TOP" ]]; then
        log_fail "--staged richiede di essere in un repo git"
        exit 2
    fi
    STAGED_TMPDIR="$WORK_TMP/staged"
    STAGED_LIST_FILE="$WORK_TMP/staged.list"
    mkdir -p "$STAGED_TMPDIR"
    # -z + core.quotepath=off: senza, git quota i path non-ASCII con escape
    # ottali che non combaciano con nessun file reale, e il file sparirebbe
    # dallo scan in silenzio.
    # --raw per avere il modo del file; --no-renames: un rename è un file nuovo,
    # e il formato -z ha così sempre due campi per voce.
    if ! git -C "$REPO_TOP" -c core.quotepath=off diff --cached --raw --no-abbrev \
            --no-renames --diff-filter=ACMT -z > "$STAGED_LIST_FILE" 2>/dev/null; then
        log_fail "impossibile elencare i file in staging (git diff --cached fallito)"
        exit 2
    fi
    while IFS= read -r -d '' _meta && IFS= read -r -d '' path; do
        [[ -z "$path" ]] && continue
        # Voce ":<modo vecchio> <modo nuovo> <sha> <sha> <stato>". 160000 è un
        # gitlink (submodule): nell'indice non c'è un file da leggere, e il suo
        # contenuto si controlla nel repo del submodule.
        _mode="${_meta#* }"; _mode="${_mode%% *}"
        if [[ "$_mode" == "160000" ]]; then
            log_warn "submodule saltato: $path"
            continue
        fi
        mkdir -p -- "$STAGED_TMPDIR/$(dirname -- "$path")"
        # ":0:" esplicito: ":1:x" come nome file verrebbe letto come stage 1.
        if ! git -C "$REPO_TOP" show ":0:$path" > "$STAGED_TMPDIR/$path" 2>/dev/null; then
            # Mai uno skip silenzioso: un path in staging che non si riesce a
            # leggere è un errore d'ambiente, non "nessun secret" (il
            # chiamante tipico è un hook pre-commit fail-closed).
            log_fail "impossibile leggere il contenuto in staging di: $path (git show fallito)"
            exit 2
        fi
        is_binary_skip "$STAGED_TMPDIR/$path" && continue
        add_target "$STAGED_TMPDIR/$path" "$path"
    done < "$STAGED_LIST_FILE"
else
    if [[ "${#TARGETS[@]}" -eq 0 ]]; then
        log_fail "nessun file/directory da scandire (e --staged non passato)"
        exit 2
    fi
    # Elenco NUL-separato su file (un nome può contenere newline).
    expand_targets > "$WORK_TMP/expanded.list"
    while IFS= read -r -d '' f; do
        [[ -z "$f" ]] && continue
        rel_path_for "$f"   # NON $(...): vedi il commento sulla funzione
        add_target "$f" "$_RELPATH_RESULT" "$_SCOPEPATH_RESULT"
    done < "$WORK_TMP/expanded.list"
fi

# --- file con byte NUL (binari, UTF-16) --------------------------------------
# Senza -a grep tratta un file con NUL come binario; con -a un NUL nella riga
# stampata romperebbe il parsing. Questi file si scansionano quindi su copie:
#   - BOM UTF-16 o UTF-32: decodifica con iconv. Se iconv manca si esce con 2
#     (meglio bloccare che dare un falso "pulito").
#   - firma binaria certa (is_binary_signature): saltato.
#   - altrimenti due copie, con gli stessi numeri di riga: NUL tolti (ricompone il
#     testo UTF-16/UTF-32 senza BOM) e NUL sostituiti da spazi (tiene il confine
#     in "abc<NUL>valore", che la prima copia cancellerebbe).
# La scelta è per firma e non per densità di NUL: un UTF-16 senza BOM ha il 50% di
# NUL come un binario, e la densità riaprirebbe quel falso negativo.

# Primi 4 byte in esadecimale in _SIG, con i soli builtin (nessun processo per
# file). Da chiamare in locale C: "'$c" deve dare il valore del byte.
read_signature() {
    local c h i
    _SIG=""
    {
        for i in 1 2 3 4; do
            if IFS= read -r -d '' -n 1 c; then
                if [[ -z "$c" ]]; then
                    _SIG+="00"
                else
                    printf -v h '%02x' "'$c"; _SIG+="$h"
                fi
            else
                break
            fi
        done
    } < "$1"
}

# Solo firme che un testo non può avere per caso: niente "%PDF" o "GIF8", che si
# scrivono da tastiera. Per "MZ" serve anche il quarto byte (parte alta di un campo
# che vale meno di 512), così una riga di testo che inizia per MZ non è un binario.
is_binary_signature() {
    case "$1" in
        7f454c46|feedface|feedfacf|cefaedfe|cffaedfe|cafebabe) return 0 ;;   # ELF, Mach-O, class
        4d5a??00|4d5a??01) return 0 ;;                                        # PE
        504b0304|504b0506|504b0708) return 0 ;;                               # zip, jar, docx
        0061736d) return 0 ;;                                                 # wasm
        1f8b*|fd377a58|377abcaf) return 0 ;;                                  # gzip, xz, 7z
        89504e47|ffd8ff*|d0cf11e0) return 0 ;;                                # png, jpeg, OLE2
    esac
    return 1
}

normalize_nul_files() {
    local LC_ALL=C
    local i f nf rep scope enc _n=0
    local -a old_real=("${REALPATHS[@]}") old_rep=("${REPORTPATHS[@]}") old_scope=("${SCOPEPATHS[@]}")
    REALPATHS=(); REPORTPATHS=(); SCOPEPATHS=(); _REPORTPATH_OF=(); _SCOPEPATH_OF=()
    mkdir -p "$WORK_TMP/norm"
    for i in "${!old_real[@]}"; do
        f="${old_real[$i]}"; rep="${old_rep[$i]}"; scope="${old_scope[$i]}"
        if [[ -z "${_NUL_FILES[$f]:-}" ]]; then
            add_target "$f" "$rep" "$scope"
            continue
        fi
        read_signature "$f"
        enc=""
        case "$_SIG" in
            fffe0000|0000feff) enc="UTF-32" ;;
            fffe*|feff*)       enc="UTF-16" ;;
        esac
        if [[ -z "$enc" ]] && is_binary_signature "$_SIG"; then
            continue
        fi
        _n=$((_n+1))
        nf="$WORK_TMP/norm/$_n"
        if [[ -n "$enc" ]]; then
            if ! command -v iconv >/dev/null 2>&1; then
                log_fail "file $enc da decodificare ma iconv non è installato: $rep"
                exit 2
            fi
            # Un U+0000 decodificato tornerebbe NUL: spazio, come nella seconda copia.
            iconv -c -f "$enc" -t UTF-8 < "$f" 2>/dev/null | tr '\000' ' ' > "$nf"
            if [[ "${PIPESTATUS[0]}" -eq 0 ]]; then
                add_target "$nf" "$rep" "$scope"
                continue
            fi
            log_warn "iconv fallito su $rep: scansione senza decodifica"
        fi
        tr -d '\000' < "$f" > "$nf"
        add_target "$nf" "$rep" "$scope"
        tr '\000' ' ' < "$f" > "$nf.sp"
        add_target "$nf.sp" "$rep" "$scope"
    done
}

if [[ "${#REALPATHS[@]}" -gt 0 ]]; then
    declare -A _NUL_FILES=()
    make_batches
    # -I -c: un file con NUL in qualunque punto conta 0 righe, anche dopo 200 KB di
    # testo (-L invece si fermerebbe alla prima riga). Tolti i vuoti, restano loro.
    LC_ALL=C run_grep_batched "$WORK_TMP/nul.list" grep -IcHZ -e ''
    while IFS= read -r -d '' f && IFS= read -r _count; do
        [[ "$_count" == "0" && -s "$f" ]] && _NUL_FILES["$f"]=1
    done < "$WORK_TMP/nul.list"
    if [[ -n "${!_NUL_FILES[*]}" ]]; then
        normalize_nul_files
        make_batches
    fi
fi

# --- allowlist (uno o più file) in una mappa "path:regola" -> set di hash ----
# Caricata DOPO la risoluzione dei target: con --staged il repo giusto
# (REPO_TOP) è noto solo lì. SECRET_ALLOWLIST (env) è un override assoluto.
# _ALLOWLIST_NONEMPTY è uno scalare a parte perché sotto `set -u` un array
# associativo vuoto fa fallire "${#_ALLOW[@]}" con "unbound variable".
declare -a _ALLOWLIST_FILES=()
_add_allowlist_file() {
    local f="$1" dir abs already
    [[ -z "$f" || ! -f "$f" ]] && return 0
    dir="$(cd "$(dirname "$f")" 2>/dev/null && pwd)"
    [[ -z "$dir" ]] && return 0
    abs="$dir/$(basename "$f")"
    for already in "${_ALLOWLIST_FILES[@]:-}"; do
        [[ "$already" == "$abs" ]] && return 0
    done
    _ALLOWLIST_FILES+=("$abs")
}
if [[ -v SECRET_ALLOWLIST ]] && [[ -n "$SECRET_ALLOWLIST" ]]; then
    _add_allowlist_file "$SECRET_ALLOWLIST"
else
    _add_allowlist_file "$REPO_DIR/.secret-allowlist"
    [[ -n "$EXTRA_REPO_DIR" ]] && _add_allowlist_file "$EXTRA_REPO_DIR/.secret-allowlist"
    [[ -n "$REPO_TOP" ]] && _add_allowlist_file "$REPO_TOP/.secret-allowlist"
fi

declare -A _ALLOW=()
_ALLOWLIST_NONEMPTY=0
for ALLOWLIST_FILE in "${_ALLOWLIST_FILES[@]:-}"; do
    [[ -z "$ALLOWLIST_FILE" || ! -f "$ALLOWLIST_FILE" ]] && continue
    # "|| [[ -n $line ]]": l'ultima voce vale anche senza newline finale.
    # "\r" finale tolto (allowlist salvata con CRLF). Il parsing parte da
    # destra: hash e regola non contengono ":", il path sì (nome con ":").
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        [[ -z "$line" || "$line" == \#* ]] && continue
        hash="${line##*:}"
        rest="${line%:*}"
        rule="${rest##*:}"
        local_path="${rest%:*}"
        key="${local_path}:${rule}"
        _ALLOW["$key"]="${_ALLOW[$key]:-} $hash"
        _ALLOWLIST_NONEMPTY=1
    done < "$ALLOWLIST_FILE"
done

# Vero se <nome> è UNO dei flag separati da virgola (confronto esatto:
# "FMTPLACEHOLDER" contiene "PLACEHOLDER" come sottostringa).
_flag_has() {
    local flags="$1" want="$2" f
    local -a arr
    IFS=',' read -ra arr <<< "$flags"
    for f in "${arr[@]}"; do
        [[ "$f" == "$want" ]] && return 0
    done
    return 1
}

if [[ "${#REALPATHS[@]}" -gt 0 ]]; then
    for i in "${!RULE_NAMES[@]}"; do
        name="${RULE_NAMES[$i]}"; regex="${RULE_REGEX[$i]}"; flags="${RULE_FLAGS[$i]}"
        # -a: modalità testo (mai "Binary file matches", per byte non UTF-8).
        # --null: dopo il nome file un NUL al posto di ":", così un nome con
        # ":" o con newline non confonde il parsing. "--": nomi con "-".
        grep_opts=(-nHEa --null)
        _flag_has "$flags" CI && grep_opts=(-nHEai --null)
        run_grep_batched "$WORK_TMP/matches" grep "${grep_opts[@]}" -e "$regex"
        [[ -s "$WORK_TMP/matches" ]] || continue
        while IFS= read -r -d '' mfile && IFS= read -r mrest; do
            lineno="${mrest%%:*}"
            content="${mrest#*:}"
            [[ -z "$lineno" ]] && continue
            reportpath="${_REPORTPATH_OF[$mfile]:-}"
            [[ -z "$reportpath" ]] && continue
            if [[ "${#SCOPE_GLOBS[@]}" -gt 0 ]] && is_rule_excluded_for_path "${_SCOPEPATH_OF[$mfile]:-$reportpath}" "$name"; then
                continue
            fi
            if _flag_has "$flags" PLACEHOLDER; then
                extract_assignment_value "$content"
                looks_like_placeholder "$_EXTRACT_RESULT" && continue
            fi
            if _flag_has "$flags" FMTPLACEHOLDER; then
                looks_like_format_placeholder_line "$content" && continue
            fi
            if [[ "$_ALLOWLIST_NONEMPTY" -eq 1 ]]; then
                hash="$(sha256_string "$content")"
                is_allowlisted "$reportpath" "$name" "$hash" && continue
                # Stessa riga con CR finale (file CRLF): vale la stessa voce.
                if [[ "$content" == *$'\r' ]]; then
                    hash="$(sha256_string "${content%$'\r'}")"
                    is_allowlisted "$reportpath" "$name" "$hash" && continue
                fi
            fi
            FINDINGS+=("${reportpath}:${lineno}:${name}")
        done < "$WORK_TMP/matches"
    done
fi

# --- gitleaks, se presente, come secondo livello (best-effort) ---------------
if command -v gitleaks >/dev/null 2>&1; then
    for t in "${TARGETS[@]:-}"; do
        [[ -d "$t" ]] || continue
        # Il report contiene i valori trovati: dentro WORK_TMP, rimossa anche su TERM.
        GL_REPORT="$WORK_TMP/gitleaks-report.json"
        if gitleaks detect --no-git --source "$t" --report-format json \
                --report-path "$GL_REPORT" --no-banner --exit-code 0 >/dev/null 2>&1; then
            if [[ -s "$GL_REPORT" ]] && command -v node >/dev/null 2>&1; then
                _GL_ENTRIES="$(node -e '
                    const fs=require("fs");
                    try {
                        const data=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
                        const arr=Array.isArray(data)?data:[];
                        for (const r of arr) {
                            const f=r.File||r.file||"?";
                            const l=r.StartLine||r.startLine||"?";
                            console.log(`${f}:${l}:GITLEAKS`);
                        }
                    } catch(e) { /* report non leggibile: ignorato */ }
                ' "$GL_REPORT" 2>/dev/null)"
                while IFS= read -r entry; do
                    [[ -n "$entry" ]] && FINDINGS+=("$entry")
                done <<< "$_GL_ENTRIES"
            fi
        else
            log_warn "gitleaks presente ma l'esecuzione su $t è fallita (ignorato, livello principale invariato)"
        fi
        rm -f "$GL_REPORT"
    done
fi

if [[ "${#FINDINGS[@]}" -gt 0 ]]; then
    printf '%s\n' "${FINDINGS[@]}" | sort -u
    exit 3
fi
exit 0
