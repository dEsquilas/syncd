# syncd

Unattended git repo sync tool. Single bash script at `bin/syncd`, installed via `install.sh`.

## Project structure

```
bin/syncd            # Main script — all commands live here
install.sh           # Idempotent installer (symlink, PATH, scheduler)
.syncdrc.example   # Template for ~/.syncdrc
```

## Key files

- `~/.syncdrc` — user config, one repo path per line (created by install.sh)
- `~/.syncd.log` — activity log (syncs, pulls, pushes, and errors)
- `~/bin/syncd` — symlink to bin/syncd in this repo
- `~/Library/LaunchAgents/com.syncd.push.plist` — launchd agent (macOS scheduler for `cron on`)
- `~/.syncd.launchd.log` — launchd stdout/stderr (macOS)

## Conventions

- Pure bash, no external dependencies beyond git
- All user-facing output uses color helpers: `ok()`, `warn()`, `err()`, `info()`, `header()`
- Error logging goes through `log_error()`, activity logging through `log_sync()`, both to ~/.syncd.log
- Path validation (exists + has .git/) happens in `load_repos()` and is reused by all commands
- `cmd_check()` has its own validation loop because it reports on all paths including invalid ones
- `cmd_cron()` dispatches by OS: launchd LaunchAgent on macOS (`cron_launchd`), crontab on Linux (`cron_crontab`) — same command surface
- Everything in English
