#!/bin/bash
# ============================================
# BACKUP: ~/.claude/ → repo locale
# Sincronizza le modifiche locali fatte in Claude Code verso il repo
# (per chi ha forkato e personalizzato il toolkit)
# ============================================

set -e

CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Memoteca — BACKUP ===${NC}"
echo "Da: $CLAUDE_HOME"
echo "A:  $REPO_DIR"
echo ""

if [ ! -d "$CLAUDE_HOME" ]; then
    echo -e "${RED}Errore: $CLAUDE_HOME non trovato!${NC}"
    exit 1
fi

# Il backup copia file dentro il repo: senza git non si vedrebbe cosa è cambiato
# e nessun controllo (scanner, hook) potrebbe girare. Meglio fermarsi prima di copiare.
if ! git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo -e "${RED}Errore: $REPO_DIR non è un repository git.${NC}" >&2
    echo "Il backup deve scrivere dentro un clone di Memoteca (cartella con .git)." >&2
    echo "Nessun file è stato copiato." >&2
    exit 1
fi

# 1. Agenti
echo -e "${YELLOW}[1/5] Copiando agenti...${NC}"
mkdir -p "$REPO_DIR/agents"
if [ -d "$CLAUDE_HOME/agents" ]; then
    cp -f "$CLAUDE_HOME/agents/"*.md "$REPO_DIR/agents/" 2>/dev/null && \
        echo "  ✓ $(ls "$REPO_DIR/agents/" | wc -l) agenti copiati" || \
        echo "  - Nessun agente trovato"
fi

# 2. Patterns
echo -e "${YELLOW}[2/5] Copiando patterns...${NC}"
mkdir -p "$REPO_DIR/patterns"
if [ -d "$CLAUDE_HOME/patterns" ]; then
    cp -f "$CLAUDE_HOME/patterns/"*.md "$REPO_DIR/patterns/" 2>/dev/null && \
        echo "  ✓ $(ls "$REPO_DIR/patterns/" | wc -l) patterns copiati" || \
        echo "  - Nessun pattern trovato"
fi

# 3. Workflows
echo -e "${YELLOW}[3/5] Copiando workflows...${NC}"
mkdir -p "$REPO_DIR/workflows"
if [ -d "$CLAUDE_HOME/workflows" ]; then
    cp -f "$CLAUDE_HOME/workflows/"*.md "$REPO_DIR/workflows/" 2>/dev/null && \
        echo "  ✓ $(ls "$REPO_DIR/workflows/" | wc -l) workflows copiati" || \
        echo "  - Nessun workflow trovato"
fi

# 4. Skills
echo -e "${YELLOW}[4/5] Copiando skills...${NC}"
if [ -d "$CLAUDE_HOME/skills" ]; then
    for skill_dir in "$CLAUDE_HOME/skills"/*/; do
        if [ -d "$skill_dir" ]; then
            skill_name=$(basename "$skill_dir")
            # Escludi skill pesanti o con dati di autenticazione (mai in git!)
            case "$skill_name" in notebooklm) echo "  - Skill esclusa (auth/pesante): $skill_name"; continue;; esac
            mkdir -p "$REPO_DIR/skills/$skill_name"
            cp -rf "$skill_dir"* "$REPO_DIR/skills/$skill_name/" 2>/dev/null || true
            echo "  ✓ Skill: $skill_name"
        fi
    done
fi

# 5. Commands
echo -e "${YELLOW}[5/5] Copiando commands...${NC}"
mkdir -p "$REPO_DIR/commands"
if [ -d "$CLAUDE_HOME/commands" ]; then
    # Copia solo i comandi /kb-* (non i comandi di altri plugin)
    cp -f "$CLAUDE_HOME/commands/"kb-*.md "$REPO_DIR/commands/" 2>/dev/null && \
        echo "  ✓ Comandi /kb-* copiati" || \
        echo "  - Nessun comando /kb-* trovato"
fi

echo ""
echo -e "${GREEN}=== Backup completato! ===${NC}"
echo ""

cd "$REPO_DIR"
if git diff --stat --quiet && git diff --cached --stat --quiet; then
    UNTRACKED=$(git ls-files --others --exclude-standard | wc -l)
    if [ "$UNTRACKED" -eq 0 ]; then
        echo "Nessuna modifica rilevata."
    else
        echo -e "${YELLOW}Nuovi file:${NC}"
        git ls-files --others --exclude-standard
    fi
else
    echo -e "${YELLOW}Modifiche rilevate:${NC}"
    git diff --stat
fi

echo ""
echo "Prima di committare, controlla che non ci siano segreti:"
echo "  cd $REPO_DIR && bash scripts/lib/secret-scan.sh --repo . ."
echo "Poi scegli tu i file da aggiungere (git add <file>), senza aggiungere tutto in blocco."
echo "L'hook pre-commit ripete il controllo sui file in staging (git config core.hooksPath .githooks)."
