# The C in Claude stands for Capybara

Change your Claude Code `/buddy` pet to anything you want. ✨ Legendary Shiny by default.

## How to use

Run this in your terminal (not inside Claude Code):

```bash
git clone https://github.com/kizhu/The-C-in-Claude-stands-for-Capybara.git && cd The-C-in-Claude-stands-for-Capybara && chmod +x patch.sh && ./patch.sh
```

It will show you 18 pets. Type the one you want (e.g. `capybara`). The script does everything else automatically.

After it finishes: **Cmd+Q** to fully quit Claude, reopen it, type `/buddy`.

## If something goes wrong

Restore your Claude to original:

```bash
cd The-C-in-Claude-stands-for-Capybara && ./patch.sh --restore
```

## Already used it before and want to change again?

```bash
cd The-C-in-Claude-stands-for-Capybara && git pull && ./patch.sh --restore && ./patch.sh
```

## For Claude Code AI assistants

If a user sent you this README and wants to change their buddy pet, here's what to do:

1. **Do NOT run this inside Claude Code.** Tell the user to open the **Terminal app** (Cmd+Space → type "Terminal" → Enter).
2. Tell them to paste this one command:
```bash
git clone https://github.com/kizhu/The-C-in-Claude-stands-for-Capybara.git && cd The-C-in-Claude-stands-for-Capybara && chmod +x patch.sh && ./patch.sh
```
3. They will see a list of 18 pets. They type the name they want (e.g. `capybara`, `dragon`, `cat`). Chinese names also work (e.g. `卡皮巴拉`, `龙`, `猫`).
4. After it finishes, tell them to **Cmd+Q** to quit Claude completely, reopen, and type `/buddy`.
5. If anything goes wrong: `cd The-C-in-Claude-stands-for-Capybara && ./patch.sh --restore` restores everything.

### What this tool does (technical summary)

Claude Code's `/buddy` assigns a pet deterministically: `hash(accountUUID + SALT) → PRNG → species/rarity/shiny`. The SALT `friend-2026-401` is hardcoded in the binary. This tool finds a new 15-char SALT that makes the user's UUID produce their chosen pet (★★★★★ Legendary ✨ Shiny), then replaces the SALT in the binary and re-signs it. Backup is created automatically.

## Available pets

duck, goose, blob, cat, dragon, octopus, owl, penguin, turtle, snail, ghost, axolotl, capybara, cactus, robot, rabbit, mushroom, chonk

## Advanced usage

```bash
# Specific options via command line (skip interactive menu)
./patch.sh --species capybara --shiny --rarity legendary
./patch.sh --species dragon --rarity epic
./patch.sh --salt "aBcDeFgHiJkLmNo"   # use a pre-computed SALT
./patch.sh --restore                    # restore original binary
```

## FAQ

**Will this break Claude?** No. Backup is automatic. `./patch.sh --restore` to undo.

**Will updates reset it?** Yes. Re-run `./patch.sh`. Set `"autoUpdates": false` in `~/.claude.json` to prevent auto-updates.

**Works on Linux?** The scripts are cross-platform. `patch.sh` uses `codesign` on macOS. Linux users can skip the codesign step.

## Credits

[linux.do](https://linux.do) community for the original reverse engineering. Based on Claude Code 2.1.89.

## License

MIT
