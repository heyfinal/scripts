#!/usr/bin/env bash
set -euo pipefail
IFS=

# ————————————————————————————————————————————————————————————————————— #
# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
TAN='\033[38;5;180m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ————————————————————————————————————————————————————————————————————— #
# Banner
banner() {
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
        -v12393498u: a dev install sctipt for lazy peopple. by final 2025

EOF
  printf "${NC}\n"
}

banner

echo -e "${CYAN}🔧 Starting macOS setup...${NC}"

# ————————————————————————————————————————————————————————————————————— #
# PHASE 1: System Tweaks & Preferences (Run First)
# ————————————————————————————————————————————————————————————————————— #

echo -e "\n${CYAN}⚙️  PHASE 1: Applying System Tweaks & Preferences...${NC}"

# ————————————————————————————————————————————————————————————————————— #
# Idempotent Preference Setter (Robust version)
set_pref() {
  local domain=$1
  local key=$2
  shift 2
  local args=("$@")
  
  # Always try to set the preference - let defaults handle it
  # This is more reliable than trying to compare complex types
  echo -e "${YELLOW}🔁 Setting $domain $key to ${args[*]}${NC}"
  
  if defaults write "$domain" "$key" "${args[@]}" 2>/dev/null; then
    echo -e "${GREEN}✔ Successfully set $domain $key${NC}"
  else
    echo -e "${RED}✗ Failed to set $domain $key${NC}"
    SETUP_SUCCESS=false
    return 1
  fi
}

# ————————————————————————————————————————————————————————————————————— #
# Finder Preferences
echo -e "\n${CYAN}📁 Configuring Finder...${NC}"

# Finder: List view and sort by kind
set_pref com.apple.finder FXPreferredViewStyle "Nlsv"
set_pref com.apple.finder FXArrangeGroupViewBy "kind"
set_pref com.apple.finder DesktopViewSettings.IconViewSettings.arrangeBy "kind"

# Show hidden files in Finder
set_pref com.apple.finder AppleShowAllFiles -bool true

# Show file extensions
set_pref NSGlobalDomain AppleShowAllExtensions -bool true

# Auto-empty trash after 1 day
set_pref com.apple.finder FXRemoveOldTrashItems -bool true
set_pref com.apple.finder FXRemoveOldTrashItemsAge -int 1

# ————————————————————————————————————————————————————————————————————— #
# Input Device Preferences
echo -e "\n${CYAN}🖱️ Configuring Input Devices...${NC}"

# Mouse and trackpad
set_pref com.apple.driver.AppleBluetoothMultitouch.mouse MouseButtonMode "TwoButton"
set_pref com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
set_pref com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 2
set_pref com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true

# Enable tap to click
set_pref com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
set_pref com.apple.AppleMultitouchTrackpad Clicking -bool true

# Increase trackpad speed
set_pref NSGlobalDomain com.apple.trackpad.scaling -float 3.0

# Enable full keyboard access for all controls
set_pref NSGlobalDomain AppleKeyboardUIMode -int 3

# Set a fast keyboard repeat rate
set_pref NSGlobalDomain KeyRepeat -int 2
set_pref NSGlobalDomain InitialKeyRepeat -int 15

# Disable auto-correct
set_pref NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# ————————————————————————————————————————————————————————————————————— #
# System UI Preferences
echo -e "\n${CYAN}🎨 Configuring System UI...${NC}"

# Disable the "Are you sure you want to open this application?" dialog
set_pref com.apple.LaunchServices LSQuarantine -bool false

# Disable Dock animation
set_pref com.apple.dock launchanim -bool false

# Set Dock to auto-hide
set_pref com.apple.dock autohide -bool true

# Remove auto-hide delay
set_pref com.apple.dock autohide-delay -float 0

# Speed up Mission Control animations
set_pref com.apple.dock expose-animation-duration -float 0.1

# Don't show recent applications in Dock
set_pref com.apple.dock show-recents -bool false

# ————————————————————————————————————————————————————————————————————— #
# Browser Homepage Settings
echo -e "\n${CYAN}🌐 Configuring Browser Homepages...${NC}"

# Set Chrome homepage to Claude AI Projects
set_pref com.google.Chrome DefaultSearchProviderSearchURL "https://claude.ai/projects"
set_pref com.google.Chrome HomepageLocation "https://claude.ai/projects"
set_pref com.google.Chrome RestoreOnStartup -int 4
set_pref com.google.Chrome RestoreOnStartupURLs -array "https://claude.ai/projects"

# Set Safari homepage to GitHub profile
set_pref com.apple.Safari HomePage "https://github.com/heyfinal"

# ————————————————————————————————————————————————————————————————————— #
# Security & Firewall Configuration
echo -e "\n${CYAN}🛡️ Configuring Security & Firewall...${NC}"

# Firewall: Check and enable only if not active
firewall_status=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo "0")
if [[ "$firewall_status" -ne 1 ]]; then
  echo -e "${YELLOW}🔁 Enabling firewall${NC}"
  if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null; then
    echo -e "${GREEN}✔ Firewall enabled successfully${NC}"
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
  echo -e "${YELLOW}🔁 Enabling stealth mode${NC}"
  if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on 2>/dev/null; then
    echo -e "${GREEN}✔ Stealth mode enabled successfully${NC}"
  else
    echo -e "${RED}✗ Failed to enable stealth mode${NC}"
    SETUP_SUCCESS=false
  fi
else
  echo -e "${GREEN}✔ Stealth mode already enabled${NC}"
fi

# ————————————————————————————————————————————————————————————————————— #
# PHASE 2: Downloads & Installations (Run Second)  
# ————————————————————————————————————————————————————————————————————— #

echo -e "\n${CYAN}📦 PHASE 2: Starting Downloads & Installations...${NC}"

# ————————————————————————————————————————————————————————————————————— #
# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ————————————————————————————————————————————————————————————————————— #
# Install Homebrew if not present
install_homebrew() {
  if ! command_exists brew; then
    echo -e "${YELLOW}🍺 Installing Homebrew...${NC}"
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
      # Add Homebrew to PATH for Apple Silicon Macs
      if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
      else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
      fi
      echo -e "${GREEN}✔ Homebrew installed successfully${NC}"
    else
      echo -e "${RED}✗ Failed to install Homebrew${NC}"
      SETUP_SUCCESS=false
    fi
  else
    echo -e "${GREEN}✔ Homebrew already installed${NC}"
  fi
}

