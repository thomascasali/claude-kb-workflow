#!/bin/bash
# ============================================================================
# scripts/lib/common.sh — funzioni comuni per gli script del toolkit
# ============================================================================
#
# Da includere con `source` (non eseguirlo direttamente). Richiede bash.
#
# Variabili valorizzate dopo il source:
#   REPO_DIR        Radice del repo, calcolata dalla posizione di questo file
#                   (scripts/lib/common.sh -> due livelli sopra). Sovrascrivibile
#                   con --repo (vedi common_parse_args).
#   EXTRA_REPO_DIR  Secondo repo da considerare per l'allowlist, opzionale.
#                   Viene dalla variabile d'ambiente SECRET_SCAN_EXTRA_REPO
#                   (vuota = nessun secondo repo).
#
# Funzioni:
#   log_ok / log_warn / log_fail "msg"   Righe "[OK]" / "[WARN]" / "[FAIL]" su stderr.
#   sha256_string "testo"                Hash sha256 esadecimale di una stringa.
#   sha256_file <path>                   Hash sha256 esadecimale di un file.
#   common_parse_args "$@"               Riconosce --repo DIR / --repo=DIR ovunque
#                                        negli argomenti, aggiorna REPO_DIR e lascia
#                                        il resto in COMMON_REMAINING_ARGS.
#
# I log vanno sempre su stderr: lo stdout degli script resta pulito.
# ============================================================================

if [[ -n "${_TOOLKIT_COMMON_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_TOOLKIT_COMMON_SH_LOADED=1

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

EXTRA_REPO_DIR=""
if [[ -n "${SECRET_SCAN_EXTRA_REPO:-}" ]]; then
    EXTRA_REPO_DIR="$(cd "$SECRET_SCAN_EXTRA_REPO" 2>/dev/null && pwd)" || EXTRA_REPO_DIR=""
fi

# Colori solo se stderr è un terminale e NO_COLOR non è impostata.
if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
    _TK_GREEN='\033[0;32m'; _TK_YELLOW='\033[1;33m'; _TK_RED='\033[0;31m'; _TK_NC='\033[0m'
else
    _TK_GREEN=''; _TK_YELLOW=''; _TK_RED=''; _TK_NC=''
fi

log_ok()   { printf "${_TK_GREEN}[OK]${_TK_NC} %s\n"   "$*" >&2; }
log_warn() { printf "${_TK_YELLOW}[WARN]${_TK_NC} %s\n" "$*" >&2; }
log_fail() { printf "${_TK_RED}[FAIL]${_TK_NC} %s\n"   "$*" >&2; }

sha256_string() {
    local s="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$s" | sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        printf '%s' "$s" | shasum -a 256 | awk '{print $1}'
    else
        node -e '
            const c = require("crypto");
            process.stdout.write(c.createHash("sha256").update(process.argv[1]).digest("hex"));
        ' "$s"
    fi
}

sha256_file() {
    local f="$1"
    if [[ ! -f "$f" ]]; then
        log_fail "sha256_file: file non trovato: $f"
        return 1
    fi
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$f" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$f" | awk '{print $1}'
    else
        log_fail "sha256_file: serve sha256sum o shasum"
        return 1
    fi
}

common_parse_args() {
    COMMON_REMAINING_ARGS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo)
                if [[ $# -lt 2 ]]; then log_fail "--repo richiede un argomento"; return 1; fi
                REPO_DIR="$(cd "$2" 2>/dev/null && pwd)" || { log_fail "--repo: cartella non trovata: $2"; return 1; }
                shift 2 ;;
            --repo=*)
                REPO_DIR="$(cd "${1#--repo=}" 2>/dev/null && pwd)" || { log_fail "--repo: cartella non trovata: ${1#--repo=}"; return 1; }
                shift ;;
            *)
                COMMON_REMAINING_ARGS+=("$1")
                shift ;;
        esac
    done
    return 0
}
