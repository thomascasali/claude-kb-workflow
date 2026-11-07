#!/bin/bash
# ============================================================================
# scripts/restore.sh — repo -> ~/.claude (operazione inversa di backup.sh)
# ============================================================================
#
# Ripristina nella cartella di Claude Code i file nel formato prodotto da
# scripts/backup.sh:
#   agents/*.md        -> <home>/agents/        (README-AGENTI.md -> <home>/,
#                                                come fa install.sh)
#   patterns/*.md      -> <home>/patterns/
#   workflows/*.md     -> <home>/workflows/
#   skills/<nome>/...  -> <home>/skills/<nome>/ (solo cartelle con SKILL.md)
#   commands/kb-*.md   -> <home>/commands/
#
# Uso:
#   restore.sh [--home DIR] [--repo DIR] [--dry-run] [--force]
#
#   --home DIR   Destinazione. Default: $CLAUDE_CONFIG_DIR, altrimenti ~/.claude.
#   --repo DIR   Sorgente. Default: il repo che contiene questo script.
#   --dry-run    Elenca cosa farebbe, non scrive nulla.
#   --force      Sovrascrive anche i file esistenti e diversi. Prima di
#                sovrascrivere ne salva una copia in
#                <home>/backups/restore-<data-ora>/.
#
# Senza --force un file che esiste già e differisce dal repo NON viene toccato
# (viene segnalato e contato come "saltato"); i file identici sono lasciati
# come sono. I symlink nel repo vengono ignorati.
#
# Codici d'uscita:
#   0  ripristino completato (anche se alcuni file sono stati saltati).
#   2  errore d'uso (argomenti non validi, cartella sorgente inesistente).
#   9  una copia è fallita davvero.
#
# Richiede bash. Testato solo con Git Bash su Windows (vedi scripts/restore-test.sh).
# ============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

common_parse_args "$@" || exit 2
set -- ${COMMON_REMAINING_ARGS[@]+"${COMMON_REMAINING_ARGS[@]}"}

DRY_RUN=0
FORCE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --force)   FORCE=1; shift ;;
        --home)
            [[ $# -ge 2 ]] || { log_fail "--home richiede un argomento"; exit 2; }
            CLAUDE_HOME="$2"; shift 2 ;;
        --home=*)  CLAUDE_HOME="${1#--home=}"; shift ;;
        -h|--help) sed -n '2,33p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) log_fail "argomento sconosciuto: $1"; exit 2 ;;
    esac
done

if [[ ! -d "$REPO_DIR" ]]; then
    log_fail "repo sorgente non trovato: $REPO_DIR"
    exit 2
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
SAFETY_DIR="$CLAUDE_HOME/backups/restore-$STAMP"

N_NEW=0; N_SAME=0; N_SKIP=0; N_OVER=0; N_FAIL=0

# restore_file <sorgente> <destinazione> <percorso mostrato>
restore_file() {
    local src="$1" dst="$2" rel="$3"
    if [[ -L "$src" ]]; then
        log_warn "symlink ignorato: $rel"
        return 0
    fi
    if [[ -e "$dst" ]]; then
        if cmp -s "$src" "$dst"; then
            N_SAME=$((N_SAME+1))
            return 0
        fi
        if [[ $FORCE -eq 0 ]]; then
            N_SKIP=$((N_SKIP+1))
            log_warn "esiste ed è diverso, saltato (usa --force per sovrascrivere): $rel"
            return 0
        fi
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "[dry-run] sovrascriverebbe: $rel"
            N_OVER=$((N_OVER+1))
            return 0
        fi
        mkdir -p "$SAFETY_DIR/$(dirname "$rel")" && cp -f "$dst" "$SAFETY_DIR/$rel" || {
            log_fail "copia di sicurezza fallita, non sovrascrivo: $rel"
            N_FAIL=$((N_FAIL+1)); return 0; }
        if cp -f "$src" "$dst"; then
            N_OVER=$((N_OVER+1))
        else
            log_fail "copia fallita: $rel"; N_FAIL=$((N_FAIL+1))
        fi
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "[dry-run] creerebbe: $rel"
        N_NEW=$((N_NEW+1))
        return 0
    fi
    if mkdir -p "$(dirname "$dst")" && cp "$src" "$dst"; then
        N_NEW=$((N_NEW+1))
    else
        log_fail "copia fallita: $rel"; N_FAIL=$((N_FAIL+1))
    fi
}

