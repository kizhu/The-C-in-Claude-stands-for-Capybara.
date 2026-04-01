#!/bin/bash
# patch.sh — 一键修改 Claude 二进制中的 buddy SALT (macOS)
# 用法: ./patch.sh --salt <新SALT>
#        ./patch.sh --species capybara --uuid <your-uuid>

set -euo pipefail

# ─── 颜色 ─────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

OLD_SALT="friend-2026-401"
NEW_SALT=""
UUID=""
SPECIES=""
EXTRA_ARGS=""

# ─── 参数解析 ──────────────────────────────────────────────────
print_help() {
    echo ""
    echo -e "${YELLOW}🔧 Buddy Patch — 一键修改 Claude 宠物${NC}"
    echo ""
    echo "用法:"
    echo "  ./patch.sh --salt <15字符SALT>"
    echo "  ./patch.sh --uuid <accountUuid> --species capybara [--shiny] [--rarity epic]"
    echo ""
    echo "选项:"
    echo "  --salt <str>      直接使用预计算好的 SALT (必须 15 个字符)"
    echo "  --uuid <id>       你的 accountUuid (用于自动搜索 SALT)"
    echo "  --species <name>  目标物种"
    echo "  --shiny           要求闪光"
    echo "  --rarity <name>   最低稀有度"
    echo "  --count <n>       搜索结果数量"
    echo "  -h, --help        显示帮助"
    echo ""
    echo "示例:"
    echo "  # 已经用 find-salt.js 找到了 SALT:"
    echo "  ./patch.sh --salt 'aBcDeFgHiJkLmNo'"
    echo ""
    echo "  # 自动搜索并 patch (需要 Bun):"
    echo "  ./patch.sh --uuid 'abc-123-def' --species capybara --shiny"
    echo ""
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --salt) NEW_SALT="$2"; shift 2 ;;
        --uuid) UUID="$2"; shift 2 ;;
        --species) SPECIES="$2"; EXTRA_ARGS="$EXTRA_ARGS --species $2"; shift 2 ;;
        --shiny) EXTRA_ARGS="$EXTRA_ARGS --shiny"; shift ;;
        --rarity) EXTRA_ARGS="$EXTRA_ARGS --rarity $2"; shift 2 ;;
        --eye) EXTRA_ARGS="$EXTRA_ARGS --eye $2"; shift 2 ;;
        --hat) EXTRA_ARGS="$EXTRA_ARGS --hat $2"; shift 2 ;;
        --count) EXTRA_ARGS="$EXTRA_ARGS --count $2"; shift 2 ;;
        -h|--help) print_help; exit 0 ;;
        *) echo -e "${RED}未知参数: $1${NC}"; print_help; exit 1 ;;
    esac
done

# ─── 检查参数 ──────────────────────────────────────────────────
if [[ -z "$NEW_SALT" && -z "$UUID" ]]; then
    echo -e "${RED}错误: 需要 --salt 或 --uuid 参数${NC}"
    print_help
    exit 1
fi

if [[ -n "$UUID" && -z "$SPECIES" && -z "$EXTRA_ARGS" ]]; then
    echo -e "${RED}错误: 使用 --uuid 时至少要指定一个目标条件 (如 --species)${NC}"
    exit 1
fi

# ─── 找 Claude 二进制 ─────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

