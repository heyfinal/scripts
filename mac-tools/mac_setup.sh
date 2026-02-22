#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────── #
# Assumes Homebrew is already installed.
# If not: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# ─────────────────────────────────────────────────────────────────────────── #

LOG_FILE="/tmp/mac_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ── Colors ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
TAN='\033[38;5;180m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ── Banner ──────────────────────────────────────────────────────────────────
banner() {
  echo -en "${TAN}"
  cat << 'EOF'

       ,,             ,...                   ,,
     `7MM           .d' ""                 `7MM   mm
       MM           dM`                      MM   MM
  ,M""bMM  .gP"Ya  mMMmm ,6"Yb.`7MM  `7MM    MM mmMMmm
,AP    MM ,M'   Yb  MM  8)   MM  MM    MM    MM   MM
8MI    MM 8M""""""  MM   ,pm9MM  MM    MM    MM   MM
`Mb    MM YM.    ,  MM  8M   MM  MM    MM    MM   MM
 `Wbmd"MML.`Mbmmd'.JMML.`Moo9^Yo.`Mbod"YML..JMML. `Mbmo

EOF
  printf "${NC}\n"
}

clear
banner

# ── Helpers ─────────────────────────────────────────────────────────────────
ok()      { echo -e "${GREEN}  ✓${NC}  $1"; }
info()    { echo -e "${CYAN}  →${NC}  $1"; }
warn()    { echo -e "${YELLOW}  ⚠${NC}  $1"; }
section() { echo -e "\n${TAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n  $1\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

brew_pkg() {
  if brew list "$1" &>/dev/null 2>&1; then
    ok "$1 already installed"
  else
    info "Installing $1..."
    brew install "$1" 2>&1 || warn "Failed: $1"
  fi
}

brew_cask() {
  if brew list --cask "$1" &>/dev/null 2>&1; then
    ok "$1 already installed"
  else
    info "Installing $1..."
    brew install --cask "$1" 2>&1 || warn "Failed: $1"
  fi
}

pipx_pkg() {
  if pipx list 2>/dev/null | grep -q "package $1"; then
    ok "$1 already installed"
  else
    info "Installing $1 via pipx..."
    pipx install "$1" 2>&1 || warn "Failed: $1"
  fi
}

# ── Homebrew check ──────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  echo ""
  warn "Homebrew is not installed."
  echo ""
  echo "  Run this command first, then re-run this script:"
  echo ""
  echo -e "  ${CYAN}/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${NC}"
  echo ""
  exit 1
fi

# Detect Apple Silicon vs Intel
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
fi
ok "Homebrew found at $HOMEBREW_PREFIX"

# ── Sudo primer ─────────────────────────────────────────────────────────────
echo ""
info "This script requires sudo for some steps. Enter your password once:"
sudo -v
# Keep sudo alive for the duration of the script
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_PID=$!
trap "kill $SUDO_PID 2>/dev/null; exit" INT TERM EXIT

# ════════════════════════════════════════════════════════════════════════════
section "1 · macOS System Preferences"
# ════════════════════════════════════════════════════════════════════════════

# ── Dock ─────────────────────────────────────────────────────────────────────
info "Dock..."
defaults write com.apple.dock tilesize -int 32
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock largesize -int 64
defaults write com.apple.dock orientation -string "bottom"
defaults write com.apple.dock show-recents -bool false
ok "Dock: small icons, magnify on hover, bottom, no recent apps"

# ── Mouse ─────────────────────────────────────────────────────────────────────
info "Mouse..."
defaults write -g com.apple.mouse.scaling -float 3.0
defaults write com.apple.AppleMultitouchMouse MouseButtonMode -string "TwoButton"
defaults write -g com.apple.swipescrolldirection -bool false
ok "Mouse: max speed, right-click on, scroll non-reverse"

# ── Keyboard ─────────────────────────────────────────────────────────────────
info "Keyboard..."
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2
ok "Keyboard: fast repeat, short delay"

# ── Finder ───────────────────────────────────────────────────────────────────
info "Finder..."
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder _FXSortFoldersFirst -bool true
ok "Finder: list view, hidden files, all extensions, path+status bar, folders first"

# ── TextEdit ─────────────────────────────────────────────────────────────────
info "TextEdit..."
defaults write com.apple.TextEdit RichText -int 0
ok "TextEdit: default to plain text (.txt)"

# ── Screenshots ──────────────────────────────────────────────────────────────
info "Screenshots..."
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Screenshots"
defaults write com.apple.screencapture type -string "jpg"
ok "Screenshots → ~/Screenshots (JPG)"

# ── Menu Bar ─────────────────────────────────────────────────────────────────
info "Menu Bar..."
defaults write com.apple.menuextra.clock ShowDate -int 1
defaults write com.apple.menuextra.clock DateFormat -string "EEE d MMM  HH:mm"
ok "Menu bar clock: date + day"

# ── Security ─────────────────────────────────────────────────────────────────
info "Security..."
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null || true
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on 2>/dev/null || true
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
ok "Firewall on, stealth mode on, password required immediately on wake"

# ── Power ────────────────────────────────────────────────────────────────────
info "Power..."
sudo pmset -c sleep 0
sudo pmset -c disksleep 0
ok "Sleep disabled on AC power"

# ── Misc ─────────────────────────────────────────────────────────────────────
info "Misc system settings..."
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write com.apple.CrashReporter DialogType -string "none"
defaults write com.apple.LaunchServices LSQuarantine -bool false
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
sudo systemsetup -setusingnetworktime on 2>/dev/null || true
chflags nohidden "$HOME/Library"
ok "Expanded save panel, no crash dialogs, no quarantine prompt, tap-to-click on login, auto timezone, ~/Library visible"

# Restart UI services
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

# ════════════════════════════════════════════════════════════════════════════
section "2 · Authorizations & Privacy"
# ════════════════════════════════════════════════════════════════════════════

# Xcode license
info "Accepting Xcode license..."
sudo xcodebuild -license accept 2>/dev/null || true
ok "Xcode license accepted"

# Allow apps from identified developers (Gatekeeper stays on)
info "Gatekeeper..."
sudo spctl --global-enable 2>/dev/null || true
ok "Gatekeeper enabled (identified developers allowed)"

# SSH key generation
info "SSH key setup..."
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  ssh-keygen -t ed25519 -C "heyfinal" -f "$HOME/.ssh/id_ed25519" -N "" -q
  ok "SSH key generated: ~/.ssh/id_ed25519"
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
  ok "SSH config written (~/.ssh/config)"
else
  ok "SSH config already configured"
fi

# Privacy permissions — must be done manually
echo ""
warn "Manual step required — iTerm2 privacy permissions:"
echo "    Full Disk Access  →  System Settings → Privacy & Security → Full Disk Access"
echo "    Accessibility     →  System Settings → Privacy & Security → Accessibility"
echo "    Automation        →  System Settings → Privacy & Security → Automation"
echo ""
read -p "  Press Enter to open Accessibility settings now (or Ctrl+C to skip)..." _REPLY 2>/dev/null || true
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true

# ════════════════════════════════════════════════════════════════════════════
section "3 · Homebrew Packages"
# ════════════════════════════════════════════════════════════════════════════

info "Updating Homebrew..."
brew update 2>&1 | tail -1

# ── CLI Essentials ────────────────────────────────────────────────────────────
info "CLI essentials..."
for pkg in git gh wget curl jq yq fzf ripgrep bat eza fd tree htop bottom tldr zoxide watch duf tmux rsync gnupg; do
  brew_pkg "$pkg"
done

# ── Dev Runtimes ──────────────────────────────────────────────────────────────
info "Dev runtimes..."
brew_pkg python@3.12
brew_pkg uv
brew_pkg pipx
brew_pkg go
brew_pkg openjdk

# Java JAVA_HOME symlink
sudo ln -sfn "$HOMEBREW_PREFIX/opt/openjdk/libexec/openjdk.jdk" /Library/Java/JavaVirtualMachines/openjdk.jdk 2>/dev/null || true

# Rust
if ! command -v rustup &>/dev/null; then
  info "Installing Rust via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --quiet
  ok "Rust installed"
else
  ok "Rust already installed"
fi

# NVM + Node LTS
if [ ! -d "$HOME/.nvm" ]; then
  info "Installing nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh 2>/dev/null | bash 2>/dev/null
fi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 2>/dev/null || true
nvm install --lts 2>/dev/null && nvm use --lts 2>/dev/null || true
ok "Node LTS installed via nvm"

# ── Network / Security ────────────────────────────────────────────────────────
info "Network & security tools..."
for pkg in nmap netcat mtr httpie iperf3 whois dnsmasq; do
  brew_pkg "$pkg"
done

# tshark (Wireshark CLI) — installed via cask which includes both
# ── Database / Queue ──────────────────────────────────────────────────────────
info "Database tools..."
brew_pkg redis
brew_pkg sqlite

# Auto-start redis on login
brew services start redis 2>/dev/null || true
ok "Redis service started"

# ── Containers ────────────────────────────────────────────────────────────────
info "Container tools..."
brew_pkg docker
brew_pkg docker-compose

# ── Git Extras ────────────────────────────────────────────────────────────────
info "Git extras..."
brew_pkg git-lfs
brew_pkg lazygit
brew_pkg diff-so-fancy
git lfs install --skip-repo 2>/dev/null || true

# ── macOS Utilities ───────────────────────────────────────────────────────────
info "macOS utilities..."
brew_pkg mas
brew_pkg dockutil
brew_pkg switchaudio-osx
brew_pkg blueutil

# ════════════════════════════════════════════════════════════════════════════
section "4 · Applications"
# ════════════════════════════════════════════════════════════════════════════

brew_cask iterm2
brew_cask visual-studio-code
brew_cask google-chrome
brew_cask raycast
brew_cask proxyman
brew_cask wireshark
brew_cask tableplus
brew_cask insomnia
brew_cask bruno
brew_cask docker
brew_cask balenaetcher
brew_cask handbrake

# Font for iTerm2 / powerlevel10k
brew_cask font-meslo-lg-nerd-font

# ════════════════════════════════════════════════════════════════════════════
section "5 · Shell Configuration"
# ════════════════════════════════════════════════════════════════════════════

ZSHRC="$HOME/.zshrc"

if ! grep -q "# ── heyfinal dotmalt ──" "$ZSHRC" 2>/dev/null; then
  info "Writing ~/.zshrc config..."
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
  ok "~/.zshrc updated"
else
  ok "~/.zshrc already configured"
fi

# fzf shell integration
"$HOMEBREW_PREFIX/opt/fzf/install" --all --no-bash --no-fish --no-update-rc 2>/dev/null || true

# ════════════════════════════════════════════════════════════════════════════
section "6 · Git Configuration"
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
ok "Git configured (heyfinal, main, nano, diff-so-fancy, aliases)"

# ════════════════════════════════════════════════════════════════════════════
section "7 · Python Environment"
# ════════════════════════════════════════════════════════════════════════════

pipx ensurepath 2>/dev/null || true

for tool in black ruff mypy httpie yt-dlp rich-cli; do
  pipx_pkg "$tool"
done

# ════════════════════════════════════════════════════════════════════════════
section "8 · AI CLIs"
# ════════════════════════════════════════════════════════════════════════════

# Ensure npm is available
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 2>/dev/null || true

if command -v npm &>/dev/null; then
  info "Installing Claude Code..."
  npm install -g @anthropic-ai/claude-code 2>/dev/null && ok "Claude Code installed" || warn "Claude Code install failed"

  info "Installing OpenAI Codex..."
  npm install -g @openai/codex 2>/dev/null && ok "Codex installed" || warn "Codex install failed"

  info "Installing Gemini CLI..."
  npm install -g @google/gemini-cli 2>/dev/null && ok "Gemini CLI installed" || warn "Gemini CLI install failed"
else
  warn "npm not available — skipping AI CLI installs. Run manually after restarting shell."
fi

# ════════════════════════════════════════════════════════════════════════════
section "9 · Claude Code — MCP Servers"
# ════════════════════════════════════════════════════════════════════════════

mkdir -p "$HOME/databases"

info "Writing MCP server config to ~/.claude.json..."

# Load GH_TOKEN if available
SECRETS_FILE="$HOME/.env_secrets"
GH_TOKEN_VAL=""
if [ -f "$SECRETS_FILE" ]; then
  GH_TOKEN_VAL=$(grep 'export GH_TOKEN=' "$SECRETS_FILE" 2>/dev/null | cut -d'"' -f2 || echo "")
fi

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
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GH_TOKEN_VAL}"
      }
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
      "env": {
        "REDIS_URL": "redis://localhost:6379"
      }
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
ok "~/.claude.json written (13 MCP servers)"