# ————————————————————————————————————————————————————————————————————— #
# Homebrew Package Installer (Robust)
install_brew_package() {
  local package=$1
  if brew list "$package" &>/dev/null; then
    echo -e "${GREEN}✔ $package already installed - skipping${NC}"
    return 0
  else
    echo -e "${YELLOW}📦 Installing $package...${NC}"
    if brew install "$package" 2>/dev/null; then
      echo -e "${GREEN}✔ $package installed successfully${NC}"
    else
      echo -e "${RED}✗ Failed to install $package${NC}"
      SETUP_SUCCESS=false
      return 1
    fi
  fi
}

# ————————————————————————————————————————————————————————————————————— #
# Homebrew Cask Installer (Robust)
install_brew_cask() {
  local cask=$1
  if brew list --cask "$cask" &>/dev/null; then
    echo -e "${GREEN}✔ $cask already installed - skipping${NC}"
    return 0
  else
    echo -e "${YELLOW}📱 Installing $cask...${NC}"
    if brew install --cask "$cask" 2>/dev/null; then
      echo -e "${GREEN}✔ $cask installed successfully${NC}"
    else
      echo -e "${RED}✗ Failed to install $cask${NC}"
      SETUP_SUCCESS=false
      return 1
    fi
  fi
}

# ————————————————————————————————————————————————————————————————————— #
# Package Installation Section
echo -e "\n${CYAN}📦 Installing Development Tools & CLIs...${NC}"

# Install Homebrew first
install_homebrew

# Essential CLI tools
echo -e "\n${CYAN}🔧 Installing Essential CLI Tools...${NC}"
install_brew_package "git" || SETUP_SUCCESS=false
install_brew_package "curl" || SETUP_SUCCESS=false
install_brew_package "wget" || SETUP_SUCCESS=false
install_brew_package "jq" || SETUP_SUCCESS=false
install_brew_package "tree" || SETUP_SUCCESS=false
install_brew_package "htop" || SETUP_SUCCESS=false
install_brew_package "bat" || SETUP_SUCCESS=false
install_brew_package "eza" || SETUP_SUCCESS=false
install_brew_package "fzf" || SETUP_SUCCESS=false
install_brew_package "ripgrep" || SETUP_SUCCESS=false
install_brew_package "fd" || SETUP_SUCCESS=false
install_brew_package "tldr" || SETUP_SUCCESS=false

# Development tools
echo -e "\n${CYAN}💻 Installing Development Tools...${NC}"
install_brew_package "node" || SETUP_SUCCESS=false
install_brew_package "python@3.12" || SETUP_SUCCESS=false
install_brew_package "go" || SETUP_SUCCESS=false
install_brew_package "rust" || SETUP_SUCCESS=false
install_brew_package "docker" || SETUP_SUCCESS=false
install_brew_package "docker-compose" || SETUP_SUCCESS=false

# GitHub Copilot CLI
echo -e "\n${CYAN}🤖 Installing GitHub Copilot CLI...${NC}"
if ! command_exists gh; then
  install_brew_package "gh" || SETUP_SUCCESS=false
fi

if command_exists gh && ! gh extension list 2>/dev/null | grep -q "github/gh-copilot"; then
  echo -e "${YELLOW}🔧 Installing GitHub Copilot extension...${NC}"
  if gh extension install github/gh-copilot 2>/dev/null; then
    echo -e "${GREEN}✔ GitHub Copilot extension installed${NC}"
  else
    echo -e "${YELLOW}⚠️  GitHub Copilot extension install failed - you may need to login first${NC}"
    SETUP_SUCCESS=false
  fi
else
  echo -e "${GREEN}✔ GitHub Copilot CLI already installed - skipping${NC}"
fi

# Claude CLI
echo -e "\n${CYAN}🧠 Installing Claude CLI...${NC}"
if ! command_exists claude; then
  echo -e "${YELLOW}📥 Installing Claude CLI...${NC}"
  if curl -fsSL https://claude.ai/cli/install.sh | sh 2>/dev/null; then
    echo -e "${GREEN}✔ Claude CLI installed successfully${NC}"
  else
    echo -e "${RED}✗ Claude CLI install failed - check network connection${NC}"
    SETUP_SUCCESS=false
  fi
else
  echo -e "${GREEN}✔ Claude CLI already installed - skipping${NC}"
fi

# OpenAI CLI
echo -e "\n${CYAN}🔮 Installing OpenAI CLI...${NC}"
if ! command_exists openai; then
  echo -e "${YELLOW}📥 Installing OpenAI CLI...${NC}"
  if command_exists npm; then
    if npm install -g openai-cli 2>/dev/null; then
      echo -e "${GREEN}✔ OpenAI CLI installed via npm${NC}"
    else
      echo -e "${YELLOW}⚠️  npm install failed, trying pip...${NC}"
      if pip3 install openai 2>/dev/null; then
        echo -e "${GREEN}✔ OpenAI CLI installed via pip${NC}"
      else
        echo -e "${RED}✗ OpenAI CLI install failed${NC}"
        SETUP_SUCCESS=false
      fi
    fi
  else
    if pip3 install openai 2>/dev/null; then
      echo -e "${GREEN}✔ OpenAI CLI installed via pip${NC}"
    else
      echo -e "${RED}✗ OpenAI CLI install failed - check pip and network connection${NC}"
      SETUP_SUCCESS=false
    fi
  fi
else
  echo -e "${GREEN}✔ OpenAI CLI already installed - skipping${NC}"
fi

# Applications
echo -e "\n${CYAN}📱 Installing Applications...${NC}"
install_brew_cask "google-chrome" || SETUP_SUCCESS=false
install_brew_cask "iterm2" || SETUP_SUCCESS=false
install_brew_cask "rectangle" || SETUP_SUCCESS=false
install_brew_cask "alfred" || SETUP_SUCCESS=false
install_brew_cask "1password" || SETUP_SUCCESS=false
install_brew_cask "discord" || SETUP_SUCCESS=false
install_brew_cask "slack" || SETUP_SUCCESS=false
install_brew_cask "zoom" || SETUP_SUCCESS=false

# ————————————————————————————————————————————————————————————————————— #
# Shell Enhancement Section
echo -e "\n${CYAN}🐚 Setting up Enhanced Shell Environment...${NC}"

