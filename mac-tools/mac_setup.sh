#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────── #
# Assumes Homebrew is already installed.
# If not: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# ─────────────────────────────────────────────────────────────────────────── #

LOG_FILE="/tmp/mac_setup.log"
> "$LOG_FILE"

# ── Detect real user (safe to run as root or normal user) ────────────────────
if [ "$EUID" -eq 0 ]; then
  REAL_USER=$(stat -f '%Su' /dev/console 2>/dev/null || who | awk '/console/{print $1}' | head -1)
  [ -z "$REAL_USER" ] || [ "$REAL_USER" = "root" ] && REAL_USER=$(ls /Users | grep -v Shared | grep -v '.localized' | head -1)
  REAL_HOME="/Users/$REAL_USER"
  AS_USER="sudo -H -u $REAL_USER HOME=$REAL_HOME"
else
  REAL_USER=$(whoami)
  REAL_HOME="$HOME"
  AS_USER=""
fi
export HOME="$REAL_HOME"

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
TAN='\033[38;5;180m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# ── Terminal dimensions ──────────────────────────────────────────────────────
TERM_ROWS=$(tput lines)
TERM_COLS=$(tput cols)

# Fixed header occupies rows 0-13
# Row 0-8   : banner (9 lines incl. leading blank)
# Row 9     : blank after banner
# Row 10    : ━ separator
# Row 11    : section status
# Row 12    : overall progress bar
# Row 13    : ━ separator
# Row 14+   : scroll region (all output goes here)
SECTION_ROW=11
PROGRESS_ROW=12
SCROLL_START=14

TOTAL_SECTIONS=12
CURRENT_SECTION=0

# ── Logging ──────────────────────────────────────────────────────────────────
log() { printf '%s\n' "$*" >> "$LOG_FILE"; }

# ── Draw the fixed header (called once) ──────────────────────────────────────
draw_header() {
  tput clear
  tput cup 0 0

  echo -en "${TAN}"
  cat << 'BANNER'

       ,,             ,...                   ,,
     `7MM           .d' ""                 `7MM   mm
       MM           dM`                      MM   MM
  ,M""bMM  .gP"Ya  mMMmm ,6"Yb.`7MM  `7MM    MM mmMMmm
,AP    MM ,M'   Yb  MM  8)   MM  MM    MM    MM   MM
8MI    MM 8M""""""  MM   ,pm9MM  MM    MM    MM   MM
`Mb    MM YM.    ,  MM  8M   MM  MM    MM    MM   MM
 `Wbmd"MML.`Mbmmd'.JMML.`Moo9^Yo.`Mbod"YML..JMML. `Mbmo
BANNER
  printf "${NC}\n"
  # Row 10: separator
  printf "${TAN}"; printf '━%.0s' $(seq 1 "$TERM_COLS"); printf "${NC}\n"
  # Row 11: section name placeholder
  printf "  ${CYAN}⬡${NC}  %-$((TERM_COLS - 5))s\n" "Initializing..."
  # Row 12: overall progress placeholder
  printf "  ${TAN}Overall${NC} [%-40s] %3d%%  %s\n" "" 0 ""
  # Row 13: separator
  printf "${TAN}"; printf '━%.0s' $(seq 1 "$TERM_COLS"); printf "${NC}\n"

  # Lock scroll region to rows 14+ — banner stays frozen above
  tput csr $SCROLL_START $((TERM_ROWS - 1))
  tput cup $SCROLL_START 0
}

# ── Update section name + overall progress bar in frozen header ───────────────
update_section() {
  local name="$1"
  ((CURRENT_SECTION++))
  local pct=$(( CURRENT_SECTION * 100 / TOTAL_SECTIONS ))
  local bar_width=40
  local filled=$(( CURRENT_SECTION * bar_width / TOTAL_SECTIONS ))
  local i; local bar=""
  for ((i=0; i<filled; i++));     do bar+="█"; done
  for ((i=filled; i<bar_width; i++)); do bar+="░"; done

  tput sc
    tput cup $SECTION_ROW 0; tput el
    printf "  ${CYAN}⬡${NC}  ${BOLD}%s${NC}  ${CYAN}(%d/%d)${NC}" "$name" "$CURRENT_SECTION" "$TOTAL_SECTIONS"
    tput cup $PROGRESS_ROW 0; tput el
    printf "  ${TAN}Overall${NC} [${TAN}%s${NC}] %3d%%  ${CYAN}%d${NC}/${TOTAL_SECTIONS} sections complete" \
      "$bar" "$pct" "$CURRENT_SECTION"
  tput rc

  log ""
  log "━━━ Section $CURRENT_SECTION/$TOTAL_SECTIONS: $name ━━━"
}

