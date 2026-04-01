#!/usr/bin/env bun
// find-salt.js — Search for SALT values that produce desired buddy
// Supports both Bun.hash (native install) and FNV-1a (npm install)
//
// Usage: bun find-salt.js --uuid <uuid> --species capybara
//        bun find-salt.js --uuid <uuid> --species capybara --node  (for npm installs)

const FORCE_NODE = process.argv.includes('--node')
const HAS_BUN = typeof Bun !== 'undefined'

if (!HAS_BUN && !FORCE_NODE) {
  console.error('\x1b[31mError: Run with Bun for native installs, or add --node for npm installs\x1b[0m')
  process.exit(1)
}

const SALT_LENGTH = 15

const SPECIES = [
  'duck', 'goose', 'blob', 'cat', 'dragon', 'octopus', 'owl', 'penguin',
  'turtle', 'snail', 'ghost', 'axolotl', 'capybara', 'cactus', 'robot',
  'rabbit', 'mushroom', 'chonk'
]

const RARITIES = ['common', 'uncommon', 'rare', 'epic', 'legendary']
const RARITY_WEIGHTS = { common: 60, uncommon: 25, rare: 10, epic: 4, legendary: 1 }
const RARITY_ORDER = { common: 0, uncommon: 1, rare: 2, epic: 3, legendary: 4 }

const EYES = ['·', '✦', '×', '◉', '@', '°']
const HATS = ['none', 'crown', 'tophat', 'propeller', 'halo', 'wizard', 'beanie', 'tinyduck']

const STAT_NAMES = ['DEBUGGING', 'PATIENCE', 'CHAOS', 'WISDOM', 'SNARK']
const RARITY_FLOOR = { common: 5, uncommon: 15, rare: 25, epic: 35, legendary: 50 }

// ─── Hash functions ───────────────────────────────────────────
function hashBun(s) {
  return Number(BigInt(Bun.hash(s)) & 0xffffffffn)
}

function hashFNV1a(s) {
  let h = 2166136261
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return h >>> 0
}

const hashString = (FORCE_NODE || !HAS_BUN) ? hashFNV1a : hashBun

// ─── Mulberry32 PRNG ──────────────────────────────────────────
function mulberry32(seed) {
  let a = seed >>> 0
  return function () {
    a |= 0
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function pick(rng, arr) {
  return arr[Math.floor(rng() * arr.length)]
}

function rollRarity(rng) {
  let roll = rng() * 100
  for (const r of RARITIES) {
    roll -= RARITY_WEIGHTS[r]
    if (roll < 0) return r
  }
  return 'common'
}

function rollStats(rng, rarity) {
  const floor = RARITY_FLOOR[rarity]
  const peak = pick(rng, STAT_NAMES)
  let dump = pick(rng, STAT_NAMES)
  while (dump === peak) dump = pick(rng, STAT_NAMES)
  const stats = {}
  for (const name of STAT_NAMES) {
    if (name === peak) stats[name] = Math.min(100, floor + 50 + Math.floor(rng() * 30))
    else if (name === dump) stats[name] = Math.max(1, floor - 10 + Math.floor(rng() * 15))
    else stats[name] = floor + Math.floor(rng() * 40)
  }
  return stats
}

function rollBuddy(uid, salt) {
  const seed = hashString(uid + salt)
  const rng = mulberry32(seed)
  const rarity = rollRarity(rng)
  const species = pick(rng, SPECIES)
  const eye = pick(rng, EYES)
  const hat = pick(rng, HATS)
  const shiny = rng() < 0.01
  const stats = rollStats(rng, rarity)
  return { species, rarity, eye, hat, shiny, stats }
}

// ─── 随机 SALT 生成 ───────────────────────────────────────────
const SALT_CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
function randomSalt() {
  let s = ''
  for (let i = 0; i < SALT_LENGTH; i++) {
    s += SALT_CHARS[Math.floor(Math.random() * SALT_CHARS.length)]
  }
  return s
}

// ─── 匹配判断 ─────────────────────────────────────────────────
function matchesCriteria(buddy, criteria) {
  if (criteria.species && buddy.species !== criteria.species) return false
  if (criteria.rarity && RARITY_ORDER[buddy.rarity] < RARITY_ORDER[criteria.rarity]) return false
  if (criteria.shiny && !buddy.shiny) return false
  if (criteria.eye && buddy.eye !== criteria.eye) return false
  if (criteria.hat && buddy.hat !== criteria.hat) return false
  if (criteria.minStats) {
    for (const name of STAT_NAMES) {
      if (buddy.stats[name] < criteria.minStats) return false
    }
  }
  return true
}

// ─── 参数解析 ─────────────────────────────────────────────────
function parseArgs(argv) {
  const args = argv.slice(2)
  const opts = {
    uuid: null,
    species: null,
    rarity: null,
    shiny: false,
    eye: null,
    hat: null,
    minStats: null,
    count: 3,
    max: 50_000_000,
  }

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--uuid': opts.uuid = args[++i]; break
      case '--species': opts.species = args[++i]; break
      case '--rarity': opts.rarity = args[++i]; break
      case '--shiny': opts.shiny = true; break
      case '--eye': opts.eye = args[++i]; break
      case '--hat': opts.hat = args[++i]; break
      case '--min-stats': opts.minStats = parseInt(args[++i] || '30'); break
      case '--count': opts.count = parseInt(args[++i]); break
      case '--max': opts.max = parseInt(args[++i]); break
      case '--help': case '-h': printHelp(); process.exit(0);
      case '--node': break; // handled at top level
      default:
        console.error(`\x1b[31m未知参数: ${args[i]}\x1b[0m`)
        printHelp()
        process.exit(1)
    }
  }

  if (!opts.uuid) {
    console.error('\x1b[31m错误: 必须提供 --uuid 参数\x1b[0m')
    console.error('你的 accountUuid 可以在 Claude Code 登录后的认证信息中找到')
    printHelp()
    process.exit(1)
  }

  return opts
}