# Install Oh My Zsh if not present
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo -e "${YELLOW}⚡ Installing Oh My Zsh...${NC}"
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo -e "${GREEN}✔ Oh My Zsh already installed - skipping${NC}"
fi

# Install useful zsh plugins
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

# zsh-autosuggestions
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  echo -e "${YELLOW}🔮 Installing zsh-autosuggestions...${NC}"
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
else
  echo -e "${GREEN}✔ zsh-autosuggestions already installed - skipping${NC}"
fi

# zsh-syntax-highlighting
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  echo -e "${YELLOW}🎨 Installing zsh-syntax-highlighting...${NC}"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
else
  echo -e "${GREEN}✔ zsh-syntax-highlighting already installed - skipping${NC}"
fi

# Powerlevel10k theme
if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
  echo -e "${YELLOW}⚡ Installing Powerlevel10k theme...${NC}"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
else
  echo -e "${GREEN}✔ Powerlevel10k already installed - skipping${NC}"
fi

# Update .zshrc with plugins and theme
if [[ -f "$HOME/.zshrc" ]]; then
  # Backup original .zshrc
  cp "$HOME/.zshrc" "$HOME/.zshrc.backup"
  
  # Update plugins
  sed -i.bak 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting docker node npm)/' "$HOME/.zshrc"
  
  # Update theme
  sed -i.bak 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc"
  
  # Add useful aliases
  cat >> "$HOME/.zshrc" << 'EOF'

# Custom aliases
alias ll='eza -la --git'
alias ls='eza'
alias cat='bat'
alias find='fd'
alias grep='rg'
alias top='htop'

# Custom shortcuts
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

# Quick navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# FZF for command history
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

EOF
fi

# ————————————————————————————————————————————————————————————————————— #
# Git Configuration
echo -e "\n${CYAN}📝 Git Configuration...${NC}"

