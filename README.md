# The C in Claude stands for Capybara

```
                    ╭─────────────────────────────╮
                    │   FATE SUCCESSFULLY CHANGED  │
                    │   Your capybara is now       │
                    │   ✨ LEGENDARY ✨            │
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

> Claude Code's `/buddy` pet system is deterministic — your account ID decides your fate.
> **This tool lets you change it.**

## What is this?

Claude Code 2.1 introduced an easter egg: type `/buddy` and you get a companion pet. Species, rarity, shiny status, hat, eyes, stats — all determined by a single formula:

```
hash(yourID + SALT) → Mulberry32 PRNG → sequential dice rolls → your fate
```

You can't change the formula. But you can change the inputs.

**Method 1**: Swap `userID` — find an ID that hashes to the pet you want
**Method 2**: Patch the `SALT` — modify the hardcoded salt in the binary so your existing ID produces a different pet

## Pet Codex

| Category | Options |
|----------|---------|
| **18 Species** | duck, goose, blob, cat, dragon, octopus, owl, penguin, turtle, snail, ghost, axolotl, **capybara**, cactus, robot, rabbit, mushroom, chonk |
| **5 Rarities** | common(60%) / uncommon(25%) / rare(10%) / epic(4%) / legendary(1%) |
| **Shiny** | 1% chance, extremely rare |
| **6 Eyes** | `·` `✦` `×` `◉` `@` `°` |
| **8 Hats** | none, crown, tophat, propeller, halo, wizard, beanie, tinyduck |
| **5 Stats** | DEBUGGING / PATIENCE / CHAOS / WISDOM / SNARK |

## Quick Start

```bash
git clone https://github.com/kizhu/The-C-in-Claude-stands-for-Capybara..git
cd The-C-in-Claude-stands-for-Capybara.
chmod +x patch.sh

# Check your current buddy
bun buddy-reroll.js --check "your-userID-here"
# Or with node (for npm-installed Claude)
node buddy-reroll.js --check "your-userID-here"
```

> **Where's your userID?** Open `~/.claude.json` and look for the `"userID"` field.

## Method 1: Swap userID (API / non-OAuth users)

If you're not using OAuth login (e.g. API key users), Claude uses the `userID` field to compute your buddy. Just find an ID that produces the pet you want.

```bash
# With Bun (matches native Claude's hash algorithm)
bun buddy-reroll.js --species capybara --count 3

# With Node.js (matches npm-installed Claude's hash algorithm)
node buddy-reroll.js --species capybara --count 3

# Want a legendary shiny dragon?
bun buddy-reroll.js --species dragon --rarity legendary --shiny

# Just want shiny, any species
bun buddy-reroll.js --shiny --count 1
```

Once you find a match:

1. Open `~/.claude.json`
2. Delete the `"userID"` and `"companion"` fields
3. Add `"userID": "the-id-from-search-results"`
4. Restart Claude Code
5. Type `/buddy` to verify

## Method 2: Patch the SALT (OAuth / Max subscribers)

For OAuth users, `accountUuid` is fetched from the server on every login — you can't change it, and it takes priority over `userID`. But the binary has a hardcoded 15-character SALT: `friend-2026-401`. Change that, and the same UUID produces a completely different pet.

### Step 1: Find the right SALT

```bash
# Must use Bun (native Claude uses Bun.hash)
bun find-salt.js --uuid "your-accountUuid" --species capybara
bun find-salt.js --uuid "your-accountUuid" --species dragon --rarity legendary --shiny
```

> **Where's your accountUuid?** Open `~/.claude.json`, look for `oauthAccount.accountUuid`.

### Step 2: One-click patch

```bash
# Use a pre-computed SALT
./patch.sh --salt "your-15-char-SALT"