# ── In-scroll progress bar — updates the same line with \r ───────────────────
item_progress() {
  local label="$1"
  local current=$2
  local total=$3
  local bar_width=28
  local pct=$(( current * 100 / total ))
  local filled=$(( current * bar_width / total ))
  local i; local bar=""
  for ((i=0; i<filled; i++));      do bar+="█"; done
  for ((i=filled; i<bar_width; i++)); do bar+="░"; done
  printf "\r  ${CYAN}[${TAN}%s${CYAN}]${NC} %3d%%  %-36s" "$bar" "$pct" "$label"
}

# ── Helpers ──────────────────────────────────────────────────────────────────
ok()   { printf "${GREEN}  ✓${NC}  %s\n" "$1" | tee -a "$LOG_FILE"; }
info() { printf "${CYAN}  →${NC}  %s\n" "$1" | tee -a "$LOG_FILE"; }
warn() { printf "${YELLOW}  ⚠${NC}  %s\n" "$1" | tee -a "$LOG_FILE"; }

# ── Batch install with per-item progress bar ──────────────────────────────────
install_brew_batch() {
  local section_label="$1"; shift
  local pkgs=("$@")
  local total=${#pkgs[@]}
  local i=0
  for pkg in "${pkgs[@]}"; do
    ((i++))
    item_progress "$pkg" "$i" "$total"
    if $AS_USER brew list "$pkg" &>/dev/null 2>&1; then
      log "skip (installed): $pkg"
    else
      $AS_USER brew install "$pkg" >> "$LOG_FILE" 2>&1 || log "WARN: failed $pkg"
    fi
  done
  printf "\r  ${GREEN}✓${NC}  %-65s\n" "$section_label ($total packages)"
}

install_cask_batch() {
  local section_label="$1"; shift
  local pkgs=("$@")
  local total=${#pkgs[@]}
  local i=0
  for pkg in "${pkgs[@]}"; do
    ((i++))
    item_progress "$pkg" "$i" "$total"
    if $AS_USER brew list --cask "$pkg" &>/dev/null 2>&1; then
      log "skip (installed): $pkg"
    else
      $AS_USER brew install --cask "$pkg" >> "$LOG_FILE" 2>&1 || log "WARN: failed $pkg"
    fi
  done
  printf "\r  ${GREEN}✓${NC}  %-65s\n" "$section_label ($total apps)"
}

install_pipx_batch() {
  local pkgs=("$@")
  local total=${#pkgs[@]}
  local i=0
  for pkg in "${pkgs[@]}"; do
    ((i++))
    item_progress "$pkg" "$i" "$total"
    if $AS_USER pipx list 2>/dev/null | grep -q "package $pkg"; then
      log "skip (installed): $pkg"
    else
      $AS_USER pipx install "$pkg" >> "$LOG_FILE" 2>&1 || log "WARN: failed $pkg"
    fi
  done
  printf "\r  ${GREEN}✓${NC}  %-65s\n" "Python tools ($total packages)"
}

install_npm_batch() {
  local pkgs=("$@")
  local total=${#pkgs[@]}
  local i=0
  for pkg in "${pkgs[@]}"; do
    ((i++))
    item_progress "$pkg" "$i" "$total"
    $AS_USER bash -c "
      export NVM_DIR=\"$REAL_HOME/.nvm\"
      [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
      npm install -g \"$pkg\"
    " >> "$LOG_FILE" 2>&1 || log "WARN: failed $pkg"
  done
  printf "\r  ${GREEN}✓${NC}  %-65s\n" "npm globals ($total packages)"
}

# ════════════════════════════════════════════════════════════════════════════
# Init
# ════════════════════════════════════════════════════════════════════════════

draw_header

# Homebrew check
if ! command -v brew &>/dev/null; then
  tput csr 0 $((TERM_ROWS - 1))
  tput cup $((TERM_ROWS - 1)) 0
  echo ""
  warn "Homebrew not found. Install it first, then re-run this script:"
  echo ""
  echo -e "  ${CYAN}/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${NC}"
  echo ""
  exit 1
fi

ARCH=$(uname -m)
[[ "$ARCH" == "arm64" ]] && HOMEBREW_PREFIX="/opt/homebrew" || HOMEBREW_PREFIX="/usr/local"
ok "Homebrew found ($HOMEBREW_PREFIX)"

# Sudo — prime once, keep alive
info "Sudo required — enter your password once:"
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_PID=$!
cleanup() {
  kill "$SUDO_PID" 2>/dev/null || true
  # Restore full scroll region on exit
  tput csr 0 $((TERM_ROWS - 1))
  tput cup $((TERM_ROWS - 1)) 0
  echo ""
}
trap cleanup INT TERM EXIT

# ════════════════════════════════════════════════════════════════════════════
update_section "macOS System Preferences"
# ════════════════════════════════════════════════════════════════════════════

info "Dock..."
defaults write com.apple.dock tilesize -int 32
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 64
defaults write com.apple.dock orientation -string "bottom"
defaults write com.apple.dock show-recents -bool false
ok "Dock: small icons, magnify on hover, bottom, no recents"

info "Mouse / keyboard..."
defaults write -g com.apple.mouse.scaling -float 3.0
defaults write com.apple.AppleMultitouchMouse MouseButtonMode -string "TwoButton"
defaults write -g com.apple.swipescrolldirection -bool false
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2
ok "Mouse: max speed, right-click, scroll non-reverse | Keyboard: fast repeat"

info "Finder..."
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder _FXSortFoldersFirst -bool true
ok "Finder: list view, hidden files, all extensions, path+status bar, folders first"

info "TextEdit / Screenshots / Menu Bar..."
defaults write com.apple.TextEdit RichText -int 0
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Screenshots"
defaults write com.apple.screencapture type -string "jpg"
defaults write com.apple.menuextra.clock ShowDate -int 1
defaults write com.apple.menuextra.clock DateFormat -string "EEE d MMM  HH:mm"
ok "TextEdit: plain text | Screenshots → ~/Screenshots (JPG) | Clock: date + day"

info "Security / Power / Misc..."
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null || true
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on 2>/dev/null || true
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
sudo pmset -c sleep 0
sudo pmset -c disksleep 0
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write com.apple.CrashReporter DialogType -string "none"
defaults write com.apple.LaunchServices LSQuarantine -bool false
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
sudo systemsetup -setusingnetworktime on 2>/dev/null || true
chflags nohidden "$HOME/Library"
ok "Firewall+stealth | No sleep on AC | Password on wake | No quarantine dialogs | ~/Library visible"

killall Dock Finder SystemUIServer 2>/dev/null || true

# ════════════════════════════════════════════════════════════════════════════
update_section "Authorizations & Privacy"
# ════════════════════════════════════════════════════════════════════════════

info "Xcode license + Gatekeeper..."
sudo xcodebuild -license accept >> "$LOG_FILE" 2>&1 || true
sudo spctl --global-enable 2>/dev/null || true
ok "Xcode license accepted | Gatekeeper enabled (identified developers)"

info "SSH key setup..."
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  ssh-keygen -t ed25519 -C "heyfinal" -f "$HOME/.ssh/id_ed25519" -N "" -q
  ok "SSH ed25519 key generated"
else
  ok "SSH ed25519 key already exists"
fi
ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" 2>/dev/null || true
if ! grep -q "ServerAliveInterval" "$HOME/.ssh/config" 2>/dev/null; then
  cat >> "$HOME/.ssh/config" << 'EOF'
Host *
  ServerAliveInterval 60
  ServerAliveCountMax 3
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
  chmod 600 "$HOME/.ssh/config"
  ok "SSH config written"
else
  ok "SSH config already present"
fi

# ════════════════════════════════════════════════════════════════════════════
update_section "Homebrew Packages"
# ════════════════════════════════════════════════════════════════════════════

info "Updating Homebrew..."
brew update >> "$LOG_FILE" 2>&1
ok "Homebrew updated"

install_brew_batch "CLI essentials" \
  git gh wget curl jq yq fzf ripgrep bat eza fd tree htop bottom tldr zoxide watch duf tmux rsync gnupg

install_brew_batch "Dev runtimes" \
  python@3.12 uv pipx go openjdk

# Rust
if ! $AS_USER bash -c 'command -v rustup' &>/dev/null; then
  item_progress "rust (rustup)" 1 1
  $AS_USER bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --quiet' >> "$LOG_FILE" 2>&1
  printf "\r  ${GREEN}✓${NC}  %-65s\n" "Rust installed via rustup"
else
  ok "Rust already installed"
fi

# NVM + Node
if [ ! -d "$REAL_HOME/.nvm" ]; then
  item_progress "nvm + node LTS" 1 1
  $AS_USER bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash' >> "$LOG_FILE" 2>&1
fi
$AS_USER bash -c "
  export NVM_DIR=\"$REAL_HOME/.nvm\"
  [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
  nvm install --lts && nvm use --lts
" >> "$LOG_FILE" 2>&1 || true
printf "\r  ${GREEN}✓${NC}  %-65s\n" "Node LTS installed via nvm"

install_brew_batch "Network & security" \
  nmap netcat mtr httpie iperf3 whois dnsmasq

install_brew_batch "Database & queue" \
  redis sqlite

brew services start redis >> "$LOG_FILE" 2>&1 || true
ok "Redis service started"

install_brew_batch "Containers" \
  docker docker-compose

install_brew_batch "Git extras" \
  git-lfs lazygit diff-so-fancy

git lfs install --skip-repo >> "$LOG_FILE" 2>&1 || true

install_brew_batch "macOS utilities" \
  mas dockutil switchaudio-osx blueutil

# Symlink Java
sudo ln -sfn "$HOMEBREW_PREFIX/opt/openjdk/libexec/openjdk.jdk" \
  /Library/Java/JavaVirtualMachines/openjdk.jdk >> "$LOG_FILE" 2>&1 || true
ok "Java symlinked to /Library/Java/JavaVirtualMachines"

# ════════════════════════════════════════════════════════════════════════════
update_section "Applications (Casks)"
# ════════════════════════════════════════════════════════════════════════════

install_cask_batch "Apps" \
  iterm2 visual-studio-code google-chrome raycast proxyman wireshark \
  tableplus insomnia bruno docker balenaetcher handbrake \
  font-meslo-lg-nerd-font

# ════════════════════════════════════════════════════════════════════════════
update_section "Shell Configuration"
# ════════════════════════════════════════════════════════════════════════════

ZSHRC="$HOME/.zshrc"
if ! grep -q "# ── heyfinal dotmalt ──" "$ZSHRC" 2>/dev/null; then
  info "Writing ~/.zshrc..."
  cat >> "$ZSHRC" << ZSHRC_BLOCK

# ── heyfinal dotmalt ────────────────────────────────────────────────────────

# PATH
export PATH="${HOMEBREW_PREFIX}/bin:/usr/local/bin:\$PATH"
export PATH="\$HOME/.local/bin:\$PATH"
export GOPATH="\$HOME/go"
export PATH="\$GOPATH/bin:\$PATH"
export PATH="\$HOME/.cargo/bin:\$PATH"
export JAVA_HOME="${HOMEBREW_PREFIX}/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
export PATH="\$JAVA_HOME/bin:\$PATH"

# nvm
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"

# zoxide (smart cd)
eval "\$(zoxide init zsh)"

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# iTerm2 shell integration
[ -f ~/.iterm2_shell_integration.zsh ] && source ~/.iterm2_shell_integration.zsh

# API keys
[ -f "\$HOME/.env_secrets" ] && source "\$HOME/.env_secrets"

# Aliases
alias ll='eza -la --git'
alias cat='bat'
alias grep='rg'
alias top='btm'
alias py='python3'
alias venv='python3 -m venv venv && source venv/bin/activate'
alias activate='source venv/bin/activate'
alias ports='lsof -i -P -n | grep LISTEN'
alias myip='curl -s ifconfig.me'
alias flushdns='sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder'
ZSHRC_BLOCK
  ok "~/.zshrc updated (PATH, nvm, zoxide, fzf, aliases)"
else
  ok "~/.zshrc already configured"
fi

"$HOMEBREW_PREFIX/opt/fzf/install" --all --no-bash --no-fish --no-update-rc >> "$LOG_FILE" 2>&1 || true
ok "fzf shell integration installed"

# ════════════════════════════════════════════════════════════════════════════
update_section "Git Configuration"
# ════════════════════════════════════════════════════════════════════════════

git config --global user.name "heyfinal"
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global core.editor nano
git config --global core.pager "diff-so-fancy | less --tabs=4 -RFX"
git config --global credential.helper osxkeychain
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.lg "log --oneline --graph --decorate --all"
cat > "$HOME/.gitignore_global" << 'EOF'
.DS_Store
.env
.env.*
__pycache__/
*.py[cod]
.venv/
venv/
node_modules/
*.log
.idea/
.vscode/
*.swp
EOF
git config --global core.excludesfile "$HOME/.gitignore_global"
ok "Git: heyfinal | main branch | nano | diff-so-fancy | aliases (st co br lg)"

# ════════════════════════════════════════════════════════════════════════════
update_section "Python Environment"
# ════════════════════════════════════════════════════════════════════════════

pipx ensurepath >> "$LOG_FILE" 2>&1 || true
install_pipx_batch black ruff mypy httpie yt-dlp rich-cli

# ════════════════════════════════════════════════════════════════════════════
update_section "AI CLIs"
# ════════════════════════════════════════════════════════════════════════════

if $AS_USER bash -c "export NVM_DIR=\"$REAL_HOME/.nvm\"; [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"; command -v npm" &>/dev/null; then
  install_npm_batch \
    @anthropic-ai/claude-code \
    @openai/codex \
    @google/gemini-cli
else
  warn "npm not available — re-run after: source ~/.zshrc"
fi

# ════════════════════════════════════════════════════════════════════════════
update_section "Claude Code — MCP Servers"
# ════════════════════════════════════════════════════════════════════════════

mkdir -p "$HOME/databases"

info "Writing ~/.claude.json (13 MCP servers)..."

GH_TOKEN_VAL=""
[ -f "$HOME/.env_secrets" ] && \
  GH_TOKEN_VAL=$(grep 'export GH_TOKEN=' "$HOME/.env_secrets" 2>/dev/null | cut -d'"' -f2 || echo "")

MCP_SERVERS=(
  "filesystem" "puppeteer" "memory" "github" "git"
  "playwright" "sqlite" "postgres" "redis"
  "sequential-thinking" "fetch" "duckduckgo" "youtube" "osquery"
)
TOTAL_MCP=${#MCP_SERVERS[@]}
i=0
for srv in "${MCP_SERVERS[@]}"; do
  ((i++))
  item_progress "$srv" "$i" "$TOTAL_MCP"
  sleep 0.05  # visual beat — actual write is one shot below
done

cat > "$HOME/.claude.json" << EOF
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "$HOME", "/tmp"]
    },
    "memory": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GH_TOKEN_VAL}" }
    },
    "git": {
      "command": "uvx",
      "args": ["mcp-server-git", "--repository", "$HOME"]
    },
    "puppeteer": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-puppeteer"]
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@executeautomation/playwright-mcp-server"]
    },
    "sqlite": {
      "command": "uvx",
      "args": ["mcp-server-sqlite", "--db-path", "$HOME/databases/local.db"]
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres", "postgresql://localhost/dev"]
    },
    "redis": {
      "command": "npx",
      "args": ["-y", "mcp-server-redis"],
      "env": { "REDIS_URL": "redis://localhost:6379" }
    },
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    },
    "fetch": {
      "command": "uvx",
      "args": ["mcp-server-fetch"]
    },
    "duckduckgo": {
      "command": "npx",
      "args": ["-y", "duckduckgo-mcp-server"]
    },
    "youtube": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-youtube-transcript"]
    },
    "osquery": {
      "command": "npx",
      "args": ["-y", "osquery-mcp-server"]
    }
  }
}
EOF
printf "\r  ${GREEN}✓${NC}  %-65s\n" "~/.claude.json written (14 MCP servers)"

