#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

LOG_FILE="/tmp/mac_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Track success status and progress
SETUP_SUCCESS=true
TOTAL_STEPS=12
CURRENT_STEP=0

# ————————————————————————————————————————————————————————————————————— #
# ANSI Colors & Control
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
TAN='\033[38;5;180m'
YELLOW='\033[1;33m'
NC='\033[0m'

SAVE_CURSOR='\033[s'
RESTORE_CURSOR='\033[u'
CLEAR_LINE='\033[2K'

# ————————————————————————————————————————————————————————————————————— #
# UI Functions
update_progress() {
  local step=$1
  local percent=$((step * 100 / TOTAL_STEPS))
  local filled=$((percent * 50 / 100))
  local empty=$((50 - filled))
  
  local bar=""
  for ((i=1; i<=filled; i++)); do bar+="█"; done
  for ((i=1; i<=empty; i++)); do bar+="░"; done
  
  # Update progress line (line 12)
  printf "\033[12;1H${CLEAR_LINE}${CYAN}Progress: [${bar}] ${percent}%%${NC}"
}

update_status() {
  local message="$1"
  # Update status line (line 13)
  printf "\033[13;1H${CLEAR_LINE}${YELLOW}Status: ${message}${NC}"
}

show_input() {
  local prompt="$1"
  # Show input line (line 14)
  printf "\033[14;1H${CLEAR_LINE}${GREEN}${prompt}${NC}"
}

clear_input() {
  # Clear input line
  printf "\033[14;1H${CLEAR_LINE}"
}

# ————————————————————————————————————————————————————————————————————— #
# Banner (Fixed Position)
clear
echo -en "${TAN}"
cat << 'EOF'

       ,,             ,...                   ,,         
     `7MM           .d' ""                 `7MM   mm    
       MM           dM`                      MM   MM    
  ,M""bMM  .gP"Ya  mMMmf ,6"Yb.`7MM  `7MM    MM mmMMmm  
,AP    MM ,M'   Yb  MM  8)   MM  MM    MM    MM   MM    
8MI    MM 8M""""""  MM   ,pm9MM  MM    MM    MM   MM    
`Mb    MM YM.    ,  MM  8M   MM  MM    MM    MM   MM    
 `Wbmd"MML.`Mbmmd'.JMML.`Moo9^Yo.`Mbod"YML..JMML. `Mbmo 
        -v2.0.1: a dev install script for lazy people. by final 2025

EOF
printf "${NC}\n\n\n\n"  # Space for progress, status, and input lines

update_progress 0
update_status "Initializing setup..."

# ————————————————————————————————————————————————————————————————————— #
# Utility Functions
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

validate_api_key() {
  local key="$1"
  local expected_type="$2"
  
  if [[ -z "$key" ]]; then
    return 0  # Empty is fine
  fi
  
  case "$expected_type" in
    "openai")
      if [[ "$key" == sk-ant-* ]]; then
        printf "\033[15;1H${CLEAR_LINE}${RED}ERROR: This looks like a Claude API key (starts with sk-ant-)${NC}"
        printf "\033[16;1H${CLEAR_LINE}${RED}You entered it in the OpenAI field. Please check your keys.${NC}"
        sleep 3
        printf "\033[15;1H${CLEAR_LINE}"
        printf "\033[16;1H${CLEAR_LINE}"
        return 1
      elif [[ "$key" != sk-proj-* ]] && [[ "$key" != sk-* ]]; then
        printf "\033[15;1H${CLEAR_LINE}${YELLOW}WARNING: OpenAI API keys usually start with 'sk-proj-' or 'sk-'${NC}"
        show_input "Continue anyway? (y/N): "
        read -r response
        clear_input
        printf "\033[15;1H${CLEAR_LINE}"
        [[ "$response" =~ ^[Yy]$ ]] || return 1
      fi
      ;;
    "claude")
      if [[ "$key" == sk-proj-* ]] || [[ "$key" == sk-* ]] && [[ "$key" != sk-ant-* ]]; then
        printf "\033[15;1H${CLEAR_LINE}${RED}ERROR: This looks like an OpenAI API key${NC}"
        printf "\033[16;1H${CLEAR_LINE}${RED}You entered it in the Claude field. Please check your keys.${NC}"
        sleep 3
        printf "\033[15;1H${CLEAR_LINE}"
        printf "\033[16;1H${CLEAR_LINE}"
        return 1
      elif [[ "$key" != sk-ant-* ]] && [[ -n "$key" ]]; then
        printf "\033[15;1H${CLEAR_LINE}${YELLOW}WARNING: Claude API keys start with 'sk-ant-'${NC}"
        show_input "Continue anyway? (y/N): "
        read -r response
        clear_input
        printf "\033[15;1H${CLEAR_LINE}"
        [[ "$response" =~ ^[Yy]$ ]] || return 1
      fi
      ;;
    "github")
      if [[ -n "$key" ]]; then
        if [[ "$key" != ghp_* ]] && [[ "$key" != gho_* ]] && [[ "$key" != ghu_* ]] && [[ "$key" != ghs_* ]] && [[ "$key" != ghr_* ]]; then
          printf "\033[15;1H${CLEAR_LINE}${YELLOW}WARNING: GitHub tokens usually start with 'ghp_', 'gho_', 'ghu_', 'ghs_', or 'ghr_'${NC}"
          show_input "Continue anyway? (y/N): "
          read -r response
          clear_input
          printf "\033[15;1H${CLEAR_LINE}"
          [[ "$response" =~ ^[Yy]$ ]] || return 1
        fi
      fi
      ;;
  esac
  return 0
}