# Check if git is configured
if [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
  echo -e "${YELLOW}🔧 Please configure Git:${NC}"
  read -p "Enter your Git username: " git_username
  read -p "Enter your Git email: " git_email
  
  git config --global user.name "$git_username"
  git config --global user.email "$git_email"
  git config --global init.defaultBranch main
  git config --global pull.rebase false
  
  echo -e "${GREEN}✔ Git configured successfully${NC}"
else
  echo -e "${GREEN}✔ Git already configured${NC}"
fi

# ————————————————————————————————————————————————————————————————————— #
# Terminal Theme Configuration (Kali Linux Style)
echo -e "\n${CYAN}🎨 Configuring Kali-style Terminal Themes...${NC}"

# Configure iTerm2 with Kali-style theme
if [[ -d "/Applications/iTerm.app" ]]; then
  echo -e "${YELLOW}🖥️  Configuring iTerm2 Kali theme...${NC}"
  
  # Create iTerm2 profile directory if it doesn't exist
  mkdir -p "$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  
  # Create Kali-style iTerm2 profile
  cat > "$HOME/Library/Application Support/iTerm2/DynamicProfiles/Kali.json" << 'EOF'
{
  "Profiles": [
    {
      "Name": "Kali",
      "Guid": "kali-linux-profile",
      "Background Color": {
        "Red Component": 0.0,
        "Green Component": 0.0,
        "Blue Component": 0.0
      },
      "Foreground Color": {
        "Red Component": 0.0,
        "Green Component": 1.0,
        "Blue Component": 0.0
      },
      "Ansi 0 Color": {
        "Red Component": 0.0,
        "Green Component": 0.0,
        "Blue Component": 0.0
      },
      "Ansi 1 Color": {
        "Red Component": 0.8,
        "Green Component": 0.0,
        "Blue Component": 0.0
      },
      "Ansi 2 Color": {
        "Red Component": 0.0,
        "Green Component": 0.8,
        "Blue Component": 0.0
      },
      "Ansi 3 Color": {
        "Red Component": 0.8,
        "Green Component": 0.8,
        "Blue Component": 0.0
      },
      "Ansi 4 Color": {
        "Red Component": 0.0,
        "Green Component": 0.0,
        "Blue Component": 0.8
      },
      "Ansi 5 Color": {
        "Red Component": 0.8,
        "Green Component": 0.0,
        "Blue Component": 0.8
      },
      "Ansi 6 Color": {
        "Red Component": 0.0,
        "Green Component": 0.8,
        "Blue Component": 0.8
      },
      "Ansi 7 Color": {
        "Red Component": 0.9,
        "Green Component": 0.9,
        "Blue Component": 0.9
      },
      "Ansi 8 Color": {
        "Red Component": 0.3,
        "Green Component": 0.3,
        "Blue Component": 0.3
      },
      "Ansi 9 Color": {
        "Red Component": 1.0,
        "Green Component": 0.0,
        "Blue Component": 0.0
      },
      "Ansi 10 Color": {
        "Red Component": 0.0,
        "Green Component": 1.0,
        "Blue Component": 0.0
      },
      "Ansi 11 Color": {
        "Red Component": 1.0,
        "Green Component": 1.0,
        "Blue Component": 0.0
      },
      "Ansi 12 Color": {
        "Red Component": 0.0,
        "Green Component": 0.0,
        "Blue Component": 1.0
      },
      "Ansi 13 Color": {
        "Red Component": 1.0,
        "Green Component": 0.0,
        "Blue Component": 1.0
      },
      "Ansi 14 Color": {
        "Red Component": 0.0,
        "Green Component": 1.0,
        "Blue Component": 1.0
      },
      "Ansi 15 Color": {
        "Red Component": 1.0,
        "Green Component": 1.0,
        "Blue Component": 1.0
      },
      "Cursor Color": {
        "Red Component": 0.0,
        "Green Component": 1.0,
        "Blue Component": 0.0
      },
      "Cursor Text Color": {
        "Red Component": 0.0,
        "Green Component": 0.0,
        "Blue Component": 0.0
      },
      "Font": {
        "Family": "MesloLGS NF"
      },
      "Non Ascii Font": {
        "Family": "MesloLGS NF"
      }
    }
  ]
}
EOF
  echo -e "${GREEN}✔ iTerm2 Kali profile created${NC}"
else
  echo -e "${YELLOW}⚠️  iTerm2 not found, skipping profile creation${NC}"
fi

# Configure Terminal.app with Kali-style theme
echo -e "${YELLOW}🖥️  Configuring Terminal.app Kali theme...${NC}"

# Create a Terminal profile XML
cat > "/tmp/Kali.terminal" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>BackgroundColor</key>
	<data>
	YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3AS
	AAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPEBww
	IDAgMCAxABABgAKABdIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhO
	U09iamVjdF8QD05TA2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FITltiaWtr
	cnN6hIyPmKqtsgAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAAC0
	</data>
	<key>Font</key>
	<data>
	YnBsaXN0MDDUAQIDBAUGGBlYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3AS
	AAGGoKQHCBESVSRudWxs1AkKCwwNDg8QVk5TU2l6ZVhOU2ZGbGFnc1ZOU05hbWVWJGNs
	YXNzI0AsAAAAAAAAEBCAAoADXxAOTWVzb G9MR1MgTkYgUmVndWxhctITFBUWWiRjbGFz
	c25hbWVYJGNsYXNzZXNWTlNGb250ohUXWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy
	0RobVHJvb3SAAQgRGiMtMjc8QktSWWJpcnR2eH+Ej5ifoqqttg==
	</data>
	<key>FontAntialias</key>
	<true/>
	<key>ProfileCurrentVersion</key>
	<real>2.04</real>
	<key>TextColor</key>
	<data>
	YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3AS
	AAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPEBww
	IDEgMCAxABABgAKABdIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhO
	U09iamVjdF8QD05TA2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FITltiaWtr
	cnN6hIyPmKqtsgAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAAC0
	</data>
	<key>name</key>
	<string>Kali</string>
	<key>type</key>
	<string>Window Settings</string>
</dict>
</plist>
EOF

# Import the Terminal profile
open "/tmp/Kali.terminal"
sleep 2

# Set as default profile
osascript -e 'tell application "Terminal" to set default settings to settings set "Kali"' 2>/dev/null || true

echo -e "${GREEN}✔ Terminal.app Kali profile created and set as default${NC}"

# ————————————————————————————————————————————————————————————————————— #
# SSH Key Setup
echo -e "\n${CYAN}🔐 SSH Key Setup...${NC}"

if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
  echo -e "${YELLOW}🔑 No SSH key found. Creating new SSH key...${NC}"
  read -p "Enter your email for SSH key: " ssh_email
  ssh-keygen -t ed25519 -C "$ssh_email" -f "$HOME/.ssh/id_ed25519" -N ""
  
  # Start SSH agent and add key
  eval "$(ssh-agent -s)"
  ssh-add "$HOME/.ssh/id_ed25519"
  
  echo -e "${GREEN}✔ SSH key created at ~/.ssh/id_ed25519${NC}"
  echo -e "${YELLOW}📋 Your public key (add to GitHub/GitLab):${NC}"
  cat "$HOME/.ssh/id_ed25519.pub"
else
  echo -e "${GREEN}✔ SSH key already exists${NC}"
fi

# ————————————————————————————————————————————————————————————————————— #
# macOS Developer Tweaks
echo -e "\n${CYAN}⚙️  Additional macOS Developer Tweaks...${NC}"

# Show hidden files in Finder
set_pref com.apple.finder AppleShowAllFiles -bool true

# Show file extensions
set_pref NSGlobalDomain AppleShowAllExtensions -bool true

# Disable the "Are you sure you want to open this application?" dialog
set_pref com.apple.LaunchServices LSQuarantine -bool false

# Enable full keyboard access for all controls
set_pref NSGlobalDomain AppleKeyboardUIMode -int 3

# Set a fast keyboard repeat rate
set_pref NSGlobalDomain KeyRepeat -int 2
set_pref NSGlobalDomain InitialKeyRepeat -int 15

# Disable auto-correct
set_pref NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Enable tap to click
set_pref com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
set_pref com.apple.AppleMultitouchTrackpad Clicking -bool true

# Increase trackpad speed
set_pref NSGlobalDomain com.apple.trackpad.scaling -float 3.0

# Disable Dock animation
set_pref com.apple.dock launchanim -bool false

# Set Dock to auto-hide
set_pref com.apple.dock autohide -bool true

# Remove auto-hide delay
set_pref com.apple.dock autohide-delay -float 0

# Speed up Mission Control animations
set_pref com.apple.dock expose-animation-duration -float 0.1

# Don't show recent applications in Dock
set_pref com.apple.dock show-recents -bool false

# ————————————————————————————————————————————————————————————————————— #
# Preferences Section

echo -e "\n${CYAN}🛠 Applying Finder, Mouse, and System Preferences...${NC}"

# Finder: List view and sort by kind
set_pref com.apple.finder FXPreferredViewStyle "Nlsv"
set_pref com.apple.finder FXArrangeGroupViewBy "kind"
set_pref com.apple.finder DesktopViewSettings.IconViewSettings.arrangeBy "kind"

# Mouse and trackpad (Fixed the boolean syntax)
set_pref com.apple.driver.AppleBluetoothMultitouch.mouse MouseButtonMode "TwoButton"
set_pref com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
set_pref com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 2
set_pref com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true

# Auto-empty trash after 1 day
set_pref com.apple.finder FXRemoveOldTrashItems -bool true
set_pref com.apple.finder FXRemoveOldTrashItemsAge -int 1

# Firewall: Check and enable only if not active
firewall_status=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo "0")
if [[ "$firewall_status" -ne 1 ]]; then
  echo -e "${YELLOW}🔁 Enabling firewall${NC}"
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
else
  echo -e "${GREEN}✔ Firewall already enabled${NC}"
fi

# Firewall: Stealth Mode
stealth_status=$(defaults read /Library/Preferences/com.apple.alf stealthenabled 2>/dev/null || echo "0")
if [[ "$stealth_status" -ne 1 ]]; then
  echo -e "${YELLOW}🔁 Enabling stealth mode${NC}"
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
else
  echo -e "${GREEN}✔ Stealth mode already enabled${NC}"
fi

# Firewall logging
log_status=$(defaults read /Library/Preferences/com.apple.alf loggingenabled 2>/dev/null || echo "0")
if [[ "$log_status" -ne 1 ]]; then
  echo -e "${YELLOW}🔁 Enabling firewall logging${NC}"
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on
else
  echo -e "${GREEN}✔ Firewall logging already enabled${NC}"
fi

# ————————————————————————————————————————————————————————————————————— #
# Restart services to apply changes
echo -e "\n${CYAN}🔄 Restarting services to apply changes...${NC}"

