#!/bin/bash
# ============================================
# INSTALL: claude-kb-workflow → ~/.claude/
# Installazione interattiva degli agenti, pattern, skill, comandi
# ============================================

set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --yes|-y)
            ASSUME_YES=1
            ;;
    esac
done

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   claude-kb-workflow — Installazione                  ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Da: $REPO_DIR"
echo "A:  $CLAUDE_HOME"
echo ""

if [ ! -d "$CLAUDE_HOME" ]; then
    echo -e "${YELLOW}La directory $CLAUDE_HOME non esiste — la creo.${NC}"
    mkdir -p "$CLAUDE_HOME"
fi

echo ""
echo -e "${YELLOW}Questo installerà nel tuo Claude Code:${NC}"
echo "  - 12 subagent (2 orchestratori + 10 specialisti), con frontmatter YAML (agents/)"
echo "  - 16 pattern generalizzati + convenzioni personali IT (patterns/)"
echo "  - Workflow comuni (workflows/)"
echo "  - 6 skill custom (skills/)"
echo "  - 5 comandi /kb-* (commands/)"
echo ""
echo -e "${RED}Sovrascriverà i file con lo stesso nome esistenti in $CLAUDE_HOME${NC}"
if [ "$ASSUME_YES" -eq 1 ]; then
    REPLY=y
elif [ -t 0 ]; then
    read -p "Continuare? (y/N) " -n 1 -r || REPLY=n
    echo
else
    echo "stdin non interattivo: rilancia con --yes per confermare l'installazione."
    exit 1
fi
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Annullato."
    exit 0
fi

# 1. Agenti
echo -e "${YELLOW}[1/5] Installando agenti...${NC}"
mkdir -p "$CLAUDE_HOME/agents"
for agent_file in "$REPO_DIR/agents/"*.md; do
    if [ "$(basename "$agent_file")" = "README-AGENTI.md" ]; then
        continue
    fi
    cp -f "$agent_file" "$CLAUDE_HOME/agents/"
done
cp -f "$REPO_DIR/agents/README-AGENTI.md" "$CLAUDE_HOME/"
echo "  ✓ 12 agenti installati in $CLAUDE_HOME/agents/"
echo "  ✓ README-AGENTI.md installato in $CLAUDE_HOME/ (guida, non un agente)"
echo "  ✓ Ogni agente ha frontmatter YAML (name/description/model): il lead li vede"
echo "    e li sceglie automaticamente in base alla description, nessuna registrazione manuale"

# 2. Patterns
echo -e "${YELLOW}[2/5] Installando patterns...${NC}"
mkdir -p "$CLAUDE_HOME/patterns"
rm -f "$CLAUDE_HOME/patterns/critical-patterns.md"   # sostituito da patterns.md + field-notes-it.md
cp -f "$REPO_DIR/patterns/"*.md "$CLAUDE_HOME/patterns/"
echo "  ✓ $(ls "$CLAUDE_HOME/patterns/"*.md | wc -l) file di pattern installati (16 pattern generalizzati + convenzioni personali IT)"

# 3. Workflows
echo -e "${YELLOW}[3/5] Installando workflows...${NC}"
mkdir -p "$CLAUDE_HOME/workflows"
cp -f "$REPO_DIR/workflows/"*.md "$CLAUDE_HOME/workflows/"
echo "  ✓ $(ls "$REPO_DIR/workflows/"*.md | wc -l) file di workflow installati"

# 4. Skills
echo -e "${YELLOW}[4/5] Installando skills...${NC}"
mkdir -p "$CLAUDE_HOME/skills"
shopt -s nullglob dotglob
for skill_dir in "$REPO_DIR/skills"/*/; do
    if [ -d "$skill_dir" ]; then
        skill_name=$(basename "$skill_dir")
        if [ ! -e "$skill_dir/SKILL.md" ]; then
            echo "  ⊘ salto $skill_name (vuota)"
            continue
        fi
        dest="$CLAUDE_HOME/skills/$skill_name"
        mkdir -p "$dest"
        cp -rf "$skill_dir/." "$dest/"
        echo "  ✓ Skill: $skill_name"
    fi
done
shopt -u nullglob dotglob

# 5. Commands
echo -e "${YELLOW}[5/5] Installando commands /kb-*...${NC}"
mkdir -p "$CLAUDE_HOME/commands"
cp -f "$REPO_DIR/commands/"*.md "$CLAUDE_HOME/commands/"
echo "  ✓ $(ls "$REPO_DIR/commands/"*.md | wc -l) comandi installati"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Installazione completata!                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Prossimi passi:${NC}"
echo "  1. (Opzionale) Configura la LLM Wiki:"
echo "       cp -r $REPO_DIR/llm-wiki-template ~/llm-wiki"
echo "       export LLM_WIKI_PATH=~/llm-wiki"
echo ""
echo "  2. Riavvia Claude Code per caricare agenti, skill e comandi"
echo "     Gli agenti hanno frontmatter YAML (name/description/model): non serve"
echo "     elencarli in CLAUDE.md, il lead li seleziona da solo in base alla description."
echo ""
echo "  3. Test rapido:"
echo "       In Claude Code, scrivi: 'Mostrami il decision tree degli agenti'"
echo "       (Dovrebbe leggere ~/.claude/README-AGENTI.md)"
echo ""
echo -e "${BLUE}Per disinstallare: rimuovi i file da $CLAUDE_HOME/agents,patterns,workflows,skills,commands${NC}"
