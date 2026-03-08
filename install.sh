#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNCD_BIN="$SCRIPT_DIR/bin/syncd"
LINK_PATH="$HOME/bin/syncd"
SYNCPATHS="$HOME/.syncpaths"
EXAMPLE="$SCRIPT_DIR/.syncpaths.example"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*"; }
info() { echo -e "  $*"; }

echo -e "${BOLD}syncd installer${NC}\n"

# 1. Create ~/bin
if [[ ! -d "$HOME/bin" ]]; then
  mkdir -p "$HOME/bin"
  ok "Created ~/bin"
else
  ok "~/bin exists"
fi

# 2. Permissions
chmod +x "$SYNCD_BIN"
ok "bin/syncd is executable"

# 3. Symlink
if [[ -L "$LINK_PATH" ]]; then
  current_target=$(readlink "$LINK_PATH")
  if [[ "$current_target" == "$SYNCD_BIN" ]]; then
    ok "Symlink already correct"
  else
    ln -sf "$SYNCD_BIN" "$LINK_PATH"
    ok "Symlink updated (was pointing to $current_target)"
  fi
elif [[ -e "$LINK_PATH" ]]; then
  err "$LINK_PATH exists but is not a symlink — remove it manually"
  exit 1
else
  ln -s "$SYNCD_BIN" "$LINK_PATH"
  ok "Symlink created: ~/bin/syncd → $SYNCD_BIN"
fi

# 4. PATH check
if echo "$PATH" | tr ':' '\n' | grep -qx "$HOME/bin"; then
  ok "~/bin is in PATH"
else
  warn "~/bin is NOT in PATH"
  read -rp "  Add to ~/.zshrc? [y/N] " answer
  if [[ "$answer" =~ ^[yY]$ ]]; then
    echo '' >> "$HOME/.zshrc"
    echo '# syncd' >> "$HOME/.zshrc"
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
    ok "Added to ~/.zshrc — run: source ~/.zshrc"
  else
    info "Add manually: export PATH=\"\$HOME/bin:\$PATH\""
  fi
fi

# 5. Create ~/.syncpaths
if [[ ! -f "$SYNCPATHS" ]]; then
  if [[ -f "$EXAMPLE" ]]; then
    cp "$EXAMPLE" "$SYNCPATHS"
  else
    cat > "$SYNCPATHS" <<'EOF'
# syncd — one repo path per line
# Lines starting with # are ignored
# ~ is expanded to $HOME

# ~/Develop/claude-code-config
# ~/Develop/cowork-sessions
EOF
  fi
  ok "Created $SYNCPATHS (edit it to add your repos)"
else
  ok "$SYNCPATHS already exists"
fi

# 6. Validate syncpaths
echo -e "\n${BOLD}Validating ~/.syncpaths${NC}"
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  line="$(echo "$line" | xargs)"
  [[ -z "$line" ]] && continue

  path="${line/#\~/$HOME}"

  if [[ ! -d "$path" ]]; then
    warn "$path — directory not found"
  elif [[ ! -d "$path/.git" ]]; then
    warn "$path — not a git repo"
  else
    ok "$path"
  fi
done < "$SYNCPATHS"

# 7. Cron setup
echo ""
read -rp "Set up cron for 'syncd push' every 30 min? [y/N] " cron_answer
if [[ "$cron_answer" =~ ^[yY]$ ]]; then
  cron_line="*/30 * * * * $LINK_PATH push"
  if crontab -l 2>/dev/null | grep -qF "syncd push"; then
    ok "Cron entry already exists"
  else
    (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
    ok "Cron added: $cron_line"
  fi
else
  info "Skipped cron setup"
fi

echo -e "\n${BOLD}Done!${NC} Run: syncd help"
