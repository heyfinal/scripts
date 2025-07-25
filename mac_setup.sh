#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

LOG_FILE="/tmp/mac_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

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
                                    -  v1039123123.6 by final
EOF
  printf "${NC}\n"
}

banner

echo -e "${CYAN}🔧 Starting macOS setup...${NC}"

# ————————————————————————————————————————————————————————————————————— #
# Password Management - Get sudo password once and keep it alive
echo -e "${YELLOW}🔐 This script requires administrator privileges for some operations.${NC}"
echo -e "${CYAN}Please enter your password once (it will be remembered for this session):${NC}"

# Prompt for password and validate it
sudo -v

if [[ $? -ne 0 ]]; then
  echo -e "${RED}❌ Invalid password or cancelled. Exiting.${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Password validated. Starting setup...${NC}"

# Keep sudo alive throughout the script
while true; do
  sudo -n true
  sleep 60
  kill -0 "$" || exit
done 2>/dev/null &

SUDO_PID=$!

# ————————————————————————————————————————————————————————————————————— #
# Idempotent Preference Setter (Fixed to handle typed values)
set_pref() {
  local domain=$1
  local key=$2
  shift 2
  local args=("$@")
  
  # Get current value for comparison
  local current
  current=$(defaults read "$domain" "$key" 2>/dev/null || echo "__unset__")
  
  # For boolean values, normalize the comparison
  if [[ "${args[0]}" == "-bool" ]]; then
    local target_value="${args[1]}"
    if [[ "$current" != "$target_value" ]]; then
      echo -e "${YELLOW}🔁 Setting $domain $key to ${args[*]}${NC}"
      defaults write "$domain" "$key" "${args[@]}"
    else
      echo -e "${GREEN}✔ $domain $key is already $target_value${NC}"
    fi
  # For integer values
  elif [[ "${args[0]}" == "-int" ]]; then
    local target_value="${args[1]}"
    if [[ "$current" != "$target_value" ]]; then
      echo -e "${YELLOW}🔁 Setting $domain $key to ${args[*]}${NC}"
      defaults write "$domain" "$key" "${args[@]}"
    else
      echo -e "${GREEN}✔ $domain $key is already $target_value${NC}"
    fi
  # For string values (default)
  else
    local target_value="${args[0]}"
    if [[ "$current" != "$target_value" ]]; then
      echo -e "${YELLOW}🔁 Setting $domain $key to $target_value${NC}"
      defaults write "$domain" "$key" "$target_value"
    else
      echo -e "${GREEN}✔ $domain $key is already $target_value${NC}"
    fi
  fi
}

# ————————————————————————————————————————————————————————————————————— #
# Cleanup function
cleanup() {
  echo -e "\n${YELLOW}🧹 Cleaning up...${NC}"
  # Kill the sudo keep-alive process
  if [[ -n "$SUDO_PID" ]]; then
    kill "$SUDO_PID" 2>/dev/null || true
  fi
  # Clear sudo timestamp
  sudo -k
  echo -e "${GREEN}✓ Sudo session cleared${NC}"
}

# Set trap to run cleanup on script exit
trap cleanup EXIT

# ————————————————————————————————————————————————————————————————————— #
# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ————————————————————————————————————————————————————————————————————— #
# Check if macOS app exists
app_exists() {
  local app_name="$1"
  [[ -d "/Applications/${app_name}.app" ]]
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
# Homebrew Cask Installer (Optimized with app detection)
install_brew_cask() {
  local cask=$1
  local app_name=""
  
  # Map cask names to app bundle names
  case "$cask" in
    "google-chrome") app_name="Google Chrome" ;;
    "visual-studio-code") app_name="Visual Studio Code" ;;
    "iterm2") app_name="iTerm" ;;
    "rectangle") app_name="Rectangle" ;;
    "alfred") app_name="Alfred 5" ;;
    "1password") app_name="1Password 7 - Password Manager" ;;
    "discord") app_name="Discord" ;;
    "slack") app_name="Slack" ;;
    "zoom") app_name="zoom.us" ;;
    "spotify") app_name="Spotify" ;;
    "firefox") app_name="Firefox" ;;
    *) app_name="$cask" ;;
  esac
  
  # Check if installed via Homebrew first
  if brew list --cask "$cask" &>/dev/null; then
    echo -e "${GREEN}✔ $cask already installed via Homebrew - skipping${NC}"
    return 0
  fi
  
  # Check if app exists in /Applications/
  if app_exists "$app_name"; then
    echo -e "${GREEN}✔ $app_name already exists in /Applications - skipping${NC}"
    return 0
  fi
  
  # Try alternative app names for some cases
  case "$cask" in
    "1password")
      if app_exists "1Password" || app_exists "1Password 8"; then
        echo -e "${GREEN}✔ 1Password already exists in /Applications - skipping${NC}"
        return 0
      fi
      ;;
    "alfred")
      if app_exists "Alfred" || app_exists "Alfred 4"; then
        echo -e "${GREEN}✔ Alfred already exists in /Applications - skipping${NC}"
        return 0
      fi
      ;;
  esac
  
  # Install if not found
  echo -e "${YELLOW}📱 Installing $cask...${NC}"
  brew install --cask "$cask" || {
    echo -e "${RED}✗ Failed to install $cask${NC}"
    return 1
  }
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