# ════════════════════════════════════════════════════════════════════════════
update_section "Claude Code — Settings & Config"
# ════════════════════════════════════════════════════════════════════════════

mkdir -p "$HOME/.claude/hooks" "$HOME/.claude/backups"

info "Writing ~/.claude/settings.json..."
cat > "$HOME/.claude/settings.json" << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash(*)",
      "Read(*)",
      "Write(*)",
      "Edit(*)",
      "Glob(*)",
      "Grep(*)",
      "WebFetch(*)",
      "WebSearch(*)",
      "Task(*)",
      "NotebookEdit(*)",
      "mcp__filesystem__*",
      "mcp__memory__*",
      "mcp__github__*",
      "mcp__git__*",
      "mcp__puppeteer__*",
      "mcp__playwright__*",
      "mcp__sqlite__*",
      "mcp__postgres__*",
      "mcp__redis__*",
      "mcp__sequential-thinking__*",
      "mcp__fetch__*",
      "mcp__duckduckgo__*",
      "mcp__youtube__*",
      "mcp__osquery__*"
    ],
    "deny": []
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/pre_backup.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "osascript -e 'display notification \"Task complete\" with title \"Claude Code\" sound name \"Glass\"' 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
EOF
ok "~/.claude/settings.json written"

info "Installing pre-backup hook..."
cat > "$HOME/.claude/hooks/pre_backup.sh" << 'EOF'
#!/bin/bash
FILE="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"
if [ -n "$FILE" ] && [ -f "$FILE" ]; then
  BACKUP_DIR="$HOME/.claude/backups/$(date +%Y%m%d)"
  mkdir -p "$BACKUP_DIR"
  cp "$FILE" "$BACKUP_DIR/$(basename "$FILE").$(date +%H%M%S).bak" 2>/dev/null || true