# restore_tree <cartella sorgente> <cartella destinazione> <prefisso mostrato>
# Scende ricorsivamente (nomi con spazi inclusi, file nascosti inclusi).
restore_tree() {
    local srcdir="$1" dstdir="$2" prefix="$3" e name
    shopt -s nullglob dotglob
    for e in "$srcdir"/*; do
        name="${e##*/}"
        [[ "$name" == ".git" ]] && continue
        if [[ -L "$e" ]]; then
            log_warn "symlink ignorato: $prefix$name"
        elif [[ -d "$e" ]]; then
            restore_tree "$e" "$dstdir/$name" "$prefix$name/"
        elif [[ -f "$e" ]]; then
            restore_file "$e" "$dstdir/$name" "$prefix$name"
        fi
    done
    shopt -u nullglob dotglob
}

# restore_flat <cartella sorgente> <glob dei file> <cartella destinazione> <prefisso>
restore_flat() {
    local srcdir="$1" pattern="$2" dstdir="$3" prefix="$4" f
    [[ -d "$srcdir" ]] || return 0
    shopt -s nullglob
    for f in "$srcdir"/$pattern; do
        [[ -f "$f" ]] || continue
        [[ "${f##*/}" == "README-AGENTI.md" ]] && continue
        restore_file "$f" "$dstdir/${f##*/}" "$prefix${f##*/}"
    done
    shopt -u nullglob
}

echo "=== Memoteca — RESTORE ===" >&2
echo "Da: $REPO_DIR" >&2
echo "A:  $CLAUDE_HOME" >&2
[[ $DRY_RUN -eq 1 ]] && echo "(dry-run: nessuna scrittura)" >&2
[[ $FORCE -eq 1 ]] && echo "(--force: i file diversi vengono sovrascritti, con copia di sicurezza)" >&2

if [[ $DRY_RUN -eq 0 ]]; then
    mkdir -p "$CLAUDE_HOME" || { log_fail "impossibile creare $CLAUDE_HOME"; exit 9; }
fi

restore_flat "$REPO_DIR/agents"    '*.md'    "$CLAUDE_HOME/agents"    "agents/"
[[ -f "$REPO_DIR/agents/README-AGENTI.md" ]] && \
    restore_file "$REPO_DIR/agents/README-AGENTI.md" "$CLAUDE_HOME/README-AGENTI.md" "README-AGENTI.md"
restore_flat "$REPO_DIR/patterns"  '*.md'    "$CLAUDE_HOME/patterns"  "patterns/"
restore_flat "$REPO_DIR/workflows" '*.md'    "$CLAUDE_HOME/workflows" "workflows/"
restore_flat "$REPO_DIR/commands"  'kb-*.md' "$CLAUDE_HOME/commands"  "commands/"

if [[ -d "$REPO_DIR/skills" ]]; then
    shopt -s nullglob
    for skill_dir in "$REPO_DIR/skills"/*/; do
        skill_dir="${skill_dir%/}"
        name="${skill_dir##*/}"
        if [[ ! -e "$skill_dir/SKILL.md" ]]; then
            echo "  salto skill senza SKILL.md: $name" >&2
            continue
        fi
        restore_tree "$skill_dir" "$CLAUDE_HOME/skills/$name" "skills/$name/"
    done
    shopt -u nullglob
fi

echo "" >&2
echo "Nuovi: $N_NEW · identici: $N_SAME · saltati (diversi): $N_SKIP · sovrascritti: $N_OVER · errori: $N_FAIL"
[[ $N_OVER -gt 0 && $DRY_RUN -eq 0 ]] && echo "Copie di sicurezza in: $SAFETY_DIR"

if [[ $N_FAIL -gt 0 ]]; then
    log_fail "ripristino incompleto: $N_FAIL errori"
    exit 9
fi
exit 0