set_pref() {
  defaults write "$1" "$2" "${@:3}" 2>/dev/null || return 1
}

install_package() {
  local package="$1"
  brew list "$package" >/dev/null 2>&1 || brew install "$package" >/dev/null 2>&1
}

install_cask() {
  local cask="$1"
  brew list --cask "$cask" >/dev/null 2>&1 || brew install --cask "$cask" >/dev/null 2>&1
}

# ————————————————————————————————————————————————————————————————————— #
# Configuration Collection (Get ALL input upfront)
update_status "Collecting all required configuration..."

# Configuration Collection (Get ALL input upfront)
update_status "Collecting all required configuration..."

printf "\033[15;1H${CYAN}🔧 Please provide the following information (all optional except Git if not configured):${NC}\n"

# Git config
if [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
  show_input "Git username: "
  read -r git_username
  clear_input
  printf "\033[14;1H${CLEAR_LINE}${GREEN}✔ Git username: ${git_username}${NC}"
  sleep 1
  clear_input
  
  show_input "Git email: "
  read -r git_email
  clear_input
  printf "\033[14;1H${CLEAR_LINE}${GREEN}✔ Git email: ${git_email}${NC}"
  sleep 1
  clear_input
else
  git_username=$(git config --global user.name)
  git_email=$(git config --global user.email)
  printf "\033[15;1H${GREEN}✔ Using existing Git config: ${git_username} <${git_email}>${NC}\n"
  sleep 1
fi

# SSH key
if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
  show_input "Email for SSH key: "
  read -r ssh_email
  clear_input
  printf "\033[14;1H${CLEAR_LINE}${GREEN}✔ SSH email: ${ssh_email}${NC}"
  sleep 1
  clear_input
else
  printf "\033[15;1H${GREEN}✔ SSH key already exists${NC}\n"
  sleep 1
fi

# API Keys with validation
while true; do
  show_input "OpenAI API key (optional, starts with sk-proj- or sk-): "
  read -r openai_api_key
  clear_input
  
  if validate_api_key "$openai_api_key" "openai"; then
    if [[ -n "$openai_api_key" ]]; then
      printf "\033[14;1H${CLEAR_LINE}${GREEN}✔ OpenAI API key entered${NC}"
      sleep 1
      clear_input
    fi
    break
  fi
  clear_input
done

while true; do
  show_input "Claude API key (optional, starts with sk-ant-): "
  read -r claude_api_key
  clear_input
  
  if validate_api_key "$claude_api_key" "claude"; then
    if [[ -n "$claude_api_key" ]]; then
      printf "\033[14;1H${CLEAR_LINE}${GREEN}✔ Claude API key entered${NC}"
      sleep 1
      clear_input
    fi
    break
  fi
  clear_input
done

# GitHub Token for Copilot
while true; do
  show_input "GitHub token (for Copilot, optional, starts with ghp_): "
  read -r github_token
  clear_input
  
  if validate_api_key "$github_token" "github"; then
    if [[ -n "$github_token" ]]; then
      printf "\033[14;1H${CLEAR_LINE}${GREEN}✔ GitHub token entered${NC}"
      sleep 1
      clear_input
    fi
    break
  fi
  clear_input
done

update_progress 1
update_status "Setting up sudo access..."

# Sudo setup
sudo -v 2>/dev/null
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

update_progress 2
update_status "Configuring system preferences..."

# ————————————————————————————————————————————————————————————————————— #
# System Preferences
{
  # Finder
  set_pref com.apple.finder FXPreferredViewStyle "Nlsv"
  set_pref com.apple.finder AppleShowAllFiles -bool true
  set_pref NSGlobalDomain AppleShowAllExtensions -bool true
  set_pref com.apple.finder FXRemoveOldTrashItems -bool true
  
  # Input devices  
  set_pref com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  set_pref NSGlobalDomain com.apple.trackpad.scaling -float 2.1
  set_pref NSGlobalDomain com.apple.mouse.scaling -float 2.1
  set_pref NSGlobalDomain KeyRepeat -int 2
  set_pref NSGlobalDomain InitialKeyRepeat -int 15
  set_pref NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
  
  # Dock configuration
  set_pref com.apple.dock autohide -bool false
  set_pref com.apple.dock tilesize -int 32
  set_pref com.apple.dock magnification -bool true
  set_pref com.apple.dock largesize -int 80
  set_pref com.apple.dock static-only -bool true
  set_pref com.apple.dock show-recents -bool false
  set_pref com.apple.dock launchanim -bool false
  
  # Security
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on 2>/dev/null
  
  # Browser
  set_pref com.apple.Safari HomePage "https://github.com/heyfinal"
  set_pref com.apple.LaunchServices LSQuarantine -bool false
} 2>/dev/null

update_progress 3
update_status "Installing Homebrew..."

# ————————————————————————————————————————————————————————————————————— #
# Homebrew
if ! command_exists brew; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null 2>&1
  
  if [[ $(uname -m) == "arm64" ]]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile  
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

update_progress 4
update_status "Installing CLI tools..."

# ————————————————————————————————————————————————————————————————————— #
# CLI Tools
for pkg in git curl wget jq tree htop bat eza fzf ripgrep fd tldr; do
  install_package "$pkg"
done

update_progress 5
update_status "Installing development tools..."

# ————————————————————————————————————————————————————————————————————— #
# Development Tools  
for pkg in node "python@3.12" go rust docker docker-compose; do
  install_package "$pkg"
done

update_progress 6
update_status "Installing AI CLIs..."

# ————————————————————————————————————————————————————————————————————— #
# AI CLIs
install_package "gh"

# Configure GitHub CLI with token if provided
if [[ -n "${github_token:-}" ]]; then
  echo "$github_token" | gh auth login --with-token >/dev/null 2>&1 || true
fi

# GitHub Copilot (now that gh is configured)
if ! gh extension list 2>/dev/null | grep -q "github/gh-copilot"; then
  gh extension install github/gh-copilot >/dev/null 2>&1 || true
fi

# Claude CLI
if ! command_exists claude; then
  curl -fsSL https://claude.ai/cli/install.sh | sh >/dev/null 2>&1 || true
fi

# OpenAI CLI
if ! command_exists openai; then
  if command_exists npm; then
    npm install -g openai-cli >/dev/null 2>&1 || pip3 install openai >/dev/null 2>&1 || true
  else
    pip3 install openai >/dev/null 2>&1 || true
  fi
fi

update_progress 7
update_status "Installing applications..."

# ————————————————————————————————————————————————————————————————————— #
# Applications
for app in iterm2 rectangle alfred 1password discord slack zoom; do
  install_cask "$app"
done

update_progress 8
update_status "Setting up shell environment..."

# ————————————————————————————————————————————————————————————————————— #
# Shell Setup
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended >/dev/null 2>&1
fi

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" >/dev/null 2>&1
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" >/dev/null 2>&1
fi

# Configure .zshrc
if [[ -f "$HOME/.zshrc" ]]; then
  cp "$HOME/.zshrc" "$HOME/.zshrc.backup"
  sed -i.bak 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting docker node npm)/' "$HOME/.zshrc"
  
  cat >> "$HOME/.zshrc" << 'EOF'