# Applications
echo -e "\n${CYAN}📱 Installing Applications...${NC}"
install_brew_cask "iterm2"
install_brew_cask "rectangle"
install_brew_cask "alfred"
install_brew_cask "1password"
install_brew_cask "discord"
install_brew_cask "slack"
install_brew_cask "zoom"
install_brew_cask "google-chrome"

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

# Keep Dock visible (no auto-hide)
set_pref com.apple.dock autohide -bool false

# Speed up Mission Control animations
set_pref com.apple.dock expose-animation-duration -float 0.1

# Don't show recent applications in Dock
set_pref com.apple.dock show-recents -bool false

# Set small dock icons with magnification
set_pref com.apple.dock tilesize -int 32

# Enable magnification
set_pref com.apple.dock magnification -bool true

# Set magnified icon size to large
set_pref com.apple.dock largesize -int 80

# ————————————————————————————————————————————————————————————————————— #
# Notification Settings
echo -e "\n${CYAN}🔕 Disabling Notifications...${NC}"

# Disable notification banners
set_pref com.apple.notificationcenterui bannerTime -int 0

# Disable notification sounds
set_pref com.apple.systemsound com.apple.sound.beep.volume -float 0

# Disable badge app icon in Dock
set_pref com.apple.dock persistent-apps -array

# Turn off notification center
set_pref com.apple.ncprefs dndDisplayLock -bool true
set_pref com.apple.ncprefs dndDisplaySleep -bool true

# Disable notification previews
set_pref com.apple.ncprefs content_visibility -int 2

# ————————————————————————————————————————————————————————————————————— #
# Preferences Section

echo -e "\n${CYAN}🛠 Applying Finder, Mouse, and System Preferences...${NC}"

# Finder: List view and sort by kind
set_pref com.apple.finder FXPreferredViewStyle "Nlsv"
set_pref com.apple.finder FXArrangeGroupViewBy "kind"
set_pref com.apple.finder DesktopViewSettings.IconViewSettings.arrangeBy "kind"

# Finder: Show user folder, connected servers, and hard drives in sidebar
set_pref com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
set_pref com.apple.finder ShowHardDrivesOnDesktop -bool true
set_pref com.apple.finder ShowMountedServersOnDesktop -bool true
set_pref com.apple.finder ShowRemovableMediaOnDesktop -bool true

# Finder: Show user home folder in sidebar
set_pref com.apple.finder ShowRecentTags -bool false
set_pref com.apple.finder SidebarDevicesSectionDisclosedState -bool true
set_pref com.apple.finder SidebarPlacesSectionDisclosedState -bool true
set_pref com.apple.finder SidebarSharedSectionDisclosedState -bool true

# Finder: Show these items in Finder sidebar
set_pref com.apple.finder SidebarShowingiCloudDesktop -bool false
set_pref com.apple.finder SidebarShowingSignedIntoiCloud -bool false

# Mouse and trackpad - ENSURE RIGHT-CLICK IS ENABLED
echo -e "${YELLOW}🖱️  Ensuring right-click is enabled for mouse and trackpad...${NC}"

# Mouse: Enable secondary click (right-click)
set_pref com.apple.driver.AppleBluetoothMultitouch.mouse MouseButtonMode "TwoButton"
set_pref com.apple.driver.AppleHIDMouse Button2 -int 2
set_pref com.apple.driver.AppleUSBMultitouch.mouse MouseButtonMode "TwoButton"

# Trackpad: Enable right-click 
set_pref com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true
set_pref com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 2
set_pref com.apple.AppleMultitouchTrackpad TrackpadRightClick -bool true

# System-wide trackpad settings
set_pref NSGlobalDomain ContextMenuGesture -int 1
set_pref com.apple.trackpad enableSecondaryClick -bool true
set_pref com.apple.trackpad TrackpadRightClick -bool true

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
echo -e "   • GitHub Copilot CLI"
echo -e "   • Claude CLI"
echo -e "   • Applications (iTerm2, Rectangle, Alfred, Chrome, etc.)"
echo -e "   • Oh My Zsh with plugins and Powerlevel10k theme"
echo -e "   • Kali Linux-style terminal themes for Terminal.app & iTerm2"
echo -e "   • Custom aliases: ${CYAN}chz${NC} (chmod +x) and ${CYAN}openz${NC} (open -a textedit)"
echo -e "   • SSH key generation"
echo -e "   • Finder: shows user folder, connected servers & hard drives"
echo -e "   • Mouse & trackpad: right-click enabled (multiple fallbacks)"
echo -e "   • macOS system preferences and developer tweaks"
echo -e "   • Dock: always visible, small icons with magnification on hover"
echo -e "   • Notifications: disabled system-wide"
echo -e "   • Security settings (firewall, stealth mode)"

echo -e "\n${YELLOW}📝 Post-setup notes:${NC}"
echo -e "   • Configure GitHub Copilot: ${CYAN}gh auth login${NC} then ${CYAN}gh copilot config${NC}"
echo -e "   • Configure Claude CLI: ${CYAN}claude config${NC}"
echo -e "   • Add your SSH public key to GitHub/GitLab"
echo -e "   • Run ${CYAN}p10k configure${NC} to setup Powerlevel10k theme"
echo -e "   • Restart iTerm2 to see the new Kali profile"
echo -e "   • Use ${CYAN}chz filename${NC} to make files executable"
echo -e "   • Use ${CYAN}openz filename${NC} to open files in TextEdit"
echo -e "   • ${CYAN}RIGHT-CLICK SHOULD WORK${NC} after reboot - tested on multiple devices!"
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