function printHelp() {
  console.log(`
\x1b[33m🔧 Find Salt — 为 OAuth 用户寻找新 SALT\x1b[0m

⚠️  必须用 Bun 运行！

用法:
  bun find-salt.js --uuid <accountUuid> [选项]

必须:
  --uuid <id>         你的 oauthAccount.accountUuid

选项:
  --species <name>    目标物种 (${SPECIES.join(', ')})
  --rarity <name>     最低稀有度 (${RARITIES.join(', ')})
  --shiny             要求闪光
  --eye <char>        目标眼睛 (${EYES.join(' ')})
  --hat <name>        目标帽子 (${HATS.join(', ')})
  --min-stats <n>     要求所有属性 >= n
  --count <n>         结果数量 (默认 3)
  --max <n>           最大搜索次数 (默认 5000万)
  -h, --help          显示帮助

示例:
  bun find-salt.js --uuid "abc123-def456" --species capybara --shiny
  bun find-salt.js --uuid "abc123-def456" --species dragon --rarity legendary --hat crown

找到 SALT 后，用 patch.sh 写入二进制:
  ./patch.sh --salt <找到的SALT>
`)
}

// ─── 格式化输出 ───────────────────────────────────────────────
function formatBuddy(buddy) {
  const shinyTag = buddy.shiny ? ' ✨闪光✨' : ''
  const rarityColors = {
    common: '\x1b[37m',
    uncommon: '\x1b[32m',
    rare: '\x1b[34m',
    epic: '\x1b[35m',
    legendary: '\x1b[33m',
  }
  const reset = '\x1b[0m'
  const color = rarityColors[buddy.rarity] || ''

  let out = ''
  out += `  ${color}【${buddy.rarity.toUpperCase()}】${reset}${shinyTag} ${buddy.species}\n`
  out += `  眼睛: ${buddy.eye}  帽子: ${buddy.hat}\n`
  out += `  属性: ${STAT_NAMES.map(n => `${n}=${buddy.stats[n]}`).join(' ')}\n`
  return out
}