# Restart Finder
echo -e "${YELLOW}🔄 Restarting Finder...${NC}"
killall Finder 2>/dev/null || true

# Restart Dock
echo -e "${YELLOW}🔄 Restarting Dock...${NC}"
killall Dock 2>/dev/null || true

# Restart SystemUIServer for trackpad changes
echo -e "${YELLOW}🔄 Restarting SystemUIServer...${NC}"
killall SystemUIServer 2>/dev/null || true

# ————————————————————————————————————————————————————————————————————— #
# Summary
echo -e "\n${GREEN}🎉 macOS setup completed successfully!${NC}"
echo -e "\n${CYAN}📋 Summary of what was installed/configured:${NC}"
echo -e "   • Homebrew package manager"
echo -e "   • Essential CLI tools (git, curl, jq, bat, eza, fzf, etc.)"
echo -e "   • Development tools (Node.js, Python, Go, Rust, Docker)"
echo -e "   • AI CLIs: GitHub Copilot, Claude, OpenAI"
echo -e "   • Applications (iTerm2, Rectangle, Alfred, 1Password, Discord, Slack, Zoom)"
echo -e "   • Oh My Zsh with plugins and Powerlevel10k theme"
echo -e "   • Kali Linux-style terminal themes for Terminal.app & iTerm2"
echo -e "   • Custom aliases: ${CYAN}chz${NC} (chmod +x) and ${CYAN}openz${NC} (open -a textedit)"
echo -e "   • SSH key generation"
echo -e "   • macOS system preferences and developer tweaks"
echo -e "   • Security settings (firewall, stealth mode)"

echo -e "\n${YELLOW}📝 Post-setup notes:${NC}"
echo -e "   • Configure GitHub Copilot: ${CYAN}gh auth login${NC} then ${CYAN}gh copilot config${NC}"
echo -e "   • Configure Claude CLI: ${CYAN}claude config${NC}"
echo -e "   • Configure OpenAI CLI: ${CYAN}openai config${NC} (set your API key)"
echo -e "   • Add your SSH public key to GitHub/GitLab"
echo -e "   • Run ${CYAN}p10k configure${NC} to setup Powerlevel10k theme"
echo -e "   • Restart iTerm2 to see the new Kali profile"
echo -e "   • Use ${CYAN}chz filename${NC} to make files executable"
echo -e "   • Use ${CYAN}openz filename${NC} to open files in TextEdit"
echo -e "   • Consider configuring 1Password and other installed apps"

# Added reboot functionality (only if successful)
if [[ "$SETUP_SUCCESS" == true ]]; then
  echo -e "\n${GREEN}🎉 Setup completed successfully with no errors!${NC}"
  echo -e "\n${CYAN}💻 System will reboot in 15 seconds to complete setup...${NC}"
  echo -e "${YELLOW}Press Ctrl+C to cancel reboot${NC}"

  for i in {15..1}; do
    echo -ne "\rRebooting in $i seconds... "
    sleep 1
  done

  echo -e "\n${GREEN}🔄 Rebooting now...${NC}"
  sudo reboot
else
  echo -e "\n${YELLOW}⚠️  Setup completed with some errors.${NC}"
  echo -e "${YELLOW}Check the log file at: $LOG_FILE${NC}"
  echo -e "\n${CYAN}Would you like to reboot anyway? (y/N):${NC}"
  read -r response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🔄 Rebooting...${NC}"
    sudo reboot
  else
    echo -e "${GREEN}Setup complete. Reboot manually when ready.${NC}"
  fi
fi\n\t'

LOG_FILE="/tmp/mac_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Track success status
SETUP_SUCCESS=true

# Error handler
handle_error() {
  local exit_code=$?
  echo -e "\n${RED}❌ Setup encountered an error (exit code: $exit_code)${NC}"
  echo -e "${YELLOW}Check the log file at: $LOG_FILE${NC}"
  SETUP_SUCCESS=false
}

# Set error trap
trap 'handle_error' ERR

# ————————————————————————————————————————————————————————————————————— #
# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
TAN='\033[38;5;180m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ————————————————————————————————————————————————————————————————————— #
# Banner
banner() {
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
        -v12393498u: a dev install sctipt for lazy peopple. by final 2025

EOF
  printf "${NC}\n"
}

banner

echo -e "${CYAN}🔧 Starting macOS setup...${NC}"

# ————————————————————————————————————————————————————————————————————— #
# Idempotent Preference Setter (Robust version)
set_pref() {
  local domain=$1
  local key=$2
  shift 2
  local args=("$@")
  
  # Always try to set the preference - let defaults handle it
  # This is more reliable than trying to compare complex types
  echo -e "${YELLOW}🔁 Setting $domain $key to ${args[*]}${NC}"
  
  if defaults write "$domain" "$key" "${args[@]}" 2>/dev/null; then
    echo -e "${GREEN}✔ Successfully set $domain $key${NC}"
  else
    echo -e "${RED}✗ Failed to set $domain $key${NC}"
    return 1
  fi
}

# ————————————————————————————————————————————————————————————————————— #
# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ————————————————————————————————————————————————————————————————————— #
# Install Homebrew if not present
install_homebrew() {
  if ! command_exists brew; then
    echo -e "${YELLOW}🍺 Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == "arm64" ]]; then
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    echo -e "${GREEN}✔ Homebrew already installed${NC}"
  fi
}

# ————————————————————————————————————————————————————————————————————— #
# Homebrew Package Installer (Optimized)
install_brew_package() {
  local package=$1
  if brew list "$package" &>/dev/null; then
    echo -e "${GREEN}✔ $package already installed - skipping${NC}"
    return 0
  else
    echo -e "${YELLOW}📦 Installing $package...${NC}"
    brew install "$package" || {
      echo -e "${RED}✗ Failed to install $package${NC}"
      return 1
    }
  fi
}

# ————————————————————————————————————————————————————————————————————— #
# Homebrew Cask Installer (Optimized)
install_brew_cask() {
  local cask=$1
  if brew list --cask "$cask" &>/dev/null; then
    echo -e "${GREEN}✔ $cask already installed - skipping${NC}"
    return 0
  else
    echo -e "${YELLOW}📱 Installing $cask...${NC}"
    brew install --cask "$cask" || {
      echo -e "${RED}✗ Failed to install $cask${NC}"
      return 1
    }
  fi
}