# ════════════════════════════════════════════════════════════════════════════
section "10 · Claude Code — Settings & Config"
# ════════════════════════════════════════════════════════════════════════════

mkdir -p "$HOME/.claude/hooks"
mkdir -p "$HOME/.claude/backups"

# ── settings.json ────────────────────────────────────────────────────────────
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
ok "~/.claude/settings.json written (all tools allowed, hooks enabled)"

# ── Pre-backup hook ───────────────────────────────────────────────────────────
info "Installing pre-backup hook..."
cat > "$HOME/.claude/hooks/pre_backup.sh" << 'EOF'
#!/bin/bash
# Auto-backup files before Write/Edit operations
FILE="${CLAUDE_TOOL_INPUT_FILE_PATH:-}"
if [ -n "$FILE" ] && [ -f "$FILE" ]; then
  BACKUP_DIR="$HOME/.claude/backups/$(date +%Y%m%d)"
  mkdir -p "$BACKUP_DIR"
  cp "$FILE" "$BACKUP_DIR/$(basename "$FILE").$(date +%H%M%S).bak" 2>/dev/null || true
fi
EOF
chmod +x "$HOME/.claude/hooks/pre_backup.sh"
ok "Pre-backup hook installed (~/.claude/hooks/pre_backup.sh)"

