#!/bin/bash
# patch.sh — One command to change your Claude buddy fate
# Usage: ./patch.sh --species capybara --shiny

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

OLD_SALT="friend-2026-401"
NEW_SALT=""
UUID=""
EXTRA_ARGS=""
RESTORE_MODE=""
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
        --restore) RESTORE_MODE=1; shift ;;
        --species) EXTRA_ARGS="$EXTRA_ARGS --species $2"; shift 2 ;;
        --shiny) EXTRA_ARGS="$EXTRA_ARGS --shiny"; shift ;;
        --rarity) EXTRA_ARGS="$EXTRA_ARGS --rarity $2"; shift 2 ;;
        --eye) EXTRA_ARGS="$EXTRA_ARGS --eye $2"; shift 2 ;;
        --hat) EXTRA_ARGS="$EXTRA_ARGS --hat $2"; shift 2 ;;
        -h|--help) print_help; exit 0 ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; print_help; exit 1 ;;
    esac
done

# ─── Interactive mode (no args) ───────────────────────────────
if [[ -z "$NEW_SALT" && -z "$EXTRA_ARGS" && -z "$RESTORE_MODE" ]]; then
    echo ""
    echo -e "${YELLOW}🐹 Buddy Patch — Change your Claude Code pet${NC}"
    echo ""
    echo "Available pets:"
    echo ""
    echo "  🦆 duck       🪿 goose      🫧 blob       🐱 cat"
    echo "  🐉 dragon     🐙 octopus    🦉 owl        🐧 penguin"
    echo "  🐢 turtle     🐌 snail      👻 ghost      🦎 axolotl"
    echo "  🐹 capybara   🌵 cactus     🤖 robot      🐰 rabbit"
    echo "  🍄 mushroom   🐈 chonk"
    echo ""
    read -p "What pet do you want? Type the name: " INPUT_SPECIES

    # Normalize: lowercase, trim
    INPUT_SPECIES=$(echo "$INPUT_SPECIES" | tr '[:upper:]' '[:lower:]' | xargs)

    # Map aliases, Chinese names, partial matches, common typos
    case "$INPUT_SPECIES" in
        duck|鸭|鸭子|小黄鸭)           CHOSEN_SPECIES="duck" ;;
        goose|鹅|大鹅|鹅鹅)            CHOSEN_SPECIES="goose" ;;
        blob|水滴|果冻|史莱姆|slime)    CHOSEN_SPECIES="blob" ;;
        cat|猫|猫咪|小猫|喵)            CHOSEN_SPECIES="cat" ;;
        dragon|龙|恐龙|小龙)            CHOSEN_SPECIES="dragon" ;;
        octopus|章鱼|八爪鱼)            CHOSEN_SPECIES="octopus" ;;
        owl|猫头鹰|夜猫子)              CHOSEN_SPECIES="owl" ;;
        penguin|企鹅|小企鹅)            CHOSEN_SPECIES="penguin" ;;
        turtle|乌龟|龟|海龟)            CHOSEN_SPECIES="turtle" ;;
        snail|蜗牛|小蜗牛)              CHOSEN_SPECIES="snail" ;;
        ghost|幽灵|鬼|👻)              CHOSEN_SPECIES="ghost" ;;
        axolotl|六角恐龙|蝾螈|美西螈)   CHOSEN_SPECIES="axolotl" ;;
        capybara|卡皮巴拉|水豚|🐹)      CHOSEN_SPECIES="capybara" ;;
        cactus|仙人掌|🌵)              CHOSEN_SPECIES="cactus" ;;
        robot|机器人|🤖)               CHOSEN_SPECIES="robot" ;;
        rabbit|兔|兔子|小兔子|🐰)       CHOSEN_SPECIES="rabbit" ;;
        mushroom|蘑菇|🍄)              CHOSEN_SPECIES="mushroom" ;;
        chonk|胖猫|肥猫|橘猫)           CHOSEN_SPECIES="chonk" ;;
        *)
            # Fuzzy: check if input is a substring of any species
            CHOSEN_SPECIES=""
            for sp in duck goose blob cat dragon octopus owl penguin turtle snail ghost axolotl capybara cactus robot rabbit mushroom chonk; do
                if [[ "$sp" == *"$INPUT_SPECIES"* || "$INPUT_SPECIES" == *"$sp"* ]]; then
                    CHOSEN_SPECIES="$sp"
                    break
                fi
            done
            if [[ -z "$CHOSEN_SPECIES" ]]; then
                echo -e "${RED}Can't find a pet matching: $INPUT_SPECIES${NC}"
                echo "Available: duck goose blob cat dragon octopus owl penguin turtle snail ghost axolotl capybara cactus robot rabbit mushroom chonk"
                exit 1
            fi
            ;;
    esac

    echo -e "   → Got it: ${GREEN}$CHOSEN_SPECIES${NC}"

    EXTRA_ARGS="--species $CHOSEN_SPECIES --shiny --rarity legendary"
    echo ""
    echo -e "   → Searching for a ✨ LEGENDARY SHINY $CHOSEN_SPECIES for you..."
    echo ""
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

    # Method 2: Native CLI install
    if [[ -d "$HOME/.local/share/claude/versions" ]]; then
        for dir in $(ls -t "$HOME/.local/share/claude/versions/" 2>/dev/null); do
            local bin="$HOME/.local/share/claude/versions/$dir"
            if [[ -f "$bin" ]]; then
                echo "$bin"
                return 0
            fi
        done
    fi

    # Method 3: npm install — find cli.js
    if command -v claude &>/dev/null; then
        local npm_cli=$(node -e "try{console.log(require.resolve('@anthropic-ai/claude-code/cli.js'))}catch(e){}" 2>/dev/null)
        if [[ -f "$npm_cli" ]]; then
            echo "$npm_cli"
            return 0
        fi
    fi

    # Method 4: macOS app bundle
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