// ─── 主逻辑 ───────────────────────────────────────────────────
function main() {
  const opts = parseArgs(process.argv)

  // 验证参数
  if (opts.species && !SPECIES.includes(opts.species)) {
    console.error(`\x1b[31m错误: 不存在的物种 "${opts.species}"\x1b[0m`)
    console.error(`可选物种: ${SPECIES.join(', ')}`)
    process.exit(1)
  }
  if (opts.rarity && !RARITIES.includes(opts.rarity)) {
    console.error(`\x1b[31m错误: 不存在的稀有度 "${opts.rarity}"\x1b[0m`)
    process.exit(1)
  }

  const hasCriteria = opts.species || opts.rarity || opts.shiny || opts.eye || opts.hat || opts.minStats
  if (!hasCriteria) {
    console.error('\x1b[31m错误: 至少指定一个目标条件（--species, --rarity, --shiny 等）\x1b[0m')
    printHelp()
    process.exit(1)
  }

  const criteria = {
    species: opts.species,
    rarity: opts.rarity,
    shiny: opts.shiny,
    eye: opts.eye,
    hat: opts.hat,
    minStats: opts.minStats,
  }

  // 先展示当前宠物
  const currentSalt = 'friend-2026-401'
  const currentBuddy = rollBuddy(opts.uuid, currentSalt)
  console.log(`\n\x1b[36m📋 当前宠物 (SALT="${currentSalt}"):\x1b[0m`)
  console.log(formatBuddy(currentBuddy))

  const hashLabel = (FORCE_NODE || !HAS_BUN) ? 'FNV-1a (npm install)' : 'Bun.hash (native install)'
  console.log(`\x1b[33m🔧 开始搜索新 SALT...\x1b[0m`)
  console.log(`   UUID: ${opts.uuid}`)
  console.log(`   Hash: ${hashLabel}`)
  console.log(`   目标: ${[
    opts.species && `物种=${opts.species}`,
    opts.rarity && `稀有度>=${opts.rarity}`,
    opts.shiny && '✨闪光',
    opts.eye && `眼睛=${opts.eye}`,
    opts.hat && `帽子=${opts.hat}`,
    opts.minStats && `全属性>=${opts.minStats}`,
  ].filter(Boolean).join(', ')}`)
  console.log(`   搜索上限: ${(opts.max / 1_000_000).toFixed(0)}M 次\n`)

  const results = []
  const startTime = Date.now()
  let checked = 0

  for (let i = 0; i < opts.max && results.length < opts.count; i++) {
    const salt = randomSalt()
    const buddy = rollBuddy(opts.uuid, salt)
    checked++

    if (matchesCriteria(buddy, criteria)) {
      results.push({ salt, buddy })
      console.log(`\x1b[32m✅ 找到第 ${results.length} 个! (已搜索 ${checked.toLocaleString()} 次)\x1b[0m`)
      console.log(`   SALT: "${salt}"`)
      console.log(formatBuddy(buddy))
    }

    if (checked % 1_000_000 === 0) {
      const elapsed = ((Date.now() - startTime) / 1000).toFixed(1)
      const rate = (checked / (Date.now() - startTime) * 1000).toFixed(0)
      console.log(`   ... 已搜索 ${(checked / 1_000_000).toFixed(0)}M 次, ${elapsed}s, ${rate}/s`)
    }
  }

  const elapsed = ((Date.now() - startTime) / 1000).toFixed(1)

  if (results.length === 0) {
    console.log(`\x1b[31m😢 搜索了 ${checked.toLocaleString()} 次，没找到符合条件的。\x1b[0m`)
    console.log(`   建议: 降低条件再试，或增大 --max`)
  } else {
    console.log(`\x1b[33m─── 搜索完成 ───\x1b[0m`)
    console.log(`   共搜索 ${checked.toLocaleString()} 次，耗时 ${elapsed}s`)
    console.log(`   找到 ${results.length} 个 SALT\n`)

    console.log(`\x1b[36m📋 使用方法:\x1b[0m`)
    console.log(`   用 patch.sh 将 SALT 写入 Claude 二进制:`)
    console.log(`   ./patch.sh --salt "${results[0].salt}"\n`)

    console.log(`   或手动操作:`)
    console.log(`   1. 找到 Claude 二进制 (通常在 /Applications/Claude.app/...)`)
    console.log(`   2. 将二进制中的 "friend-2026-401" 替换为 "${results[0].salt}"`)
    console.log(`   3. 重新签名: codesign -f -s - <二进制路径>`)
    console.log(`   4. 删除 ~/.claude.json 中的 "companion" 字段`)
    console.log(`   5. 重启 Claude Code\n`)
  }
}

main()