fi
EOF
chmod +x "$HOME/.claude/hooks/pre_backup.sh"
ok "Pre-backup hook installed"

info "Writing ~/CLAUDE.md..."
cat > "$HOME/CLAUDE.md" << 'EOF'
# Claude Code — Global Configuration

## User
- Handle: heyfinal
- GitHub: https://github.com/heyfinal

## Hard Rules
- NEVER auto-generate demo, placeholder, or mock code in any project
- NEVER commit code unless explicitly asked
- NEVER add boilerplate, stubs, or example data unless specifically instructed
- Do not add docstrings, comments, or type annotations to code you didn't touch
- Avoid over-engineering — minimum complexity for the task at hand
- Do not create README or documentation files unless explicitly requested

## Dev Environment
- Python: 3.12
- Formatter: black
- Linter: ruff
- Type checker: mypy
- Package manager: uv (not pip directly)
- Shell: zsh
- Default editor: nano

## AI Delegation Strategy
You are the parent orchestrator. Delegate to reduce API usage. Audit all subagent output before accepting.

**→ Codex** — fast code gen, refactors, boilerplate, syntax-heavy tasks
```
codex "<prompt>"
```

**→ Gemini** — long context, doc review, large file analysis, research
```
gemini "<prompt>"
```

**→ DeepSeek** — code-specific algorithms, implementation detail
Use `mcp__deepseek` tools if available