# Detect install type: "native" (Bun binary) or "npm" (Node.js)
detect_install_type() {
    if file "$1" 2>/dev/null | grep -q "Mach-O\|ELF"; then
        echo "native"
    else
        echo "npm"
    fi
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

INSTALL_TYPE=$(detect_install_type "$CLAUDE_BIN")
echo -e "   Install type: ${INSTALL_TYPE}"

# ─── Restore mode ────────────────────────────────────────────
if [[ -n "$RESTORE_MODE" ]]; then
    BACKUP_FOUND=""
    for f in "${CLAUDE_BIN}.backup."* "${CLAUDE_BIN}.bak"; do
        if [[ -f "$f" ]]; then BACKUP_FOUND="$f"; break; fi
    done
    if [[ -n "$BACKUP_FOUND" ]]; then
        cp "$BACKUP_FOUND" "$CLAUDE_BIN"
        codesign -f -s - "$CLAUDE_BIN" 2>/dev/null
        echo -e "${GREEN}✅ Restored from: $BACKUP_FOUND${NC}"
    else
        echo -e "${RED}No backup found.${NC}"
    fi
    exit 0
fi

# ─── Check if SALT exists, auto-restore if needed ────────────
if ! grep -q "$OLD_SALT" "$CLAUDE_BIN" 2>/dev/null; then
    echo ""
    echo -e "${YELLOW}⚠️  Binary was already patched (original SALT not found)${NC}"

    # Auto-find backup
    BACKUP_FOUND=""
    for f in "${CLAUDE_BIN}.backup."* "${CLAUDE_BIN}.bak" "${CLAUDE_BIN}.backup"; do
        if [[ -f "$f" ]] && grep -q "$OLD_SALT" "$f" 2>/dev/null; then
            BACKUP_FOUND="$f"
            break
        fi
    done

    if [[ -n "$BACKUP_FOUND" ]]; then
        echo -e "   Found backup: $BACKUP_FOUND"
        echo -e "${CYAN}   Restoring original binary...${NC}"
        cp "$BACKUP_FOUND" "$CLAUDE_BIN"
        codesign -f -s - "$CLAUDE_BIN" 2>/dev/null
        echo -e "   ${GREEN}Restored!${NC}"
    else
        echo -e "${RED}   No backup found. Cannot restore.${NC}"
        echo "   Try reinstalling Claude Code, then run this script again."
        exit 1
    fi
fi

# ─── Ensure Bun is available ─────────────────────────────────
ensure_bun() {
    # Detect Bun version from Claude binary (must match EXACTLY!)
    local REQUIRED_BUN_VER=""
    if [[ -n "$CLAUDE_BIN" ]]; then
        REQUIRED_BUN_VER=$(strings "$CLAUDE_BIN" 2>/dev/null | grep -oE 'bun-v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    fi
    REQUIRED_BUN_VER="${REQUIRED_BUN_VER:-bun-v1.3.11}"
    local BUN_DIR="$SCRIPT_DIR/.bun-local"

    # Check project-local bun first (guaranteed correct version)
    if [[ -f "$BUN_DIR/bun" ]]; then
        local cur="bun-v$($BUN_DIR/bun --version 2>/dev/null)"
        if [[ "$cur" == "$REQUIRED_BUN_VER" ]]; then
            echo "$BUN_DIR/bun"
            return 0
        fi
    fi

    # Download the EXACT version directly from GitHub releases
    echo -e "${CYAN}📦 Downloading $REQUIRED_BUN_VER (must match Claude exactly)...${NC}" >&2

    local ARCH=$(uname -m)
    local BUN_ARCH="aarch64"
    if [[ "$ARCH" == "x86_64" ]]; then BUN_ARCH="x64"; fi

    local OS="darwin"
    if [[ "$(uname -s)" == "Linux" ]]; then OS="linux"; fi

    local BUN_URL="https://github.com/oven-sh/bun/releases/download/${REQUIRED_BUN_VER}/bun-${OS}-${BUN_ARCH}.zip"

    echo -e "   Downloading from: $BUN_URL" >&2
    mkdir -p "$BUN_DIR"
    curl -fsSL "$BUN_URL" -o /tmp/buddy-bun.zip || {
        echo -e "${RED}Download failed${NC}" >&2
        return 1
    }
    unzip -o /tmp/buddy-bun.zip -d /tmp/buddy-bun &>/dev/null || {
        echo -e "${RED}Unzip failed${NC}" >&2
        return 1
    }
    cp /tmp/buddy-bun/bun-${OS}-${BUN_ARCH}/bun "$BUN_DIR/bun"
    chmod +x "$BUN_DIR/bun"
    rm -rf /tmp/buddy-bun /tmp/buddy-bun.zip

    # Verify
    local installed="bun-v$($BUN_DIR/bun --version 2>/dev/null)"
    if [[ "$installed" == "$REQUIRED_BUN_VER" ]]; then
        echo -e "   ${GREEN}✓ $installed installed${NC}" >&2
        echo "$BUN_DIR/bun"
        return 0
    fi

    echo -e "${RED}Version mismatch: got $installed, need $REQUIRED_BUN_VER${NC}" >&2
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

    HASH_FLAG=""
    if [[ "$INSTALL_TYPE" == "npm" ]]; then
        HASH_FLAG="--node"
    fi

    FIND_OUTPUT=$($BUN "$SCRIPT_DIR/find-salt.js" --uuid "$UUID" --count 1 $HASH_FLAG $EXTRA_ARGS 2>&1) || {
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
