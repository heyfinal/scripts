#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

LOG_FILE="/tmp/mac_setup.log"

# Track success status and progress
SETUP_SUCCESS=true
TOTAL_STEPS=15
CURRENT_STEP=0

# ————————————————————————————————————————————————————————————————————— #
# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
TAN='\033[38;5;180m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ————————————————————————————————————————————————————————————————————— #
# Progress Function
show_progress() {
  local step=$1
  local description=$2
  CURRENT_STEP=$step
  
  local percent=$((step * 100 / TOTAL_STEPS))
  local filled=$((percent * 40 / 100))
  local empty=$((40 - filled))
  
  local bar=""
  for ((i=1; i<=filled; i++)); do bar+="█"; done
  for ((i=1; i<=empty; i++)); do bar+="░"; done
  
  # Clear line and show progress
  printf "\r\033[K${CYAN}Progress: [${bar}] ${percent}%% - ${description}${NC}"
}

# ————————————————————————————————————————————————————————————————————— #
# Banner
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
printf "${NC}\n"

show_progress 0 "Initializing..."

# ————————————————————————————————————————————————————————————————————— #
# Utility Functions
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

log() {
  echo "$1" >> "$LOG_FILE"
}

set_pref() {
  local domain=$1
  local key=$2
  shift 2
  local args=("$@")
  
  if defaults write "$domain" "$key" "${args[@]}" &>> "$LOG_FILE"; then
    return 0
  else
    log "ERROR: Failed to set $domain $key"
    SETUP_SUCCESS=false
    return 1
  fi
}

install_brew_package() {
  local package=$1
  if brew list "$package" &>/dev/null; then
    return 0
  else
    if brew install "$package" &>> "$LOG_FILE"; then
      return 0
    else
      log "ERROR: Failed to install $package"
      SETUP_SUCCESS=false
      return 1
    fi
  fi
}

install_brew_cask() {
  local cask=$1
  if brew list --cask "$cask" &>/dev/null; then
    return 0
  else
    if brew install --cask "$cask" &>> "$LOG_FILE"; then
      return 0
    else
      log "ERROR: Failed to install $cask"
      SETUP_SUCCESS=false
      return 1
    fi
  fi
}

# ————————————————————————————————————————————————————————————————————— #
# User Input Collection
echo -e "\n${CYAN}🔧 Collecting configuration...${NC}"

# Git configuration
if [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
  read -p "Git username: " git_username
  read -p "Git email: " git_email
else
  git_username=$(git config --global user.name)
  git_email=$(git config --global user.email)
  echo -e "${GREEN}✔ Using existing Git config${NC}"
fi

# SSH key email
if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
  read -p "SSH key email: " ssh_email
else
  echo -e "${GREEN}✔ SSH key exists${NC}"
fi

# API Keys
read -p "OpenAI API key (optional): " openai_api_key
read -p "Claude API key (optional): " claude_api_key

show_progress 1 "Starting setup..."

# ————————————————————————————————————————————————————————————————————— #
# Sudo setup
sudo -v &>> "$LOG_FILE"
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

show_progress 2 "Configuring system preferences..."

# ————————————————————————————————————————————————————————————————————— #
# System Preferences (Silent)
{
  # Finder
  set_pref com.apple.finder FXPreferredViewStyle "Nlsv"
  set_pref com.apple.finder AppleShowAllFiles -bool true
  set_pref NSGlobalDomain AppleShowAllExtensions -bool true
  
  # Input devices
  set_pref com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  set_pref NSGlobalDomain com.apple.trackpad.scaling -float 2.1
  set_pref NSGlobalDomain com.apple.mouse.scaling -float 2.1
  set_pref NSGlobalDomain KeyRepeat -int 2
  set_pref NSGlobalDomain InitialKeyRepeat -int 15
  
  # Dock
  set_pref com.apple.dock autohide -bool false
  set_pref com.apple.dock tilesize -int 32
  set_pref com.apple.dock magnification -bool true
  set_pref com.apple.dock largesize -int 80
  set_pref com.apple.dock static-only -bool true
  set_pref com.apple.dock show-recents -bool false
  
  # Security
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on &>> "$LOG_FILE"
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on &>> "$LOG_FILE"
  
  # Browser
  set_pref com.apple.Safari HomePage "https://github.com/heyfinal"
} 2>/dev/null

show_progress 3 "Installing Homebrew..."

# ————————————————————————————————————————————————————————————————————— #
# Homebrew
if ! command_exists brew; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" &>> "$LOG_FILE"
  if [[ $(uname -m) == "arm64" ]]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

show_progress 4 "Installing CLI tools..."

# ————————————————————————————————————————————————————————————————————— #
# CLI Tools
for package in git curl wget jq tree htop bat eza fzf ripgrep fd tldr; do
  install_brew_package "$package"
done

show_progress 6 "Installing development tools..."

# ————————————————————————————————————————————————————————————————————— #
# Development Tools
for package in node "python@3.12" go rust docker docker-compose; do
  install_brew_package "$package"
done

show_progress 8 "Installing AI CLIs..."

# ————————————————————————————————————————————————————————————————————— #
# AI CLIs
install_brew_package "gh"

if ! gh extension list 2>/dev/null | grep -q "github/gh-copilot"; then
  gh extension install github/gh-copilot &>> "$LOG_FILE" || true
fi

if ! command_exists claude; then
  curl -fsSL https://claude.ai/cli/install.sh | sh &>> "$LOG_FILE" || true
fi

if ! command_exists openai; then
  if command_exists npm; then
    npm install -g openai-cli &>> "$LOG_FILE" || pip3 install openai &>> "$LOG_FILE" || true
  else
    pip3 install openai &>> "$LOG_FILE" || true
  fi
fi

show_progress 10 "Installing applications..."

# ————————————————————————————————————————————————————————————————————— #
# Applications
for app in iterm2 rectangle alfred 1password discord slack zoom; do
  install_brew_cask "$app"
done

show_progress 11 "Setting up shell..."

# ————————————————————————————————————————————————————————————————————— #
# Shell Setup
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended &>> "$LOG_FILE"
fi

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" &>> "$LOG_FILE"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" &>> "$LOG_FILE"
fi

# Configure .zshrc
if [[ -f "$HOME/.zshrc" ]]; then
  cp "$HOME/.zshrc" "$HOME/.zshrc.backup"
  sed -i.bak 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting docker node npm)/' "$HOME/.zshrc"
  
  cat >> "$HOME/.zshrc" << 'EOF'