# Or all-in-one (auto-search + auto-patch)
./patch.sh --uuid "your-accountUuid" --species capybara --shiny
```

`patch.sh` automatically:
- Locates the Claude binary
- Creates a timestamped backup
- Replaces the SALT (all occurrences)
- Re-signs the binary (required by macOS Gatekeeper)
- Clears companion cache from config

## Full Options

### buddy-reroll.js

```
Options:
  --check <uid>       Check what buddy a specific userID produces
  --species <name>    Target species (any of the 18)
  --rarity <name>     Minimum rarity (common/uncommon/rare/epic/legendary)
  --shiny             Require shiny variant
  --eye <char>        Target eye style (· ✦ × ◉ @ °)
  --hat <name>        Target hat (none/crown/tophat/propeller/halo/wizard/beanie/tinyduck)
  --min-stats <n>     Require ALL stats >= n
  --count <n>         Number of results to find (default: 3)
  --max <n>           Max search iterations (default: 50,000,000)
```

### find-salt.js (Bun only)

```
Required:
  --uuid <id>         Your oauthAccount.accountUuid

Options are the same as buddy-reroll.js, but searches for SALT values instead of userIDs.
```

### patch.sh (macOS)

```
Usage:
  ./patch.sh --salt <15-char-SALT>
  ./patch.sh --uuid <accountUuid> --species capybara [--shiny] [--rarity epic]
```

## How the Algorithm Works

```
ID priority: oauthAccount.accountUuid > userID > "anon"

input = userID + SALT("friend-2026-401")
        │
        ▼
   hash()  ← Bun.hash (native install) or FNV-1a (npm install)
        │
        ▼
   Mulberry32 PRNG (seeded)
        │
        ├── rng() → rarity    (weighted: 60/25/10/4/1)
        ├── rng() → species   (1 of 18)
        ├── rng() → eye       (1 of 6)
        ├── rng() → hat       (1 of 8, common = none)
        ├── rng() → shiny     (< 0.01 = true)
        └── rng() → 5 stats   (floor based on rarity + random offset)
```

## FAQ

**Q: Bun and Node give different results?**

Yes. Native Claude uses `Bun.hash()`, npm-installed Claude uses `FNV-1a`. They're different hash functions. Choose the runtime that matches your Claude installation.

**Q: How do I know if I'm OAuth or API?**

Open `~/.claude.json`. If you see an `oauthAccount` field, you're OAuth — use Method 2. If you only have `userID`, use Method 1.

**Q: Will this break my Claude?**

No. Method 1 only changes a JSON field. Method 2 modifies a 15-character string in the binary, and `patch.sh` auto-creates a backup. Worst case: restore the backup.

**Q: Will Claude auto-update reset my pet?**

Yes. Updates replace the binary, restoring the original SALT. Just re-run `patch.sh` — the SALT is already computed, takes seconds. (Tip: set `"autoUpdates": false` in `~/.claude.json` to prevent this.)

**Q: Shiny is too hard to find?**

Shiny is 1% probability on top of other filters. Tips:
1. Search without `--shiny` first to find a base you like
2. Then search for shiny separately
3. Or increase `--max` (default is 50M iterations)

**Q: Why must the SALT be exactly 15 characters?**

Because we're doing a direct byte replacement in the binary. The original SALT `friend-2026-401` is 15 characters — the replacement must be the same length or it would corrupt the file structure.

**Q: Does this work on Windows / Linux?**

`buddy-reroll.js` and `find-salt.js` are cross-platform. `patch.sh` currently supports macOS only (uses `codesign`). On other platforms, you can manually replace the SALT string in the binary with a hex editor.

## Version

Based on **Claude Code 2.1.89**. Future versions may change the algorithm (SALT value, hash function, pet pool, etc.), in which case the tools will need to be updated accordingly.

## Credits

- Thanks to the [linux.do](https://linux.do) community for the original reverse engineering of the Claude Code buddy system
- This project is the result of collective community wisdom and a stubborn refusal to accept a robot when a capybara was possible

## License

MIT