**Audit rule:** You are responsible for correctness, security, and style of all delegated output.

## Stack Reference
- AI APIs: Anthropic Claude, OpenAI GPT-4, Google Gemini, DeepSeek
- MCP Servers: filesystem, memory, github, git, puppeteer, playwright, sqlite, postgres, redis, sequential-thinking, fetch, duckduckgo, youtube, osquery
- Python: aiohttp, fastapi, playwright, openai, google-generativeai, pandas, sqlalchemy, click, rich, psutil, paramiko
- Runtime: Docker, Redis (local), SQLite
- Shell: eza, bat, ripgrep, fzf, zoxide, lazygit, tmux
EOF
ok "~/CLAUDE.md written"

# ════════════════════════════════════════════════════════════════════════════
update_section "API Keys"
# ════════════════════════════════════════════════════════════════════════════

SECRETS_FILE="$HOME/.env_secrets"
[ ! -f "$SECRETS_FILE" ] && touch "$SECRETS_FILE" && chmod 600 "$SECRETS_FILE"

prompt_key() {
  local key="$1"
  local current
  current=$(grep "^export ${key}=" "$SECRETS_FILE" 2>/dev/null | cut -d'"' -f2 || echo "")
  if [ -n "$current" ]; then
    ok "$key already set"
    return
  fi
  printf "  ${CYAN}→${NC}  %s: " "$key"
  read -r val 2>/dev/null || val=""
  [ -n "$val" ] && echo "export ${key}=\"${val}\"" >> "$SECRETS_FILE" && ok "$key saved" \
                || warn "$key skipped — add manually to ~/.env_secrets"
}