# ── CLAUDE.md ─────────────────────────────────────────────────────────────────
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
- Python stack: aiohttp, fastapi, playwright, openai, google-generativeai, pandas, sqlalchemy, click, rich, psutil, paramiko
- Runtime: Docker, Redis (local), SQLite
- Shell tools: eza, bat, ripgrep, fzf, zoxide, lazygit, tmux
EOF
ok "~/CLAUDE.md written"

# ════════════════════════════════════════════════════════════════════════════
section "11 · API Keys"
# ════════════════════════════════════════════════════════════════════════════

SECRETS_FILE="$HOME/.env_secrets"

if [ ! -f "$SECRETS_FILE" ]; then
  touch "$SECRETS_FILE"
  chmod 600 "$SECRETS_FILE"
fi

prompt_key() {
  local key_name="$1"
  local current_val
  current_val=$(grep "^export ${key_name}=" "$SECRETS_FILE" 2>/dev/null | cut -d'"' -f2 || echo "")
  if [ -n "$current_val" ]; then
    ok "$key_name already set"
    return
  fi
  echo -n "  ${CYAN}→${NC}  $key_name: "
  read -r input_val 2>/dev/null || input_val=""
  if [ -n "$input_val" ]; then
    echo "export ${key_name}=\"${input_val}\"" >> "$SECRETS_FILE"
    ok "$key_name saved"
  else
    warn "$key_name skipped — add manually to ~/.env_secrets"
  fi
}