find_claude_binary() {
    local candidates=(
        "/Applications/Claude.app/Contents/MacOS/Claude"
        "$HOME/Applications/Claude.app/Contents/MacOS/Claude"
    )
    for path in "${candidates[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

echo ""
echo -e "${CYAN}🔍 正在查找 Claude 二进制...${NC}"

CLAUDE_BIN=$(find_claude_binary) || {
    echo -e "${RED}错误: 找不到 Claude.app${NC}"
    echo "请确认 Claude 已安装在 /Applications/ 或 ~/Applications/"
    exit 1
}

echo -e "   找到: ${CLAUDE_BIN}"

# ─── 验证二进制中存在旧 SALT ──────────────────────────────────
if ! grep -q "$OLD_SALT" "$CLAUDE_BIN" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  警告: 二进制中没有找到原始 SALT \"${OLD_SALT}\"${NC}"
    echo "   可能已经被修改过，或者 Claude 版本不同"
    echo -n "   继续吗？(y/N) "
    read -r answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
        echo "已取消"
        exit 0
    fi
fi

# ─── 如果没有 SALT，先搜索 ────────────────────────────────────
if [[ -z "$NEW_SALT" ]]; then
    echo ""
    echo -e "${CYAN}🎲 使用 find-salt.js 搜索匹配的 SALT...${NC}"

    if ! command -v bun &>/dev/null; then
        echo -e "${RED}错误: 需要 Bun 来搜索 SALT${NC}"
        echo "安装: curl -fsSL https://bun.sh/install | bash"
        exit 1
    fi

    # 运行 find-salt.js 并捕获输出
    FIND_OUTPUT=$(bun "$SCRIPT_DIR/find-salt.js" --uuid "$UUID" --count 1 $EXTRA_ARGS 2>&1) || {
        echo -e "${RED}搜索失败:${NC}"
        echo "$FIND_OUTPUT"
        exit 1
    }

    echo "$FIND_OUTPUT"

    # 从输出中提取第一个 SALT (兼容 macOS BSD grep)
    NEW_SALT=$(echo "$FIND_OUTPUT" | sed -n 's/.*SALT: "\([^"]*\)".*/\1/p' | head -1)

    if [[ -z "$NEW_SALT" ]]; then
        echo -e "${RED}错误: 未找到符合条件的 SALT${NC}"
        exit 1
    fi

    echo -e "${GREEN}将使用 SALT: \"${NEW_SALT}\"${NC}"
fi

# ─── 验证 SALT 长度 ───────────────────────────────────────────
if [[ ${#NEW_SALT} -ne 15 ]]; then
    echo -e "${RED}错误: SALT 必须是 15 个字符 (当前 ${#NEW_SALT} 个)${NC}"
    echo "   原始 SALT \"${OLD_SALT}\" 是 15 个字符"
    echo "   替换时长度必须一致，否则会破坏二进制结构"
    exit 1
fi

# ─── 备份 ─────────────────────────────────────────────────────
BACKUP_PATH="${CLAUDE_BIN}.backup.$(date +%Y%m%d%H%M%S)"
echo ""
echo -e "${CYAN}📦 备份原始二进制...${NC}"
cp "$CLAUDE_BIN" "$BACKUP_PATH"
echo -e "   备份到: ${BACKUP_PATH}"

# ─── 替换 SALT ────────────────────────────────────────────────
echo ""
echo -e "${CYAN}✏️  替换 SALT...${NC}"
echo -e "   ${OLD_SALT} → ${NEW_SALT}"

# 使用 perl 进行二进制安全的替换
REPLACED=$(perl -pi -e "s/\Q${OLD_SALT}\E/${NEW_SALT}/g" "$CLAUDE_BIN" 2>&1) || {
    echo -e "${RED}替换失败，正在恢复备份...${NC}"
    cp "$BACKUP_PATH" "$CLAUDE_BIN"
    echo "已恢复"
    exit 1
}

# 验证替换成功
if grep -q "$NEW_SALT" "$CLAUDE_BIN" 2>/dev/null; then
    echo -e "   ${GREEN}替换成功${NC}"
else
    echo -e "${RED}替换似乎没有生效，正在恢复备份...${NC}"
    cp "$BACKUP_PATH" "$CLAUDE_BIN"
    echo "已恢复"
    exit 1
fi

# ─── 重新签名 ─────────────────────────────────────────────────
echo ""
echo -e "${CYAN}🔐 重新签名二进制...${NC}"
codesign -f -s - "$CLAUDE_BIN" 2>&1 || {
    echo -e "${RED}签名失败，正在恢复备份...${NC}"
    cp "$BACKUP_PATH" "$CLAUDE_BIN"
    codesign -f -s - "$CLAUDE_BIN" 2>/dev/null
    echo "已恢复"
    exit 1
}
echo -e "   ${GREEN}签名完成${NC}"

# ─── 清理 companion 缓存 ──────────────────────────────────────
CLAUDE_CONFIG="$HOME/.claude.json"
if [[ -f "$CLAUDE_CONFIG" ]]; then
    echo ""
    echo -e "${CYAN}🧹 清理 companion 缓存...${NC}"

    # 用 node/bun 来安全地修改 JSON
    if command -v node &>/dev/null; then
        JS_RUNTIME="node"
    elif command -v bun &>/dev/null; then
        JS_RUNTIME="bun"
    else
        echo -e "${YELLOW}   跳过: 找不到 node 或 bun 来修改 JSON${NC}"
        echo "   请手动删除 ~/.claude.json 中的 \"companion\" 字段"
        JS_RUNTIME=""
    fi

    if [[ -n "$JS_RUNTIME" ]]; then
        $JS_RUNTIME -e "
            const fs = require('fs');
            const config = JSON.parse(fs.readFileSync('$CLAUDE_CONFIG', 'utf8'));
            delete config.companion;
            fs.writeFileSync('$CLAUDE_CONFIG', JSON.stringify(config, null, 2) + '\n');
            console.log('   companion 缓存已清除');
        " 2>/dev/null || {
            echo -e "${YELLOW}   清理缓存时出错，请手动删除 ~/.claude.json 中的 companion 字段${NC}"
        }
    fi
fi

# ─── 完成 ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ 改命成功！${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo -e "  新 SALT: ${YELLOW}${NEW_SALT}${NC}"
echo -e "  备份在: ${BACKUP_PATH}"
echo ""
echo -e "  ${CYAN}下一步:${NC}"
echo "  1. 完全退出 Claude (Cmd+Q)"
echo "  2. 重新打开 Claude"
echo "  3. 输入 /buddy 查看你的新宠物"
echo ""
echo -e "  ${YELLOW}注意: Claude 自动更新后 SALT 会被重置，需要重新运行此脚本${NC}"
echo ""