echo ""
info "Enter API keys (press Enter to skip):"
echo ""
prompt_key ANTHROPIC_API_KEY
prompt_key OPENAI_API_KEY
prompt_key DEEPSEEK_API_KEY
prompt_key GEMINI_API_KEY
prompt_key GH_TOKEN

chmod 600 "$SECRETS_FILE"
chown "$REAL_USER" "$SECRETS_FILE" 2>/dev/null || true
ok "~/.env_secrets saved (chmod 600, owned by $REAL_USER)"

# Inject GH_TOKEN into MCP config
GH_TOKEN_VAL=$(grep 'export GH_TOKEN=' "$SECRETS_FILE" 2>/dev/null | cut -d'"' -f2 || echo "")
if [ -n "$GH_TOKEN_VAL" ] && [ -f "$HOME/.claude.json" ]; then
  sed -i '' "s|\"GITHUB_PERSONAL_ACCESS_TOKEN\": \"\"|\"GITHUB_PERSONAL_ACCESS_TOKEN\": \"${GH_TOKEN_VAL}\"|" \
    "$HOME/.claude.json" 2>/dev/null || true
fi

# ════════════════════════════════════════════════════════════════════════════
update_section "iTerm2 Enhancements"
# ════════════════════════════════════════════════════════════════════════════