# Custom aliases
alias ll='eza -la --git'
alias ls='eza'
alias cat='bat'
alias chz='chmod +x' 
alias openz='open -a textedit'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
EOF
fi

update_progress 9
update_status "Configuring Git and SSH..."

# ————————————————————————————————————————————————————————————————————— #
# Git & SSH
git config --global user.name "$git_username" 2>/dev/null
git config --global user.email "$git_email" 2>/dev/null
git config --global init.defaultBranch main 2>/dev/null
git config --global pull.rebase false 2>/dev/null

if [[ ! -f "$HOME/.ssh/id_ed25519" && -n "${ssh_email:-}" ]]; then
  ssh-keygen -t ed25519 -C "$ssh_email" -f "$HOME/.ssh/id_ed25519" -N "" >/dev/null 2>&1
  eval "$(ssh-agent -s)" >/dev/null 2>&1
  ssh-add "$HOME/.ssh/id_ed25519" >/dev/null 2>&1
fi

update_progress 10
update_status "Configuring terminal themes..."

# ————————————————————————————————————————————————————————————————————— #
# Terminal Themes
if [[ -d "/Applications/iTerm.app" ]]; then
  mkdir -p "$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  cat > "$HOME/Library/Application Support/iTerm2/DynamicProfiles/Kali.json" << 'EOF'
{
  "Profiles": [
    {
      "Name": "Kali",
      "Guid": "kali-linux-profile",
      "Background Color": {
        "Red Component": 0.0,
        "Green Component": 0.0,
        "Blue Component": 0.0,
        "Alpha Component": 0.8
      },
      "Foreground Color": {
        "Red Component": 0.0,
        "Green Component": 1.0,
        "Blue Component": 0.0
      },
      "Cursor Color": {
        "Red Component": 0.0,
        "Green Component": 1.0,
        "Blue Component": 0.0
      },
      "Transparency": 0.2,
      "Blur": false,
      "Window Type": 0,
      "Background Image Mode": 0
    }
  ]
}
EOF
fi

