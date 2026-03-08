# syncd

Unattended git repo sync tool. Single bash script at `bin/syncd`, installed via `install.sh`.

## Project structure

```
bin/syncd            # Main script — all commands live here
install.sh           # Idempotent installer (symlink, PATH, cron)
.syncpaths.example   # Template for ~/.syncpaths
```

## Key files

- `~/.syncpaths` — user config, one repo path per line (created by install.sh)
- `~/.syncd.log` — error log (appended by syncd on failures)
- `~/bin/syncd` — symlink to bin/syncd in this repo

## Conventions

- Pure bash, no external dependencies beyond git
- All user-facing output uses color helpers: `ok()`, `warn()`, `err()`, `info()`, `header()`
- All error logging goes through `log_error()` to ~/.syncd.log
- Path validation (exists + has .git/) happens in `load_repos()` and is reused by all commands
- `cmd_check()` has its own validation loop because it reports on all paths including invalid ones
- Everything in English
