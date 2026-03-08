#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNCD_BIN="$SCRIPT_DIR/bin/syncd"
LINK_PATH="$HOME/bin/syncd"
SYNCPATHS="$HOME/.syncdrc"
EXAMPLE="$SCRIPT_DIR/.syncdrc.example"

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
shell_name=$(basename "${SHELL:-/bin/bash}")
case "$shell_name" in
  zsh)  rc_file="$HOME/.zshrc" ;;
  bash) rc_file="$HOME/.bashrc" ;;
  fish) rc_file="$HOME/.config/fish/config.fish" ;;
  *)    rc_file="$HOME/.profile" ;;
esac

if echo "$PATH" | tr ':' '\n' | grep -qx "$HOME/bin"; then
  ok "~/bin is in PATH"
elif grep -qs 'HOME/bin' "$rc_file"; then
  ok "~/bin is configured in $rc_file (restart shell or run: source $rc_file)"
else
  warn "~/bin is NOT in PATH"
  read -rp "  Add to $rc_file? [y/N] " answer
  if [[ "$answer" =~ ^[yY]$ ]]; then
    if [[ "$shell_name" == "fish" ]]; then
      mkdir -p "$(dirname "$rc_file")"
      echo '' >> "$rc_file"
      echo '# syncd' >> "$rc_file"
      echo 'set -gx PATH $HOME/bin $PATH' >> "$rc_file"
    else
      echo '' >> "$rc_file"
      echo '# syncd' >> "$rc_file"
      echo 'export PATH="$HOME/bin:$PATH"' >> "$rc_file"
    fi
    ok "Added to $rc_file"
    export PATH="$HOME/bin:$PATH"
    ok "PATH updated for current session"
  else
    info "Add manually: export PATH=\"\$HOME/bin:\$PATH\""
  fi
fi

# 5. Create ~/.syncdrc
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
echo -e "\n${BOLD}Validating ~/.syncdrc${NC}"
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
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
CRON_TAG="# syncd-cron"
echo ""
if crontab -l 2>/dev/null | grep -q "$CRON_TAG"; then
  ok "Cron already configured"
else
  read -rp "Set up cron for 'syncd push' every 30 min? [y/N] " cron_answer
  if [[ "$cron_answer" =~ ^[yY]$ ]]; then
    git_dir="$(dirname "$(command -v git)")"
    cron_line="*/30 * * * * PATH=$git_dir:/usr/bin:/bin $LINK_PATH push $CRON_TAG"
    current=$(crontab -l 2>/dev/null || true)
    # Remove any old syncd entries without the tag
    filtered=$(echo "$current" | grep -v "$CRON_TAG" || true)
    if [[ -n "$filtered" ]]; then
      printf '%s\n%s\n' "$filtered" "$cron_line" | crontab -
    else
      echo "$cron_line" | crontab -
    fi
    ok "Cron added: $cron_line"
  else
    info "Skipped cron setup"
  fi
fi

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$HOME/bin"; then
  echo -e "\n${BOLD}Done!${NC} Run: ${YELLOW}source ~/.zshrc${NC} then: syncd help"
else
  echo -e "\n${BOLD}Done!${NC} Run: syncd help"
fi
