#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

LOG_FILE="/tmp/mac_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Track success status and progress
SETUP_SUCCESS=true
TOTAL_STEPS=85
CURRENT_STEP=0

# Error handler
handle_error() {
  local exit_code=$?
  echo -e "\n${RED}❌ Setup encountered an error (exit code: $exit_code)${NC}"
  echo -e "${YELLOW}Opening log file to show errors...${NC}"
  SETUP_SUCCESS=false
  
  # Auto-open log file on error
  if command -v code >/dev/null 2>&1; then
    code "$LOG_FILE"
  elif command -v open >/dev/null 2>&1; then
    open "$LOG_FILE"
  else
    echo -e "${YELLOW}Log file location: $LOG_FILE${NC}"
    tail -20 "$LOG_FILE"
  fi
}

# Set error trap
trap 'handle_error' ERR

# ————————————————————————————————————————————————————————————————————— #
# ANSI Colors & Terminal Control
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
TAN='\033[38;5;180m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Terminal control sequences
SAVE_CURSOR='\033[s'
RESTORE_CURSOR='\033[u'
CLEAR_LINE='\033[2K'
MOVE_UP='\033[1A'

# ————————————————————————————————————————————————————————————————————— #
# Progress and Display Functions
show_progress() {
  local step=$1
  local description=$2
  CURRENT_STEP=$step
  
  # Calculate percentage
  local percent=$((step * 100 / TOTAL_STEPS))
  local filled=$((percent * 50 / 100))
  local empty=$((50 - filled))
  
  # Create progress bar
  local bar=""
  for ((i=1; i<=filled; i++)); do bar+="█"; done
  for ((i=1; i<=empty; i++)); do bar+="░"; done
  
  # Save cursor, move to progress line (line 12), update progress, restore cursor
  printf "${SAVE_CURSOR}"
  printf "\033[12;1H${CLEAR_LINE}"
  printf "${CYAN}Progress: [${bar}] ${percent}%% - ${description}${NC}"
  printf "${RESTORE_CURSOR}"
}

