#!/bin/bash
# ============================================
# BACKUP: ~/.claude/ → repo locale
# Sincronizza le modifiche locali fatte in Claude Code verso il repo
# (per chi ha forkato e personalizzato il toolkit)
# ============================================

set -e

CLAUDE_HOME="$HOME/.claude"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== claude-kb-workflow — BACKUP ===${NC}"
echo "Da: $CLAUDE_HOME"
echo "A:  $REPO_DIR"
echo ""

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    CLAUDE_HOME="/c/Users/$(whoami)/.claude"
fi

if [ ! -d "$CLAUDE_HOME" ]; then
    echo -e "${RED}Errore: $CLAUDE_HOME non trovato!${NC}"
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
if git diff --stat --quiet 2>/dev/null && git diff --cached --stat --quiet 2>/dev/null; then
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
echo "Per committare:"
echo "  cd $REPO_DIR && git add -A && git commit -m 'backup: \$(date +%Y-%m-%d)'"
