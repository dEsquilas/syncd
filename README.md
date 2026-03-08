# syncd

Unattended git repo sync across machines. Built specifically to keep [Claude Code Cowork](https://docs.anthropic.com/en/docs/claude-code/cowork) conversations in sync — so you can start a cowork session on one machine and continue it on another without missing a beat. Also works great for config repos, dotfiles, notes, and anything else that needs to stay in sync without thinking about it.

## How it works

syncd reads a list of local repo paths from `~/.syncdrc` and runs git operations on all of them at once.

## Install

```bash
git clone git@github.com:dEsquilas/syncd.git ~/Develop/syncd
cd ~/Develop/syncd
./install.sh
```

The installer is idempotent and will:

1. Create `~/bin` if needed
2. Symlink `~/bin/syncd` to the script
3. Offer to add `~/bin` to PATH in `~/.zshrc`
4. Create `~/.syncdrc` from the example if it doesn't exist
5. Validate all configured repo paths
6. Optionally set up a cron job for `syncd push`

## Configuration

Edit `~/.syncdrc` — one repo path per line:

```
# Comments start with #
# ~ is expanded to $HOME

~/Develop/dotfiles
~/Develop/notes
~/Develop/claude-code-config
```

## Commands

### `syncd pull`

Brings all repos up to date with their remotes. Safe to run anytime.

For each repo:
1. If there are uncommitted local changes, stashes them automatically
2. Runs `git pull` (merge, never rebase)
3. Restores the stash. If there are conflicts, flags them for manual resolution

### `syncd push`

Commits and pushes all repos that have local changes. Designed for cron — repos with no changes are skipped silently.

For each repo with changes:
1. Stages everything (`git add -A`)
2. Commits with an auto-generated message: `syncd: 2026-03-08 14:30 — macbook`
3. Fetches remote — if the remote is ahead, pulls (merge) before pushing
4. Pushes to the remote

### `syncd status`

Shows the state of each repo at a glance:
- Current branch
- Sync state relative to upstream: ahead (↑), behind (↓), or in sync (≡)
- Number of files with local changes, or "Clean"

### `syncd add <path>`

Adds a repo to `~/.syncdrc`. Validates that the path exists and contains a git repo. Detects duplicates. Paths are stored with `~` notation.

```bash
syncd add ~/Develop/dotfiles
syncd add .                    # current directory
```

### `syncd list`

Shows all repos currently configured in `~/.syncdrc`.

### `syncd log [N]`

Shows the last N entries from `~/.syncd.log` (default 20). Includes both successful operations (PULL, PUSH) and errors.

### `syncd check`

Validates that every path in `~/.syncdrc`:
- Exists as a directory
- Contains a git repo (`.git/`)

Shows branch and remote URL for valid repos, and a summary of how many are valid.

### `syncd cron on [interval]`

Enables a cron job that runs `syncd push` on a schedule. Default interval is `30m`.

```bash
syncd cron on         # every 30 minutes
syncd cron on 15m     # every 15 minutes
syncd cron on 2h      # every 2 hours
```

Running it again with a different interval replaces the previous entry. Only enable on your primary machine to avoid conflicts.

### `syncd cron off`

Removes the syncd cron entry. Does not touch other cron jobs.

### `syncd cron status`

Shows whether the cron job is active and its current schedule.

## Error handling

- Invalid paths in `~/.syncdrc` are warned and skipped — they never abort the whole run
- `push` is silent when there are no changes (designed for cron)
- Errors are logged to `~/.syncd.log`
- Stash conflicts during `pull` are flagged for manual resolution

## Requirements

- bash 4+
- git
- macOS or Linux