echo ""
info "Enter API keys (press Enter to skip any):"
echo ""
prompt_key ANTHROPIC_API_KEY
prompt_key OPENAI_API_KEY
prompt_key DEEPSEEK_API_KEY
prompt_key GEMINI_API_KEY
prompt_key GH_TOKEN

chmod 600 "$SECRETS_FILE"
ok "~/.env_secrets saved (chmod 600)"

# Inject GH_TOKEN into MCP config
GH_TOKEN_VAL=$(grep 'export GH_TOKEN=' "$SECRETS_FILE" 2>/dev/null | cut -d'"' -f2 || echo "")
if [ -n "$GH_TOKEN_VAL" ] && [ -f "$HOME/.claude.json" ]; then
  # Only replace if still empty placeholder
  sed -i '' "s/\"GITHUB_PERSONAL_ACCESS_TOKEN\": \"\"/\"GITHUB_PERSONAL_ACCESS_TOKEN\": \"${GH_TOKEN_VAL}\"/" "$HOME/.claude.json" 2>/dev/null || true
fi

# ════════════════════════════════════════════════════════════════════════════
section "12 · iTerm2 Enhancements"
# ════════════════════════════════════════════════════════════════════════════

# Shell integration
if [ ! -f "$HOME/.iterm2_shell_integration.zsh" ]; then
  info "Installing iTerm2 shell integration..."
  curl -sL https://iterm2.com/shell_integration/zsh -o "$HOME/.iterm2_shell_integration.zsh" 2>/dev/null || true
  ok "iTerm2 shell integration installed"