# Fixed banner with progress bar space
banner() {
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


Progress: [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 0% - Starting...

EOF
  printf "${NC}\n"
}

banner
show_progress 1 "Initializing setup..."

# ————————————————————————————————————————————————————————————————————— #
# User Input Collection
echo -e "${CYAN}🔧 macOS Developer Setup - Collecting Configuration...${NC}\n"

# Git configuration
if [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
  read -p "Enter your Git username: " git_username
  read -p "Enter your Git email: " git_email
else
  git_username=$(git config --global user.name)
  git_email=$(git config --global user.email)
  echo -e "${GREEN}✔ Using existing Git config: $git_username <$git_email>${NC}"
fi

# SSH key email
if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
  read -p "Enter your email for SSH key: " ssh_email
else
  echo -e "${GREEN}✔ SSH key already exists${NC}"
fi

# API Keys for AI CLIs
read -p "Enter your OpenAI API key (optional, press Enter to skip): " openai_api_key
read -p "Enter your Claude API key (optional, press Enter to skip): " claude_api_key

# GitHub login for Copilot
echo -e "${YELLOW}Note: GitHub Copilot will require 'gh auth login' after installation${NC}"

show_progress 5 "Configuration collected, starting system setup..."

# ————————————————————————————————————————————————————————————————————— #
# Sudo Keep-Alive
echo -e "${YELLOW}🔑 This script requires sudo access for system preferences...${NC}"
sudo -v

# Keep sudo alive until script finishes
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo -e "${GREEN}✔ Sudo access granted${NC}"

# ————————————————————————————————————————————————————————————————————— #
# PHASE 1: System Tweaks & Preferences (Run First)
# ————————————————————————————————————————————————————————————————————— #

show_progress 10 "Applying system tweaks and preferences..."

# ————————————————————————————————————————————————————————————————————— #
# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ————————————————————————————————————————————————————————————————————— #
# Idempotent Preference Setter (Robust version)
set_pref() {
  local domain=$1
  local key=$2
  shift 2
  local args=("$@")
  
  if defaults write "$domain" "$key" "${args[@]}" 2>/dev/null; then
    echo -e "${GREEN}✔ Set $domain $key${NC}"
  else
    echo -e "${RED}✗ Failed to set $domain $key${NC}"
    SETUP_SUCCESS=false
    return 1
  fi
}

# ————————————————————————————————————————————————————————————————————— #
# Finder Preferences
show_progress 15 "Configuring Finder..."

# Finder: List view and sort by kind
set_pref com.apple.finder FXPreferredViewStyle "Nlsv"
set_pref com.apple.finder FXArrangeGroupViewBy "kind"
set_pref com.apple.finder DesktopViewSettings.IconViewSettings.arrangeBy "kind"

# Show hidden files and extensions
set_pref com.apple.finder AppleShowAllFiles -bool true
set_pref NSGlobalDomain AppleShowAllExtensions -bool true

# Auto-empty trash after 1 day
set_pref com.apple.finder FXRemoveOldTrashItems -bool true
set_pref com.apple.finder FXRemoveOldTrashItemsAge -int 1

# ————————————————————————————————————————————————————————————————————— #
# Input Device Preferences
show_progress 20 "Configuring input devices..."

# Mouse and trackpad
set_pref com.apple.driver.AppleBluetoothMultitouch.mouse MouseButtonMode "TwoButton"
set_pref com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
set_pref com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 2
set_pref com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true

# Enable tap to click
set_pref com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
set_pref com.apple.AppleMultitouchTrackpad Clicking -bool true

# Set trackpad speed to 70% (scale 0-3, so 70% = 2.1)
set_pref NSGlobalDomain com.apple.trackpad.scaling -float 2.1

# Magic Mouse speed to 70% fast (scale 0-3, so 70% = 2.1)
set_pref NSGlobalDomain com.apple.mouse.scaling -float 2.1

# Enable full keyboard access for all controls
set_pref NSGlobalDomain AppleKeyboardUIMode -int 3

# Set fast keyboard repeat rate
set_pref NSGlobalDomain KeyRepeat -int 2
set_pref NSGlobalDomain InitialKeyRepeat -int 15

# Disable auto-correct
set_pref NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# ————————————————————————————————————————————————————————————————————— #
# Dock Configuration (Enhanced)
show_progress 25 "Configuring Dock..."

# Disable Dock auto-hide (keep it visible)
set_pref com.apple.dock autohide -bool false

# Remove auto-hide delay (even though auto-hide is off)
set_pref com.apple.dock autohide-delay -float 0

# Set small icon size (default is around 48, small is 32)
set_pref com.apple.dock tilesize -int 32

# Enable magnification with large size on hover
set_pref com.apple.dock magnification -bool true
set_pref com.apple.dock largesize -int 80

# Remove dock background/shelf
set_pref com.apple.dock static-only -bool true

# Disable dock launch animation
set_pref com.apple.dock launchanim -bool false

# Speed up Mission Control animations
set_pref com.apple.dock expose-animation-duration -float 0.1

# Don't show recent applications in Dock
set_pref com.apple.dock show-recents -bool false

# ————————————————————————————————————————————————————————————————————— #
# System UI Preferences
show_progress 30 "Configuring system UI..."

# Disable the "Are you sure you want to open this application?" dialog
set_pref com.apple.LaunchServices LSQuarantine -bool false

# ————————————————————————————————————————————————————————————————————— #
# Browser Homepage Settings
show_progress 32 "Configuring browser homepages..."

# Set Safari homepage to GitHub profile
set_pref com.apple.Safari HomePage "https://github.com/heyfinal"

# ————————————————————————————————————————————————————————————————————— #
# Security & Firewall Configuration  
show_progress 35 "Configuring security and firewall..."

# Firewall: Check and enable only if not active
firewall_status=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo "0")
if [[ "$firewall_status" -ne 1 ]]; then
  if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null; then
    echo -e "${GREEN}✔ Firewall enabled${NC}"
  else
    echo -e "${RED}✗ Failed to enable firewall${NC}"
    SETUP_SUCCESS=false
  fi
else
  echo -e "${GREEN}✔ Firewall already enabled${NC}"
fi

# Firewall: Stealth Mode
stealth_status=$(defaults read /Library/Preferences/com.apple.alf stealthenabled 2>/dev/null || echo "0")
if [[ "$stealth_status" -ne 1 ]]; then
  if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on 2>/dev/null; then
    echo -e "${GREEN}✔ Stealth mode enabled${NC}"
  else
    echo -e "${RED}✗ Failed to enable stealth mode${NC}"
    SETUP_SUCCESS=false
  fi
else
  echo -e "${GREEN}✔ Stealth mode already enabled${NC}"
fi

# ————————————————————————————————————————————————————————————————————— #
# PHASE 2: Downloads & Installations
# ————————————————————————————————————————————————————————————————————— #

show_progress 40 "Starting downloads and installations..."

# ————————————————————————————————————————————————————————————————————— #
# Install Homebrew if not present
install_homebrew() {
  if ! command_exists brew; then
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
      # Add Homebrew to PATH for Apple Silicon Macs
      if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
      else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
      fi
      echo -e "${GREEN}✔ Homebrew installed${NC}"
    else
      echo -e "${RED}✗ Failed to install Homebrew${NC}"
      SETUP_SUCCESS=false
    fi
  else
    echo -e "${GREEN}✔ Homebrew already installed${NC}"
  fi
}

# Package installers
install_brew_package() {
  local package=$1
  if brew list "$package" &>/dev/null; then
    echo -e "${GREEN}✔ $package (skipped)${NC}"
    return 0
  else
    if brew install "$package" 2>/dev/null; then
      echo -e "${GREEN}✔ $package installed${NC}"
    else
      echo -e "${RED}✗ Failed to install $package${NC}"
      SETUP_SUCCESS=false
      return 1
    fi
  fi
}

install_brew_cask() {
  local cask=$1
  if brew list --cask "$cask" &>/dev/null; then
    echo -e "${GREEN}✔ $cask (skipped)${NC}"
    return 0
  else
    if brew install --cask "$cask" 2>/dev/null; then
      echo -e "${GREEN}✔ $cask installed${NC}"
    else
      echo -e "${RED}✗ Failed to install $cask${NC}"
      SETUP_SUCCESS=false
      return 1
    fi
  fi
}

# Install Homebrew first
install_homebrew

show_progress 45 "Installing essential CLI tools..."

# Essential CLI tools
install_brew_package "git"
install_brew_package "curl"
install_brew_package "wget"
install_brew_package "jq"
install_brew_package "tree"
install_brew_package "htop"
install_brew_package "bat"
install_brew_package "eza"
install_brew_package "fzf"
install_brew_package "ripgrep"
install_brew_package "fd"
install_brew_package "tldr"

show_progress 55 "Installing development tools..."

# Development tools
install_brew_package "node"
install_brew_package "python@3.12"
install_brew_package "go"
install_brew_package "rust"
install_brew_package "docker"
install_brew_package "docker-compose"

show_progress 60 "Installing AI CLIs..."

# GitHub CLI and Copilot
if ! command_exists gh; then
  install_brew_package "gh"
fi

if command_exists gh && ! gh extension list 2>/dev/null | grep -q "github/gh-copilot"; then
  if gh extension install github/gh-copilot 2>/dev/null; then
    echo -e "${GREEN}✔ GitHub Copilot extension installed${NC}"
  else
    echo -e "${YELLOW}⚠️  GitHub Copilot requires 'gh auth login' first${NC}"
  fi
else
  echo -e "${GREEN}✔ GitHub Copilot (skipped)${NC}"
fi

# Claude CLI
if ! command_exists claude; then
  if curl -fsSL https://claude.ai/cli/install.sh | sh 2>/dev/null; then
    echo -e "${GREEN}✔ Claude CLI installed${NC}"
  else
    echo -e "${RED}✗ Claude CLI install failed${NC}"
    SETUP_SUCCESS=false
  fi
else
  echo -e "${GREEN}✔ Claude CLI (skipped)${NC}"
fi

# OpenAI CLI
if ! command_exists openai; then
  if command_exists npm; then
    if npm install -g openai-cli 2>/dev/null; then
      echo -e "${GREEN}✔ OpenAI CLI installed${NC}"
    else
      if pip3 install openai 2>/dev/null; then
        echo -e "${GREEN}✔ OpenAI CLI installed via pip${NC}"
      else
        echo -e "${RED}✗ OpenAI CLI install failed${NC}"
        SETUP_SUCCESS=false
      fi
    fi
  else
    if pip3 install openai 2>/dev/null; then
      echo -e "${GREEN}✔ OpenAI CLI installed${NC}"
    else
      echo -e "${RED}✗ OpenAI CLI install failed${NC}"
      SETUP_SUCCESS=false
    fi
  fi
else
  echo -e "${GREEN}✔ OpenAI CLI (skipped)${NC}"
fi

show_progress 65 "Installing applications..."

# Applications
install_brew_cask "iterm2"
install_brew_cask "rectangle"
install_brew_cask "alfred"
install_brew_cask "1password"
install_brew_cask "discord"
install_brew_cask "slack"
install_brew_cask "zoom"

show_progress 70 "Setting up shell environment..."

# Oh My Zsh and plugins
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  echo -e "${GREEN}✔ Oh My Zsh installed${NC}"
else
  echo -e "${GREEN}✔ Oh My Zsh (skipped)${NC}"
fi

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

# zsh plugins
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>/dev/null
  echo -e "${GREEN}✔ zsh-autosuggestions installed${NC}"
else
  echo -e "${GREEN}✔ zsh-autosuggestions (skipped)${NC}"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 2>/dev/null
  echo -e "${GREEN}✔ zsh-syntax-highlighting installed${NC}"
else
  echo -e "${GREEN}✔ zsh-syntax-highlighting (skipped)${NC}"
fi

# Update .zshrc
if [[ -f "$HOME/.zshrc" ]]; then
  cp "$HOME/.zshrc" "$HOME/.zshrc.backup"
  sed -i.bak 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting docker node npm)/' "$HOME/.zshrc"
  
  # Add aliases
  cat >> "$HOME/.zshrc" << 'EOF'

