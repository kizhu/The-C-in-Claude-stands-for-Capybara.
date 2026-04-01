# The C in Claude stands for Capybara

```
                    ╭─────────────────────────────╮
                    │  改 命 成 功 ！              │
                    │  你的水豚现在是传说级了。    │
                    ╰──────────┬──────────────────╯
                               │
                        ╭──────┴──────╮
                       ╱              ╲
                      │   ✦        ✦   │
                      │    ╰──────╯    │
                      │   ·────────·   │
                       ╲     ◠◠◠     ╱
                        ╰────┬┬────╯
                       ╱╱╱╱  ││  ╲╲╲╲
                      ╱╱╱╱   ││   ╲╲╲╲
                     🌿🌿   🌿🌿   🌿🌿
```

> Claude Code 的 `/buddy` 宠物系统是确定性的——你的账号 ID 决定了你的命。
> **这个工具让你改命。**

## 这是什么？

Claude Code 2.1 版本加入了一个彩蛋：输入 `/buddy` 会分配给你一只专属宠物伙伴。物种、稀有度、是否闪光、帽子、眼睛、属性值——全部由一个公式一锤定音：

```
hash(你的ID + SALT) → Mulberry32 PRNG → 依次掷骰 → 你的命
```

问题是：你改不了公式，但你可以改输入。

**方法一**：换一个 `userID`（让公式算出你想要的结果）
**方法二**：改掉 `SALT`（二进制里的硬编码盐值，让同一个 ID 算出不同的命）

## 宠物图鉴

| 类别 | 内容 |
|------|------|
| **18 种物种** | duck, goose, blob, cat, dragon, octopus, owl, penguin, turtle, snail, ghost, axolotl, **capybara**, cactus, robot, rabbit, mushroom, chonk |
| **5 级稀有度** | common(60%) / uncommon(25%) / rare(10%) / epic(4%) / legendary(1%) |
| **闪光** | 1% 概率，极其稀有 |
| **6 种眼睛** | `·` `✦` `×` `◉` `@` `°` |
| **8 种帽子** | none, crown, tophat, propeller, halo, wizard, beanie, tinyduck |
| **5 项属性** | DEBUGGING / PATIENCE / CHAOS / WISDOM / SNARK |

## 快速开始

```bash
# 克隆仓库
git clone https://github.com/kizhu/The-C-in-Claude-stands-for-Capybara..git
cd The-C-in-Claude-stands-for-Capybara.

# 赋予执行权限
chmod +x patch.sh

# 先看看你现在的命
bun buddy-reroll.js --check "你的userID"
# 或者用 node（npm 安装的 Claude 用这个）
node buddy-reroll.js --check "你的userID"
```

> **你的 userID 在哪？** 打开 `~/.claude.json`，找 `"userID"` 字段。

## 方法一：换 userID（适合 API / 非 OAuth 用户）

如果你没有绑定 OAuth（比如用 API key 登录），Claude 用 `userID` 字段来计算宠物。换一个能算出你想要的宠物的 ID 就行。

```bash
# 用 Bun（与原生安装的 Claude 一致的哈希算法）
bun buddy-reroll.js --species capybara --count 3

# 用 Node.js（与 npm 安装的 Claude 一致的哈希算法）
node buddy-reroll.js --species capybara --count 3

# 想要传说级闪光龙？
bun buddy-reroll.js --species dragon --rarity legendary --shiny

# 只要闪光，物种随缘
bun buddy-reroll.js --shiny --count 1
```

找到满意的结果后：

1. 打开 `~/.claude.json`
2. 删除 `"userID"` 和 `"companion"` 字段
3. 写入新的 `"userID": "搜索结果中的ID"`
4. 重启 Claude Code
5. 输入 `/buddy` 验证

## 方法二：改 SALT（适合 OAuth / Max 用户）

OAuth 用户的 `accountUuid` 从服务器获取，你改不了。但二进制里硬编码了一个 15 字符的 SALT：`friend-2026-401`。改掉它，同一个 UUID 就会算出完全不同的宠物。

### 第一步：找到合适的 SALT

```bash
# 必须用 Bun 运行（因为原生 Claude 用 Bun.hash）
bun find-salt.js --uuid "你的accountUuid" --species capybara
bun find-salt.js --uuid "你的accountUuid" --species dragon --rarity legendary
```

> **你的 accountUuid 在哪？** 打开 `~/.claude.json`，找 `oauthAccount.accountUuid` 字段。

### 第二步：一键 Patch