else
  ok "iTerm2 shell integration already installed"
fi

# Catppuccin Mocha color scheme
info "Downloading Catppuccin Mocha iTerm2 theme..."
THEME_PATH="$HOME/Downloads/Catppuccin-Mocha.itermcolors"
curl -sL "https://raw.githubusercontent.com/catppuccin/iterm/main/colors/Catppuccin-Mocha.itermcolors" \
  -o "$THEME_PATH" 2>/dev/null || true
if [ -f "$THEME_PATH" ]; then
  open "$THEME_PATH" 2>/dev/null || true
  ok "Catppuccin Mocha opened — click OK in iTerm2 to import"
fi

# tmux config
if [ ! -f "$HOME/.tmux.conf" ]; then
  info "Writing ~/.tmux.conf..."
  cat > "$HOME/.tmux.conf" << 'EOF'
# iTerm2 native tmux mode: launch with  tmux -CC new-session
set -g default-terminal "xterm-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
set -g mouse on
set -g history-limit 50000
set -g base-index 1
set -g pane-base-index 1
set -g status-bg black
set -g status-fg white
set -g status-left "#[fg=cyan] #S "
set -g status-right "#[fg=yellow]%H:%M %d-%b "
EOF
  ok "~/.tmux.conf written (mouse on, 256color, status bar)"
else
  ok "~/.tmux.conf already exists"
fi

# iTerm2 status bar (set via defaults — requires iTerm2 restart to take effect)
info "Configuring iTerm2 status bar..."
defaults write com.googlecode.iterm2 ShowStatusBar -bool true 2>/dev/null || true
ok "iTerm2 status bar enabled (restart iTerm2 to see it)"

# ════════════════════════════════════════════════════════════════════════════
# Done
# ════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${TAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Setup complete.${NC}"
echo ""
echo "  Manual steps remaining:"
echo "  1. Restart iTerm2 → Preferences → Profile → Text → Font → MesloLGS NF"
echo "  2. Grant Full Disk Access + Accessibility to iTerm2 in System Settings"
echo "  3. Run: source ~/.zshrc"
echo "  4. Start tmux with native iTerm2 mode: tmux -CC new-session"
echo ""
echo "  Your SSH public key (add to GitHub → Settings → SSH Keys):"
echo ""
cat "$HOME/.ssh/id_ed25519.pub" 2>/dev/null || warn "No SSH key found"
echo ""
echo -e "  Full log: ${CYAN}/tmp/mac_setup.log${NC}"
echo -e "${TAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Release sudo
kill $SUDO_PID 2>/dev/null || true
trap - INT TERM EXIT