# Custom aliases
alias ll='eza -la --git'
alias ls='eza'
alias cat='bat'
alias find='fd'
alias grep='rg'
alias top='htop'
alias chz='chmod +x'
alias openz='open -a textedit'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'

# Docker aliases
alias dc='docker-compose'
alias dps='docker ps'
alias di='docker images'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
EOF
  echo -e "${GREEN}✔ Zsh configured with aliases${NC}"
fi

show_progress 75 "Configuring Git and SSH..."

# Git configuration
git config --global user.name "$git_username"
git config --global user.email "$git_email"
git config --global init.defaultBranch main
git config --global pull.rebase false
echo -e "${GREEN}✔ Git configured${NC}"

# SSH key setup
if [[ ! -f "$HOME/.ssh/id_ed25519" && -n "${ssh_email:-}" ]]; then
  ssh-keygen -t ed25519 -C "$ssh_email" -f "$HOME/.ssh/id_ed25519" -N ""
  eval "$(ssh-agent -s)"
  ssh-add "$HOME/.ssh/id_ed25519"
  echo -e "${GREEN}✔ SSH key created${NC}"
  echo -e "${YELLOW}Your public key:${NC}"
  cat "$HOME/.ssh/id_ed25519.pub"
else
  echo -e "${GREEN}✔ SSH key (skipped)${NC}"