```bash
# 直接用找到的 SALT
./patch.sh --salt "找到的15字符SALT"

# 或者一步到位（自动搜索 + 自动 patch）
./patch.sh --uuid "你的accountUuid" --species capybara --shiny
```

`patch.sh` 会自动完成以下所有步骤：
- 找到 Claude 二进制文件
- 备份原始文件（带时间戳）
- 替换 SALT
- 重新签名（macOS Gatekeeper 要求）
- 清理 companion 缓存

## 完整参数列表

### buddy-reroll.js

```
选项:
  --check <uid>       查看某个 userID 对应的宠物
  --species <name>    目标物种 (18 种可选)
  --rarity <name>     最低稀有度 (common/uncommon/rare/epic/legendary)
  --shiny             要求闪光
  --eye <char>        目标眼睛 (· ✦ × ◉ @ °)
  --hat <name>        目标帽子 (none/crown/tophat/propeller/halo/wizard/beanie/tinyduck)
  --min-stats <n>     要求所有属性 >= n
  --count <n>         结果数量 (默认 3)
  --max <n>           最大搜索次数 (默认 5000万)
```

### find-salt.js（Bun only）

```
必须参数:
  --uuid <id>         你的 oauthAccount.accountUuid

选项同 buddy-reroll.js（搜索的是 SALT 而非 userID）
```

### patch.sh（macOS）

```
用法:
  ./patch.sh --salt <15字符SALT>
  ./patch.sh --uuid <accountUuid> --species capybara [--shiny] [--rarity epic]
```

## 算法详解

```
ID 优先级: oauthAccount.accountUuid > userID > "anon"

userID + SALT("friend-2026-401")
        │
        ▼
   hash()  ← Bun.hash (原生安装) 或 FNV-1a (npm 安装)
        │
        ▼
   Mulberry32 PRNG (seed)
        │
        ├── rng() → 稀有度  (加权: 60/25/10/4/1)
        ├── rng() → 物种    (18 选 1)
        ├── rng() → 眼睛    (6 选 1)
        ├── rng() → 帽子    (8 选 1)
        ├── rng() → 闪光    (< 0.01 = true)
        └── rng() → 5项属性  (floor 由稀有度决定 + 随机偏移)
```

## FAQ

**Q: Bun 和 Node 跑出来结果不一样？**

对。原生安装的 Claude 用 `Bun.hash()`，npm 安装用 `FNV-1a`，两个哈希函数不同。你需要根据自己的 Claude 安装方式选择对应的运行时来搜索。

**Q: 怎么知道我是 OAuth 用户还是 API 用户？**

打开 `~/.claude.json`。如果里面有 `oauthAccount` 字段，你是 OAuth 用户，用方法二。如果只有 `userID`，用方法一。

**Q: 改了会搞坏 Claude 吗？**

不会。方法一只改一个 JSON 字段。方法二改的是二进制中一个 15 字符的字符串，而且 `patch.sh` 会自动备份。最坏情况恢复备份就行。

**Q: Claude 自动更新后宠物会重置吗？**

会。更新会替换二进制文件，SALT 恢复原始值。重新跑一次 `patch.sh` 就好（SALT 值已经找到了，秒完成）。

**Q: 闪光太难找了怎么办？**

闪光概率 1%，再叠加物种等条件筛选，搜索量会很大。建议：
1. 先不加 `--shiny`，找到基础满意的
2. 单独搜闪光版本
3. 或者把 `--max` 调大（默认 5000 万次）

**Q: SALT 长度为什么必须 15 个字符？**

因为是直接替换二进制中的字节。原始 SALT `friend-2026-401` 是 15 个字符，替换的新值必须一样长，否则会破坏二进制文件结构。

**Q: 支持 Windows / Linux 吗？**

`buddy-reroll.js` 和 `find-salt.js` 跨平台。`patch.sh` 目前只支持 macOS（因为用了 `codesign`）。其他平台可以手动替换二进制中的 SALT 字符串。

## 版本说明

本工具基于 **Claude Code 2.1.89** 版本的 buddy 系统逆向分析。未来版本的 Claude 可能会修改算法（SALT 值、哈希方式、宠物池等），届时工具需要相应更新。

## 致谢

- 感谢 [linux.do](https://linux.do) 社区对 Claude Code buddy 系统的逆向工程研究和分享
- 本项目是社区集体智慧的结晶

## 仓库地址

- SSH: `git@github.com:kizhu/The-C-in-Claude-stands-for-Capybara..git`
- HTTPS: `https://github.com/kizhu/The-C-in-Claude-stands-for-Capybara.`

## License

MIT