# ————————————————————————————————————————————————————————————————————— #
# Package Installation Section
echo -e "\n${CYAN}📦 Installing Development Tools & CLIs...${NC}"

# Install Homebrew first
install_homebrew

# Essential CLI tools
echo -e "\n${CYAN}🔧 Installing Essential CLI Tools...${NC}"
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

# Development tools
echo -e "\n${CYAN}💻 Installing Development Tools...${NC}"
install_brew_package "node"
install_brew_package "python@3.12"
install_brew_package "go"
install_brew_package "rust"
install_brew_package "docker"
install_brew_package "docker-compose"

# GitHub Copilot CLI
echo -e "\n${CYAN}🤖 Installing GitHub Copilot CLI...${NC}"
if ! command_exists gh; then
  install_brew_package "gh"
fi

if ! gh extension list 2>/dev/null | grep -q "github/gh-copilot"; then
  echo -e "${YELLOW}🔧 Installing GitHub Copilot extension...${NC}"
  gh extension install github/gh-copilot || echo -e "${YELLOW}⚠️  GitHub Copilot extension install failed - you may need to login first${NC}"
else
  echo -e "${GREEN}✔ GitHub Copilot CLI already installed - skipping${NC}"
fi

# Claude CLI
echo -e "\n${CYAN}🧠 Installing Claude CLI...${NC}"
if ! command_exists claude; then
  echo -e "${YELLOW}📥 Installing Claude CLI...${NC}"
  curl -fsSL https://claude.ai/cli/install.sh | sh || echo -e "${YELLOW}⚠️  Claude CLI install failed - check network connection${NC}"
else
  echo -e "${GREEN}✔ Claude CLI already installed - skipping${NC}"
fi

# OpenAI CLI
echo -e "\n${CYAN}🔮 Installing OpenAI CLI...${NC}"
if ! command_exists openai; then
  echo -e "${YELLOW}📥 Installing OpenAI CLI...${NC}"
  if command_exists npm; then
    npm install -g openai-cli || echo -e "${YELLOW}⚠️  OpenAI CLI install failed - check npm and network connection${NC}"
  else
    echo -e "${YELLOW}⚠️  npm not found, installing via pip...${NC}"
    pip3 install openai || echo -e "${YELLOW}⚠️  OpenAI CLI install failed - check pip and network connection${NC}"
  fi
else
  echo -e "${GREEN}✔ OpenAI CLI already installed - skipping${NC}"
fi

# Applications
echo -e "\n${CYAN}📱 Installing Applications...${NC}"
install_brew_cask "iterm2"
install_brew_cask "rectangle"
install_brew_cask "alfred"
install_brew_cask "1password"
install_brew_cask "discord"
install_brew_cask "slack"
install_brew_cask "zoom"

# ————————————————————————————————————————————————————————————————————— #
# Shell Enhancement Section
echo -e "\n${CYAN}🐚 Setting up Enhanced Shell Environment...${NC}"

# Install Oh My Zsh if not present
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo -e "${YELLOW}⚡ Installing Oh My Zsh...${NC}"
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo -e "${GREEN}✔ Oh My Zsh already installed - skipping${NC}"
fi

# Install useful zsh plugins
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

# zsh-autosuggestions
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
  echo -e "${YELLOW}🔮 Installing zsh-autosuggestions...${NC}"
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
else
  echo -e "${GREEN}✔ zsh-autosuggestions already installed - skipping${NC}"
fi

# zsh-syntax-highlighting
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
  echo -e "${YELLOW}🎨 Installing zsh-syntax-highlighting...${NC}"
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
else
  echo -e "${GREEN}✔ zsh-syntax-highlighting already installed - skipping${NC}"
fi

# Powerlevel10k theme
if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
  echo -e "${YELLOW}⚡ Installing Powerlevel10k theme...${NC}"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
else
  echo -e "${GREEN}✔ Powerlevel10k already installed - skipping${NC}"
fi

# Update .zshrc with plugins and theme
if [[ -f "$HOME/.zshrc" ]]; then
  # Backup original .zshrc
  cp "$HOME/.zshrc" "$HOME/.zshrc.backup"
  
  # Update plugins
  sed -i.bak 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting docker node npm)/' "$HOME/.zshrc"
  
  # Update theme
  sed -i.bak 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc"
  
  # Add useful aliases
  cat >> "$HOME/.zshrc" << 'EOF'

# Custom aliases
alias ll='eza -la --git'
alias ls='eza'
alias cat='bat'
alias find='fd'
alias grep='rg'
alias top='htop'

# Custom shortcuts
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

# Quick navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# FZF for command history
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

EOF
fi

# ————————————————————————————————————————————————————————————————————— #
# Git Configuration
echo -e "\n${CYAN}📝 Git Configuration...${NC}"