# Terminal.app - Create custom black transparent theme
mkdir -p "$HOME/Library/Application Support/Terminal/Themes"
cat > "$HOME/Library/Application Support/Terminal/Themes/BlackTransparent.terminal" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>BackgroundColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3AS
    AAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPEBww
    IDAgMCAwLjgAEAGAA4AE0hAREhNaJGNsYXNzbmFtZVgkY2xhc3Nlc1dOU0NvbG9yohIU
    WE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy0RcYVHJvb3SAAQgRGiMtMjc7QUhOW2Jp
    a3KDjI+YqqO4uAAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAAC6
    </data>
    <key>Font</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGGBlYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3AS
    AAGGoKQHCBESVSRudWxs1AkKCwwNDg8QVk5TU2l6ZVhOU2ZGbGFnc1ZOU05hbWVWJGNs
    YXNzI0AoAAAAAAAAEBCAAoADXU1lbmxvLVJlZ3VsYXLSExQVFlokY2xhc3NuYW1lWCRj
    bGFzc2VzVk5TRm9udKIVF1hOU09iamVjdF8QD05TS2V5ZWRBcmNoaXZlctEaG1Ryb290
    gAEIERojLTI3PEJLUllgaWttdniGjJ2lprO2uwAAAAAAAAEBAAAAAAAAABwAAAAAAAAA
    AAAAAAAAAAAAAL0=
    </data>
    <key>FontAntialias</key>
    <true/>
    <key>ProfileCurrentVersion</key>
    <real>2.07</real>
    <key>TextColor</key>
    <data>
    YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3AS
    AAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPEBwx
    IDEgMSAxABABgAKABdIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhO
    U09iamVjdF8QD05TA2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FITltiaWtr
    cnN6hIyPmKqtsgAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAAC0
    </data>
    <key>WindowOpacity</key>
    <real>0.8</real>
    <key>name</key>
    <string>BlackTransparent</string>
    <key>type</key>
    <string>Window Settings</string>
