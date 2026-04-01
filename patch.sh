#!/bin/bash
# patch.sh — One command to change your Claude buddy fate
# Usage: ./patch.sh --species capybara --shiny

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

OLD_SALT="friend-2026-401"
NEW_SALT=""
UUID=""
EXTRA_ARGS=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ─── Help ─────────────────────────────────────────────────────
print_help() {
    echo ""
    echo -e "${YELLOW}🐹 Buddy Patch — Change your Claude Code pet${NC}"
    echo ""
    echo "Usage:"
    echo "  ./patch.sh --species capybara --shiny"
    echo "  ./patch.sh --salt <15-char-SALT>"
    echo ""
    echo "Options:"
    echo "  --species <name>  Target species (duck/cat/dragon/capybara/...)"
    echo "  --rarity <name>   Min rarity (common/uncommon/rare/epic/legendary)"
    echo "  --shiny           Require shiny variant"
    echo "  --eye <char>      Target eye (· ✦ × ◉ @ °)"
    echo "  --hat <name>      Target hat (crown/tophat/wizard/...)"
    echo "  --salt <str>      Use a pre-computed 15-char SALT directly"
    echo "  --uuid <id>       Override auto-detected accountUuid"
    echo "  -h, --help        Show this help"
    echo ""
}

# ─── Parse args ───────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --salt) NEW_SALT="$2"; shift 2 ;;
        --uuid) UUID="$2"; shift 2 ;;
        --species) EXTRA_ARGS="$EXTRA_ARGS --species $2"; shift 2 ;;
        --shiny) EXTRA_ARGS="$EXTRA_ARGS --shiny"; shift ;;
        --rarity) EXTRA_ARGS="$EXTRA_ARGS --rarity $2"; shift 2 ;;
        --eye) EXTRA_ARGS="$EXTRA_ARGS --eye $2"; shift 2 ;;
        --hat) EXTRA_ARGS="$EXTRA_ARGS --hat $2"; shift 2 ;;
        -h|--help) print_help; exit 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; print_help; exit 1 ;;
    esac
done

if [[ -z "$NEW_SALT" && -z "$EXTRA_ARGS" ]]; then
    echo -e "${RED}Error: specify a target (e.g. --species capybara) or --salt${NC}"
    print_help
    exit 1
fi

# ─── Auto-detect UUID from ~/.claude.json ─────────────────────
CLAUDE_CONFIG="$HOME/.claude.json"