# Check if git is configured
if [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
  echo -e "${YELLOW}🔧 Please configure Git:${NC}"
  read -p "Enter your Git username: " git_username
  read -p "Enter your Git email: " git_email
  
  git config --global user.name "$git_username"
  git config --global user.email "$git_email"
  git config --global init.defaultBranch main
  git config --global pull.rebase false
  
  echo -e "${GREEN}✔ Git configured successfully${NC}"
else
  echo -e "${GREEN}✔ Git already configured${NC}"
fi

# ————————————————————————————————————————————————————————————————————— #
# Terminal Theme Configuration (Kali Linux Style)
echo -e "\n${CYAN}🎨 Configuring Kali-style Terminal Themes...${NC}"

# Configure iTerm2 with Kali-style theme
if [[ -d "/Applications/iTerm.app" ]]; then
  echo -e "${YELLOW}🖥️  Configuring iTerm2 Kali theme...${NC}"
  
  # Create iTerm2 profile directory if it doesn't exist
  mkdir -p "$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  
  # Create Kali-style iTerm2 profile
  cat > "$HOME/Library/Application Support/iTerm2/DynamicProfiles/Kali.json" << 'EOF'
{
  "Profiles": [
    {
      "Name": "Kali",
      "Guid": "kali-linux-profile",
      "Background Color": {
        "Red Component": 0.0,
        "Green Component": 0.0,
        "Blue Component": 0.0
      },
      "Foreground Color": {
        "Red Component": 0.0,
        "Green Component": 1.0,
        "Blue Component": 0.0
      },
      "Ansi 0 Color": {
        "Red Component": 0.0,
        "Green Component": 0.0,
        "Blue Component": 0.0
      },
      "Ansi 1 Color": {
        "Red Component": 0.8,
        "Green Component": 0.0,
        "Blue Component": 0.0
      },
      "Ansi 2 Color": {
        "Red Component": 0.0,
        "Green Component": 0.8,
        "Blue Component": 0.0
      },
      "Ansi 3 Color": {
        "Red Component": 0.8,
        "Green Component": 0.8,
        "Blue Component": 0.0
      },
      "Ansi 4 Color": {
        "Red Component": 0.0,
        "Green Component": 0.0,
        "Blue Component": 0.8
      },
      "Ansi 5 Color": {
        "Red Component": 0.8,
        "Green Component": 0.0,
        "Blue Component": 0.8
      },
      "Ansi 6 Color": {
        "Red Component": 0.0,
        "Green Component": 0.8,
        "Blue Component": 0.8
      },
      "Ansi 7 Color": {
        "Red Component": 0.9,
        "Green Component": 0.9,
        "Blue Component": 0.9
      },
      "Ansi 8 Color": {
        "Red Component": 0.3,
        "Green Component": 0.3,
        "Blue Component": 0.3
      },
      "Ansi 9 Color": {
        "Red Component": 1.0,
        "Green Component": 0.0,
        "Blue Component": 0.0
      },
      "Ansi 10 Color": {
        "Red Component": 0.0,
        "Green Component": 1.0,
        "Blue Component": 0.0
      },
      "Ansi 11 Color": {
        "Red Component": 1.0,
        "Green Component": 1.0,
        "Blue Component": 0.0
      },
      "Ansi 12 Color": {
        "Red Component": 0.0,
        "Green Component": 0.0,
        "Blue Component": 1.0
      },
      "Ansi 13 Color": {
        "Red Component": 1.0,
        "Green Component": 0.0,
        "Blue Component": 1.0
      },
      "Ansi 14 Color": {
        "Red Component": 0.0,
        "Green Component": 1.0,
        "Blue Component": 1.0
      },
      "Ansi 15 Color": {
        "Red Component": 1.0,
        "Green Component": 1.0,
        "Blue Component": 1.0
      },
      "Cursor Color": {
        "Red Component": 0.0,
        "Green Component": 1.0,
        "Blue Component": 0.0
      },
      "Cursor Text Color": {
        "Red Component": 0.0,
        "Green Component": 0.0,
        "Blue Component": 0.0
      },
      "Font": {
        "Family": "MesloLGS NF"
      },
      "Non Ascii Font": {
        "Family": "MesloLGS NF"
      }
    }
  ]
}
EOF
  echo -e "${GREEN}✔ iTerm2 Kali profile created${NC}"
else
  echo -e "${YELLOW}⚠️  iTerm2 not found, skipping profile creation${NC}"
fi

# Configure Terminal.app with Kali-style theme
echo -e "${YELLOW}🖥️  Configuring Terminal.app Kali theme...${NC}"

# Create a Terminal profile XML
cat > "/tmp/Kali.terminal" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>BackgroundColor</key>
	<data>
	YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3AS
	AAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPEBww
	IDAgMCAxABABgAKABdIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhO
	U09iamVjdF8QD05TA2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FITltiaWtr
	cnN6hIyPmKqtsgAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAAC0
	</data>
	<key>Font</key>
	<data>
	YnBsaXN0MDDUAQIDBAUGGBlYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3AS
	AAGGoKQHCBESVSRudWxs1AkKCwwNDg8QVk5TU2l6ZVhOU2ZGbGFnc1ZOU05hbWVWJGNs
	YXNzI0AsAAAAAAAAEBCAAoADXxAOTWVzb G9MR1MgTkYgUmVndWxhctITFBUWWiRjbGFz
	c25hbWVYJGNsYXNzZXNWTlNGb250ohUXWE5TT2JqZWN0XxAPTlNLZXllZEFyY2hpdmVy
	0RobVHJvb3SAAQgRGiMtMjc8QktSWWJpcnR2eH+Ej5ifoqqttg==
	</data>
	<key>FontAntialias</key>
	<true/>
	<key>ProfileCurrentVersion</key>
	<real>2.04</real>
	<key>TextColor</key>
	<data>
	YnBsaXN0MDDUAQIDBAUGFRZYJHZlcnNpb25YJG9iamVjdHNZJGFyY2hpdmVyVCR0b3AS
	AAGGoKMHCA9VJG51bGzTCQoLDA0OVU5TUkdCXE5TQ29sb3JTcGFjZVYkY2xhc3NPEBww
	IDEgMCAxABABgAKABdIQERITWiRjbGFzc25hbWVYJGNsYXNzZXNXTlNDb2xvcqISFFhO
	U09iamVjdF8QD05TA2V5ZWRBcmNoaXZlctEXGFRyb290gAEIERojLTI3O0FITltiaWtr
	cnN6hIyPmKqtsgAAAAAAAAEBAAAAAAAAABkAAAAAAAAAAAAAAAAAAAC0
	</data>
	<key>name</key>
	<string>Kali</string>
	<key>type</key>
	<string>Window Settings</string>
</dict>
</plist>
EOF

# Import the Terminal profile
open "/tmp/Kali.terminal"
sleep 2

# Set as default profile
osascript -e 'tell application "Terminal" to set default settings to settings set "Kali"' 2>/dev/null || true

echo -e "${GREEN}✔ Terminal.app Kali profile created and set as default${NC}"

# ————————————————————————————————————————————————————————————————————— #
# SSH Key Setup
echo -e "\n${CYAN}🔐 SSH Key Setup...${NC}"

if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
  echo -e "${YELLOW}🔑 No SSH key found. Creating new SSH key...${NC}"
  read -p "Enter your email for SSH key: " ssh_email
  ssh-keygen -t ed25519 -C "$ssh_email" -f "$HOME/.ssh/id_ed25519" -N ""
  
  # Start SSH agent and add key
  eval "$(ssh-agent -s)"
  ssh-add "$HOME/.ssh/id_ed25519"
  
  echo -e "${GREEN}✔ SSH key created at ~/.ssh/id_ed25519${NC}"
  echo -e "${YELLOW}📋 Your public key (add to GitHub/GitLab):${NC}"
  cat "$HOME/.ssh/id_ed25519.pub"
else
  echo -e "${GREEN}✔ SSH key already exists${NC}"
fi

# ————————————————————————————————————————————————————————————————————— #
# macOS Developer Tweaks
echo -e "\n${CYAN}⚙️  Additional macOS Developer Tweaks...${NC}"

# Show hidden files in Finder
set_pref com.apple.finder AppleShowAllFiles -bool true

# Show file extensions
set_pref NSGlobalDomain AppleShowAllExtensions -bool true

# Disable the "Are you sure you want to open this application?" dialog
set_pref com.apple.LaunchServices LSQuarantine -bool false

# Enable full keyboard access for all controls
set_pref NSGlobalDomain AppleKeyboardUIMode -int 3

# Set a fast keyboard repeat rate
set_pref NSGlobalDomain KeyRepeat -int 2
set_pref NSGlobalDomain InitialKeyRepeat -int 15

# Disable auto-correct
set_pref NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Enable tap to click
set_pref com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
set_pref com.apple.AppleMultitouchTrackpad Clicking -bool true

# Increase trackpad speed
set_pref NSGlobalDomain com.apple.trackpad.scaling -float 3.0

# Disable Dock animation
set_pref com.apple.dock launchanim -bool false

# Set Dock to auto-hide
set_pref com.apple.dock autohide -bool true

# Remove auto-hide delay
set_pref com.apple.dock autohide-delay -float 0

# Speed up Mission Control animations
set_pref com.apple.dock expose-animation-duration -float 0.1

# Don't show recent applications in Dock
set_pref com.apple.dock show-recents -bool false

# ————————————————————————————————————————————————————————————————————— #
# Preferences Section

echo -e "\n${CYAN}🛠 Applying Finder, Mouse, and System Preferences...${NC}"

# Finder: List view and sort by kind
set_pref com.apple.finder FXPreferredViewStyle "Nlsv"
set_pref com.apple.finder FXArrangeGroupViewBy "kind"
set_pref com.apple.finder DesktopViewSettings.IconViewSettings.arrangeBy "kind"

# Mouse and trackpad (Fixed the boolean syntax)
set_pref com.apple.driver.AppleBluetoothMultitouch.mouse MouseButtonMode "TwoButton"
set_pref com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
set_pref com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 2
set_pref com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true

# Auto-empty trash after 1 day
set_pref com.apple.finder FXRemoveOldTrashItems -bool true
set_pref com.apple.finder FXRemoveOldTrashItemsAge -int 1

# Firewall: Check and enable only if not active
firewall_status=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo "0")
if [[ "$firewall_status" -ne 1 ]]; then
  echo -e "${YELLOW}🔁 Enabling firewall${NC}"
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
else
  echo -e "${GREEN}✔ Firewall already enabled${NC}"