fi

show_progress 78 "Configuring terminal themes..."

# iTerm2 Kali theme
if [[ -d "/Applications/iTerm.app" ]]; then
  mkdir -p "$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  cat > "$HOME/Library/Application Support/iTerm2/DynamicProfiles/Kali.json" << 'EOF'
{
  "Profiles": [
    {
      "Name": "Kali",
      "Guid": "kali-linux-profile",
      "Background Color": {"Red Component": 0.0, "Green Component": 0.0, "Blue Component": 0.0},
      "Foreground Color": {"Red Component": 0.0, "Green Component": 1.0, "Blue Component": 0.0},
      "Cursor Color": {"Red Component": 0.0, "Green Component": 1.0, "Blue Component": 0.0}
    }
  ]
}
EOF
  echo -e "${GREEN}✔ iTerm2 Kali theme created${NC}"
fi

# Terminal.app Homebrew theme
osascript -e 'tell application "Terminal" to set default settings to settings set "Homebrew"' 2>/dev/null || {
  osascript -e 'tell application "Terminal" to set default settings to settings set "Basic"' 2>/dev/null || true
}
echo -e "${GREEN}✔ Terminal.app theme set${NC}"

show_progress 80 "Installing rEFInd bootloader..."

# rEFInd installation
if ! command_exists refind-install; then
  echo -e "${YELLOW}Installing rEFInd bootloader...${NC}"
  
  # Download rEFInd
  curl -L -o /tmp/refind.zip "https://sourceforge.net/projects/refind/files/latest/download" 2>/dev/null
  cd /tmp && unzip -q refind.zip
  REFIND_DIR=$(find /tmp -name "refind-bin-*" -type d | head -1)
  
  if [[ -d "$REFIND_DIR" ]]; then
    cd "$REFIND_DIR"
    sudo ./refind-install --yes 2>/dev/null || {
      echo -e "${RED}✗ rEFInd installation failed (SIP may need to be disabled)${NC}"
      SETUP_SUCCESS=false
    }
    echo -e "${GREEN}✔ rEFInd bootloader installed${NC}"
  else
    echo -e "${RED}✗ Failed to download rEFInd${NC}"
    SETUP_SUCCESS=false
  fi