if [ ! -f "$HOME/.iterm2_shell_integration.zsh" ]; then
  item_progress "shell integration" 1 3
  curl -sL https://iterm2.com/shell_integration/zsh -o "$HOME/.iterm2_shell_integration.zsh" 2>/dev/null || true
else
  item_progress "shell integration" 1 3
fi

item_progress "Catppuccin Mocha theme" 2 3
THEME_PATH="$HOME/Downloads/Catppuccin-Mocha.itermcolors"
curl -sL "https://raw.githubusercontent.com/catppuccin/iterm/main/colors/Catppuccin-Mocha.itermcolors" \
  -o "$THEME_PATH" 2>/dev/null || true
[ -f "$THEME_PATH" ] && open "$THEME_PATH" 2>/dev/null || true

item_progress "tmux.conf" 3 3
if [ ! -f "$HOME/.tmux.conf" ]; then
  cat > "$HOME/.tmux.conf" << 'EOF'
# Launch with iTerm2 native mode: tmux -CC new-session
set -g default-terminal "xterm-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
set -g mouse on
set -g history-limit 50000
set -g base-index 1
set -g pane-base-index 1
set -g status-bg black
set -g status-fg white
set -g status-left "#[fg=cyan] #S  "
set -g status-right "#[fg=yellow]%H:%M  %d-%b "
EOF
fi
defaults write com.googlecode.iterm2 ShowStatusBar -bool true 2>/dev/null || true

printf "\r  ${GREEN}✓${NC}  %-65s\n" "iTerm2: shell integration + Catppuccin Mocha + tmux.conf"

# ════════════════════════════════════════════════════════════════════════════
# Seal the overall progress bar at 100%
tput sc
  tput cup $PROGRESS_ROW 0; tput el
  printf "  ${TAN}Overall${NC} [${GREEN}%s${NC}] ${GREEN}100%%${NC}  All %d sections complete ✓" \
    "$(printf '█%.0s' $(seq 1 40))" "$TOTAL_SECTIONS"
  tput cup $SECTION_ROW 0; tput el
  printf "  ${GREEN}✓${NC}  ${BOLD}Setup complete${NC}"
tput rc

# ── Final summary ─────────────────────────────────────────────────────────────
echo ""
printf "${TAN}"; printf '━%.0s' $(seq 1 "$TERM_COLS"); printf "${NC}\n"
echo ""
ok "All done. Manual steps:"
echo ""
printf "  ${CYAN}1.${NC}  Restart iTerm2 → Preferences → Profile → Text → Font → ${BOLD}MesloLGS NF${NC}\n"
printf "  ${CYAN}2.${NC}  System Settings → Privacy → Full Disk Access → add ${BOLD}iTerm2${NC}\n"
printf "  ${CYAN}3.${NC}  Run: ${CYAN}source ~/.zshrc${NC}\n"
printf "  ${CYAN}4.${NC}  iTerm2 native tmux mode: ${CYAN}tmux -CC new-session${NC}\n"
printf "  ${CYAN}5.${NC}  Add ANTHROPIC_API_KEY to ${CYAN}~/.env_secrets${NC} if skipped above\n"
echo ""
printf "  SSH public key (add to github.com/settings/keys):\n"
echo ""
printf "  ${CYAN}%s${NC}\n" "$(cat "$HOME/.ssh/id_ed25519.pub" 2>/dev/null || echo 'key not found')"
echo ""
printf "  Full log: ${CYAN}%s${NC}\n" "$LOG_FILE"
echo ""
printf "${TAN}"; printf '━%.0s' $(seq 1 "$TERM_COLS"); printf "${NC}\n"
echo ""