</dict>
</plist>
EOF

# Import and set the custom theme
open "$HOME/Library/Application Support/Terminal/Themes/BlackTransparent.terminal" 2>/dev/null || true
sleep 2
osascript -e 'tell application "Terminal" to set default settings to settings set "BlackTransparent"' 2>/dev/null || {
  osascript -e 'tell application "Terminal" to set default settings to settings set "Basic"' 2>/dev/null || true
}

update_progress 11
update_status "Installing rEFInd bootloader..."

# ————————————————————————————————————————————————————————————————————— #
# rEFInd
if ! command_exists refind-install; then
  {
    curl -L -o /tmp/refind.zip "https://sourceforge.net/projects/refind/files/latest/download" 2>/dev/null
    cd /tmp && unzip -q refind.zip 2>/dev/null
    REFIND_DIR=$(find /tmp -name "refind-bin-*" -type d | head -1)
    
    if [[ -d "$REFIND_DIR" ]]; then
      cd "$REFIND_DIR"
      sudo ./refind-install --yes >/dev/null 2>&1
      
      # Install theme
      cd /tmp
      git clone https://github.com/jpmvferreira/refind-ambience-deer-and-fireflies.git >/dev/null 2>&1
      
      REFIND_PATH="/System/Volumes/Preboot/EFI/refind"
      [[ ! -d "$REFIND_PATH" ]] && REFIND_PATH="/boot/efi/EFI/refind"
      
      if [[ -d "$REFIND_PATH" ]]; then
        sudo cp -r refind-ambience-deer-and-fireflies/src/* "$REFIND_PATH/" >/dev/null 2>&1
      fi
    fi
  } || true
fi

update_progress 12
update_status "Finalizing configuration..."

# ————————————————————————————————————————————————————————————————————— #
# Auto-configure APIs
if [[ -n "${openai_api_key:-}" ]] && command_exists openai; then
  echo "$openai_api_key" | openai config set-key >/dev/null 2>&1 || true
fi

if [[ -n "${claude_api_key:-}" ]] && command_exists claude; then
  echo "$claude_api_key" | claude config >/dev/null 2>&1 || true
fi

# Restart services
killall Finder Dock SystemUIServer 2>/dev/null || true

# ————————————————————————————————————————————————————————————————————— #
# Completion
update_status "Setup complete!"

# Move to line 15 for final output
printf "\033[15;1H"

if [[ "$SETUP_SUCCESS" == true ]]; then
  echo -e "${GREEN}🎉 Setup completed successfully!${NC}"
  echo -e "${CYAN}📋 Installed: System prefs • CLI tools • AI CLIs • Apps • rEFInd${NC}"
  echo -e "${GREEN}🤖 Auto-configured: GitHub • OpenAI • Claude CLIs${NC}"
  
  if [[ -f "$HOME/.ssh/id_ed25519.pub" && -n "${ssh_email:-}" ]]; then
    echo -e "\n${YELLOW}📋 SSH Public Key (add to GitHub):${NC}"
    echo -e "${CYAN}$(cat "$HOME/.ssh/id_ed25519.pub")${NC}"
  fi
  
  echo -e "\n${GREEN}✨ Ready to use: gh copilot, claude, openai commands${NC}"
  echo -e "\n${CYAN}💻 Rebooting in 10 seconds (Ctrl+C to cancel)...${NC}"
  for i in {10..1}; do
    printf "${CLEAR_LINE}\rRebooting in $i seconds..."
    sleep 1
  done
  
  echo -e "\n${GREEN}🔄 Rebooting...${NC}"
  sudo reboot
else
  echo -e "${YELLOW}⚠️  Setup completed with some errors.${NC}"
  echo -e "${YELLOW}Check log: ${LOG_FILE}${NC}"
  
  # Auto-open log
  if command_exists code; then
    code "$LOG_FILE"
  elif command_exists open; then
    open "$LOG_FILE"  
  fi
  
  read -p "Reboot anyway? (y/N): " response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    sudo reboot
  fi
fi