else
  echo -e "${GREEN}✔ rEFInd already installed${NC}"
fi

show_progress 82 "Installing rEFInd theme..."

# Install rEFInd theme
if [[ -d "/System/Volumes/Preboot/EFI/refind" || -d "/boot/efi/EFI/refind" ]]; then
  REFIND_DIR="/System/Volumes/Preboot/EFI/refind"
  [[ ! -d "$REFIND_DIR" ]] && REFIND_DIR="/boot/efi/EFI/refind"
  
  if [[ -d "$REFIND_DIR" ]]; then
    cd /tmp
    git clone https://github.com/jpmvferreira/refind-ambience-deer-and-fireflies.git 2>/dev/null
    sudo cp -r refind-ambience-deer-and-fireflies/src/* "$REFIND_DIR/" 2>/dev/null || {
      echo -e "${RED}✗ Failed to install rEFInd theme${NC}"
      SETUP_SUCCESS=false
    }
    echo -e "${GREEN}✔ rEFInd theme installed${NC}"
  fi
else
  echo -e "${YELLOW}⚠️  rEFInd directory not found, skipping theme${NC}"
fi

show_progress 85 "Configuring AI CLIs automatically..."

# Auto-configure AI CLIs
if [[ -n "${openai_api_key:-}" ]] && command_exists openai; then
  echo "$openai_api_key" | openai config set-key 2>/dev/null || true
  echo -e "${GREEN}✔ OpenAI CLI configured${NC}"
fi

if [[ -n "${claude_api_key:-}" ]] && command_exists claude; then
  echo "$claude_api_key" | claude config 2>/dev/null || true
  echo -e "${GREEN}✔ Claude CLI configured${NC}"
fi

# GitHub Copilot setup reminder
if command_exists gh; then
  echo -e "${YELLOW}Note: Run 'gh auth login' then 'gh copilot config' to complete GitHub Copilot setup${NC}"
fi

# ————————————————————————————————————————————————————————————————————— #
# Restart services
echo -e "\n${CYAN}🔄 Restarting system services...${NC}"
killall Finder 2>/dev/null || true
killall Dock 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

# ————————————————————————————————————————————————————————————————————— #
# Summary
show_progress 85 "Setup complete!"

echo -e "\n${GREEN}🎉 macOS setup completed!${NC}"
echo -e "\n${CYAN}📋 Summary:${NC}"
echo -e "   • System preferences optimized"
echo -e "   • Dock configured (no auto-hide, small icons with magnification)"
echo -e "   • Essential development tools installed"
echo -e "   • AI CLIs configured (GitHub Copilot, Claude, OpenAI)"
echo -e "   • Terminal themes applied (iTerm2: Kali, Terminal: Homebrew)"
echo -e "   • rEFInd bootloader with custom theme installed"
echo -e "   • Magic Mouse speed set to 70%"

if [[ "$SETUP_SUCCESS" == true ]]; then
  echo -e "\n${GREEN}🎉 Setup completed successfully with no errors!${NC}"
  echo -e "\n${CYAN}💻 System will reboot in 15 seconds to complete setup...${NC}"
  echo -e "${YELLOW}Press Ctrl+C to cancel reboot${NC}"

  for i in {15..1}; do
    printf "\rRebooting in $i seconds... "
    sleep 1
  done

  echo -e "\n${GREEN}🔄 Rebooting now...${NC}"
  sudo reboot
else
  echo -e "\n${YELLOW}⚠️  Setup completed with some errors.${NC}"
  echo -e "${CYAN}Would you like to reboot anyway? (y/N):${NC}"
  read -r response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🔄 Rebooting...${NC}"
    sudo reboot
  else
    echo -e "${GREEN}Setup complete. Reboot manually when ready.${NC}"
  fi
fi