fi

# Firewall: Stealth Mode
stealth_status=$(defaults read /Library/Preferences/com.apple.alf stealthenabled 2>/dev/null || echo "0")
if [[ "$stealth_status" -ne 1 ]]; then
  echo -e "${YELLOW}🔁 Enabling stealth mode${NC}"
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
else
  echo -e "${GREEN}✔ Stealth mode already enabled${NC}"
fi

# Firewall logging
log_status=$(defaults read /Library/Preferences/com.apple.alf loggingenabled 2>/dev/null || echo "0")
if [[ "$log_status" -ne 1 ]]; then
  echo -e "${YELLOW}🔁 Enabling firewall logging${NC}"
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on
else
  echo -e "${GREEN}✔ Firewall logging already enabled${NC}"
fi

# ————————————————————————————————————————————————————————————————————— #
# Restart services to apply changes
echo -e "\n${CYAN}🔄 Restarting services to apply changes...${NC}"

# Restart Finder
echo -e "${YELLOW}🔄 Restarting Finder...${NC}"
killall Finder 2>/dev/null || true

# Restart Dock
echo -e "${YELLOW}🔄 Restarting Dock...${NC}"
killall Dock 2>/dev/null || true

# Restart SystemUIServer for trackpad changes
echo -e "${YELLOW}🔄 Restarting SystemUIServer...${NC}"
killall SystemUIServer 2>/dev/null || true

# ————————————————————————————————————————————————————————————————————— #
# Summary
echo -e "\n${GREEN}🎉 macOS setup completed successfully!${NC}"
echo -e "\n${CYAN}📋 Summary of what was installed/configured:${NC}"
echo -e "   • Homebrew package manager"
echo -e "   • Essential CLI tools (git, curl, jq, bat, eza, fzf, etc.)"
echo -e "   • Development tools (Node.js, Python, Go, Rust, Docker)"
echo -e "   • AI CLIs: GitHub Copilot, Claude, OpenAI"
echo -e "   • Applications (iTerm2, Rectangle, Alfred, 1Password, Discord, Slack, Zoom)"
echo -e "   • Oh My Zsh with plugins and Powerlevel10k theme"
echo -e "   • Kali Linux-style terminal themes for Terminal.app & iTerm2"
echo -e "   • Custom aliases: ${CYAN}chz${NC} (chmod +x) and ${CYAN}openz${NC} (open -a textedit)"
echo -e "   • SSH key generation"
echo -e "   • macOS system preferences and developer tweaks"
echo -e "   • Security settings (firewall, stealth mode)"

echo -e "\n${YELLOW}📝 Post-setup notes:${NC}"
echo -e "   • Configure GitHub Copilot: ${CYAN}gh auth login${NC} then ${CYAN}gh copilot config${NC}"
echo -e "   • Configure Claude CLI: ${CYAN}claude config${NC}"
echo -e "   • Configure OpenAI CLI: ${CYAN}openai config${NC} (set your API key)"
echo -e "   • Add your SSH public key to GitHub/GitLab"
echo -e "   • Run ${CYAN}p10k configure${NC} to setup Powerlevel10k theme"
echo -e "   • Restart iTerm2 to see the new Kali profile"
echo -e "   • Use ${CYAN}chz filename${NC} to make files executable"
echo -e "   • Use ${CYAN}openz filename${NC} to open files in TextEdit"
echo -e "   • Consider configuring 1Password and other installed apps"

# Added reboot functionality
echo -e "\n${CYAN}💻 System will reboot in 15 seconds to complete setup...${NC}"
echo -e "${YELLOW}Press Ctrl+C to cancel reboot${NC}"

for i in {15..1}; do
  echo -ne "\rRebooting in $i seconds... "
  sleep 1
done

echo -e "\n${GREEN}🔄 Rebooting now...${NC}"
sudo reboot