if [[ -z "$UUID" && -z "$NEW_SALT" ]]; then
    if [[ -f "$CLAUDE_CONFIG" ]] && command -v node &>/dev/null; then
        UUID=$(node -e "
            try {
                const c = JSON.parse(require('fs').readFileSync('$CLAUDE_CONFIG','utf8'));
                const uuid = c.oauthAccount?.accountUuid;
                if (uuid) process.stdout.write(uuid);
            } catch(e) {}
        " 2>/dev/null) || true
    fi

    if [[ -z "$UUID" ]]; then
        echo -e "${RED}Error: Could not auto-detect accountUuid from ~/.claude.json${NC}"
        echo "Please provide it manually: ./patch.sh --uuid <your-uuid> --species ..."
        exit 1
    fi

    echo -e "${CYAN}🔑 Auto-detected UUID: ${UUID}${NC}"
fi

# ─── Find Claude binary ──────────────────────────────────────
find_claude_binary() {
    # Method 1: Follow `claude` command through symlinks
    if command -v claude &>/dev/null; then
        local claude_path=$(which claude)
        # macOS readlink doesn't have -f, resolve manually
        while [[ -L "$claude_path" ]]; do
            local target=$(readlink "$claude_path")
            # Handle relative symlinks
            if [[ "$target" != /* ]]; then
                target="$(dirname "$claude_path")/$target"
            fi
            claude_path="$target"
        done
        if [[ -f "$claude_path" ]]; then
            echo "$claude_path"
            return 0
        fi
    fi

    # Method 2: Check common native CLI install paths
    if [[ -d "$HOME/.local/share/claude/versions" ]]; then
        # Find the newest version binary
        for dir in $(ls -t "$HOME/.local/share/claude/versions/" 2>/dev/null); do
            local bin="$HOME/.local/share/claude/versions/$dir"
            if [[ -f "$bin" ]]; then
                echo "$bin"
                return 0
            fi
        done
    fi

    # Method 3: macOS app bundle
    local app_paths=(
        "/Applications/Claude.app/Contents/MacOS/Claude"
        "$HOME/Applications/Claude.app/Contents/MacOS/Claude"
    )
    for path in "${app_paths[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done

    return 1
}

echo ""
echo -e "${CYAN}🔍 Looking for Claude binary...${NC}"

CLAUDE_BIN=$(find_claude_binary) || {
    echo -e "${RED}Error: Claude binary not found${NC}"
    echo "Checked: ~/.local/share/claude/versions/*, /Applications/Claude.app"
    echo "Make sure Claude Code is installed."
    exit 1
}
echo -e "   Found: ${CLAUDE_BIN}"

# ─── Check if SALT exists in binary ──────────────────────────
if ! grep -q "$OLD_SALT" "$CLAUDE_BIN" 2>/dev/null; then
    echo ""
    echo -e "${YELLOW}⚠️  Original SALT \"${OLD_SALT}\" not found in binary${NC}"
    echo "   This means either:"
    echo "   - The binary was already patched (restore backup first)"
    echo "   - This Claude version uses a different SALT"
    echo ""
    echo -n "   Continue anyway? (y/N) "
    read -r answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

# ─── Ensure Bun is available ─────────────────────────────────
ensure_bun() {
    if command -v bun &>/dev/null; then
        echo "bun"
        return 0
    fi
    if [[ -f "$HOME/.bun/bin/bun" ]]; then
        echo "$HOME/.bun/bin/bun"
        return 0
    fi
    echo -e "${CYAN}📦 Installing Bun (needed for hash matching)...${NC}"
    curl -fsSL https://bun.sh/install | bash &>/dev/null
    if [[ -f "$HOME/.bun/bin/bun" ]]; then
        echo "$HOME/.bun/bin/bun"
        return 0
    fi
    return 1
}

# ─── Find SALT if not provided ────────────────────────────────
if [[ -z "$NEW_SALT" ]]; then
    BUN=$(ensure_bun) || {
        echo -e "${RED}Error: Bun is required to search for SALT${NC}"
        echo "Install: curl -fsSL https://bun.sh/install | bash"
        exit 1
    }

    echo ""
    echo -e "${CYAN}🎲 Searching for the perfect SALT...${NC}"

    FIND_OUTPUT=$($BUN "$SCRIPT_DIR/find-salt.js" --uuid "$UUID" --count 1 $EXTRA_ARGS 2>&1) || {
        echo -e "${RED}Search failed:${NC}"
        echo "$FIND_OUTPUT"
        exit 1
    }

    echo "$FIND_OUTPUT"

    NEW_SALT=$(echo "$FIND_OUTPUT" | sed -n 's/.*SALT: "\([^"]*\)".*/\1/p' | head -1)

    if [[ -z "$NEW_SALT" ]]; then
        echo -e "${RED}Error: No matching SALT found${NC}"
        exit 1
    fi
fi

# ─── Validate SALT length ────────────────────────────────────
if [[ ${#NEW_SALT} -ne 15 ]]; then
    echo -e "${RED}Error: SALT must be exactly 15 characters (got ${#NEW_SALT})${NC}"
    exit 1
fi

# ─── Backup ──────────────────────────────────────────────────
BACKUP_PATH="${CLAUDE_BIN}.backup.$(date +%Y%m%d%H%M%S)"
echo ""
echo -e "${CYAN}📦 Backing up binary...${NC}"
cp "$CLAUDE_BIN" "$BACKUP_PATH"
echo -e "   Saved to: ${BACKUP_PATH}"

# ─── Replace SALT ────────────────────────────────────────────
echo ""
echo -e "${CYAN}✏️  Patching SALT...${NC}"
echo -e "   ${OLD_SALT} → ${NEW_SALT}"

perl -pi -e "s/\Q${OLD_SALT}\E/${NEW_SALT}/g" "$CLAUDE_BIN" 2>&1 || {
    echo -e "${RED}Patch failed, restoring backup...${NC}"
    cp "$BACKUP_PATH" "$CLAUDE_BIN"
    exit 1
}

if grep -q "$NEW_SALT" "$CLAUDE_BIN" 2>/dev/null; then
    echo -e "   ${GREEN}Done${NC}"
else
    echo -e "${RED}Patch didn't take effect, restoring backup...${NC}"
    cp "$BACKUP_PATH" "$CLAUDE_BIN"
    exit 1
fi

# ─── Re-sign (macOS) ─────────────────────────────────────────
echo ""
echo -e "${CYAN}🔐 Re-signing binary...${NC}"
codesign -f -s - "$CLAUDE_BIN" 2>&1 || {
    echo -e "${RED}Signing failed, restoring backup...${NC}"
    cp "$BACKUP_PATH" "$CLAUDE_BIN"
    codesign -f -s - "$CLAUDE_BIN" 2>/dev/null
    exit 1
}
echo -e "   ${GREEN}Done${NC}"

# ─── Clear companion cache ───────────────────────────────────
if [[ -f "$CLAUDE_CONFIG" ]]; then
    echo ""
    echo -e "${CYAN}🧹 Clearing companion cache...${NC}"
    JS_RUNTIME=""
    if command -v node &>/dev/null; then JS_RUNTIME="node"
    elif command -v bun &>/dev/null; then JS_RUNTIME="bun"
    elif [[ -f "$HOME/.bun/bin/bun" ]]; then JS_RUNTIME="$HOME/.bun/bin/bun"
    fi

    if [[ -n "$JS_RUNTIME" ]]; then
        $JS_RUNTIME -e "
            const fs = require('fs');
            const c = JSON.parse(fs.readFileSync('$CLAUDE_CONFIG','utf8'));
            delete c.companion;
            fs.writeFileSync('$CLAUDE_CONFIG', JSON.stringify(c, null, 2) + '\n');
        " 2>/dev/null && echo -e "   ${GREEN}Done${NC}" || \
        echo -e "${YELLOW}   Skipped. Manually delete 'companion' from ~/.claude.json${NC}"
    fi
fi

# ─── Done! ────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ Fate changed successfully!        ${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "  SALT: ${YELLOW}${NEW_SALT}${NC}"
echo -e "  Backup: ${BACKUP_PATH}"
echo ""
echo -e "  ${CYAN}Next steps:${NC}"
echo "  1. Quit Claude completely (Cmd+Q)"
echo "  2. Reopen Claude"
echo "  3. Type /buddy to meet your new companion"
echo ""
echo -e "  ${YELLOW}Note: Claude auto-updates will reset the patch. Re-run this script to re-apply.${NC}"
echo ""