# Aliases
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

show_progress 12 "Configuring Git and SSH..."

# ————————————————————————————————————————————————————————————————————— #
# Git & SSH
git config --global user.name "$git_username" 2>/dev/null
git config --global user.email "$git_email" 2>/dev/null
git config --global init.defaultBranch main 2>/dev/null

if [[ ! -f "$HOME/.ssh/id_ed25519" && -n "${ssh_email:-}" ]]; then
  ssh-keygen -t ed25519 -C "$ssh_email" -f "$HOME/.ssh/id_ed25519" -N "" &>> "$LOG_FILE"
  eval "$(ssh-agent -s)" &>> "$LOG_FILE"
  ssh-add "$HOME/.ssh/id_ed25519" &>> "$LOG_FILE"
fi

show_progress 13 "Configuring terminals..."

# ————————————————————————————————————————————————————————————————————— #
# Terminal Themes
if [[ -d "/Applications/iTerm.app" ]]; then
  mkdir -p "$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  cat > "$HOME/Library/Application Support/iTerm2/DynamicProfiles/Kali.json" << 'EOF'
{"Profiles":[{"Name":"Kali","Guid":"kali-linux-profile","Background Color":{"Red Component":0.0,"Green Component":0.0,"Blue Component":0.0},"Foreground Color":{"Red Component":0.0,"Green Component":1.0,"Blue Component":0.0}}]}
EOF
fi

osascript -e 'tell application "Terminal" to set default settings to settings set "Homebrew"' 2>/dev/null || true

show_progress 14 "Installing rEFInd..."

# ————————————————————————————————————————————————————————————————————— #
# rEFInd
if ! command_exists refind-install; then
  {
    curl -L -o /tmp/refind.zip "https://sourceforge.net/projects/refind/files/latest/download"
    cd /tmp && unzip -q refind.zip
    REFIND_DIR=$(find /tmp -name "refind-bin-*" -type d | head -1)
    if [[ -d "$REFIND_DIR" ]]; then
      cd "$REFIND_DIR"
      sudo ./refind-install --yes
      
      # Install theme
      cd /tmp
      git clone https://github.com/jpmvferreira/refind-ambience-deer-and-fireflies.git
      REFIND_PATH="/System/Volumes/Preboot/EFI/refind"
      [[ ! -d "$REFIND_PATH" ]] && REFIND_PATH="/boot/efi/EFI/refind"
      if [[ -d "$REFIND_PATH" ]]; then
        sudo cp -r refind-ambience-deer-and-fireflies/src/* "$REFIND_PATH/"
      fi
    fi
  } &>> "$LOG_FILE" || true
fi

show_progress 15 "Finalizing configuration..."

# ————————————————————————————————————————————————————————————————————— #
# Auto-configure APIs
if [[ -n "${openai_api_key:-}" ]] && command_exists openai; then
  echo "$openai_api_key" | openai config set-key &>> "$LOG_FILE" || true
fi

if [[ -n "${claude_api_key:-}" ]] && command_exists claude; then
  echo "$claude_api_key" | claude config &>> "$LOG_FILE" || true
fi

# Restart services
killall Finder Dock SystemUIServer 2>/dev/null || true

# ————————————————————————————————————————————————————————————————————— #
# Summary
printf "\r\033[K" # Clear progress line
echo -e "\n${GREEN}🎉 Setup Complete!${NC}"

if [[ "$SETUP_SUCCESS" == true ]]; then
  echo -e "${GREEN}✔ All components installed successfully${NC}"
  echo -e "${CYAN}📋 Configured: System prefs • CLI tools • AI CLIs • Apps • rEFInd${NC}"
  
  if [[ -f "$HOME/.ssh/id_ed25519.pub" && -n "${ssh_email:-}" ]]; then
    echo -e "\n${YELLOW}📋 Your SSH public key:${NC}"
    cat "$HOME/.ssh/id_ed25519.pub"
  fi
  
  echo -e "\n${CYAN}💻 Rebooting in 10 seconds...${NC}"
  for i in {10..1}; do
    printf "\rRebooting in $i seconds (Ctrl+C to cancel)..."
    sleep 1
  done
  echo -e "\n${GREEN}🔄 Rebooting...${NC}"
  sudo reboot
else
  echo -e "${YELLOW}⚠️  Some errors occurred. Check log: ${LOG_FILE}${NC}"
  
  # Auto-open log on errors
  if command_exists code; then
    code "$LOG_FILE"
  elif command_exists open; then
    open "$LOG_FILE"
  else
    echo -e "${RED}Recent errors:${NC}"
    tail -10 "$LOG_FILE" | grep -i error || tail -10 "$LOG_FILE"
  fi
  
  read -p "Reboot anyway? (y/N): " response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    sudo reboot
  fi
fi
