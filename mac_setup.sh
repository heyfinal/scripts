#!/usr/bin/env bash
set -euo pipefail
IFS=

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
  # Show input line (line 14) and clear any previous content
  printf "\033[14;1H${CLEAR_LINE}${GREEN}${prompt}${NC}"
}

clear_input() {
  # Clear input line and the line above it to remove any residual text
  printf "\033[14;1H${CLEAR_LINE}"
  printf "\033[13;1H\033[K"
  printf "\033[15;1H\033[K"
  printf "\033[16;1H\033[K"
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

# ————————————————————————————————————————————————————————————————————— #
# Configuration Collection (Enhanced with persistence)
update_status "Checking for previous configuration..."

# Initialize variables
git_username=""
git_email=""
ssh_email=""
openai_api_key=""
claude_api_key=""
github_token=""

# Try to load existing configuration
if load_config && [[ "${config_saved:-}" == "true" ]]; then
  show_saved_config
  read -r use_existing
  clear_config_display
  
  if [[ "$use_existing" =~ ^[Nn]$ ]]; then
    update_status "Collecting new configuration..."
    # Clear variables to force re-entry
    git_username=""
    git_email=""
    ssh_email=""
    openai_api_key=""
    claude_api_key=""
    github_token=""
  else
    update_status "Using saved configuration"
    printf "\033[15;1H${GREEN}✔ Using saved configuration from previous run${NC}\n"
    sleep 2
    printf "\033[15;1H${CLEAR_LINE}"
    
    # Skip to setup if we have saved config
    update_progress 1
    update_status "Starting setup with saved configuration..."
    # Jump to the sudo setup section
  fi
else
  update_status "No previous configuration found - collecting new information..."
  printf "\033[15;1H${CYAN}🔧 Please provide the following information (will be saved for future runs):${NC}\n"
  sleep 2
  printf "\033[15;1H${CLEAR_LINE}"
fi

# Only collect missing information
need_config=false

# Git config
if [[ -z "$git_username" ]] && [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
  need_config=true
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
elif [[ -z "$git_username" ]]; then
  git_username=$(git config --global user.name)
  git_email=$(git config --global user.email)
  printf "\033[15;1H${GREEN}✔ Using existing Git config: ${git_username} <${git_email}>${NC}\n"
  sleep 1
  printf "\033[15;1H${CLEAR_LINE}"
fi

# SSH key
if [[ -z "$ssh_email" ]] && [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
  need_config=true
  show_input "Email for SSH key: "
  read -r ssh_email
  clear_input
  printf "\033[14;1H${CLEAR_LINE}${GREEN}✔ SSH email: ${ssh_email}${NC}"
  sleep 1
  clear_input
elif [[ -z "$ssh_email" ]]; then
  printf "\033[15;1H${GREEN}✔ SSH key already exists${NC}\n"
  sleep 1
  printf "\033[15;1H${CLEAR_LINE}"
fi

# API Keys with validation (secure input)
while true; do
  show_input "OpenAI API key (optional, starts with sk-proj- or sk-): "
  read -s openai_api_key
  clear_input
  # Clear entire screen area where key might have been displayed
  printf "\033[13;1H\033[K\033[14;1H\033[K\033[15;1H\033[K\033[16;1H\033[K"
  
  if validate_api_key "$openai_api_key" "openai"; then
    if [[ -n "$openai_api_key" ]]; then
      printf "\033[14;1H${CLEAR_LINE}${GREEN}✔ OpenAI API key entered (hidden)${NC}"
      sleep 1
      clear_input
    fi
    break
  fi
  clear_input
done

while true; do
  show_input "Claude API key (optional, starts with sk-ant-): "
  read -s claude_api_key
  clear_input
  # Clear entire screen area where key might have been displayed
  printf "\033[13;1H\033[K\033[14;1H\033[K\033[15;1H\033[K\033[16;1H\033[K"
  
  if validate_api_key "$claude_api_key" "claude"; then
    if [[ -n "$claude_api_key" ]]; then
      printf "\033[14;1H${CLEAR_LINE}${GREEN}✔ Claude API key entered (hidden)${NC}"
      sleep 1
      clear_input
    fi
    break
  fi
  clear_input
done

# GitHub Token for Copilot (secure input)
while true; do
  show_input "GitHub token (for Copilot, optional, starts with ghp_): "
  read -s github_token
  clear_input
  # Clear entire screen area where token might have been displayed
  printf "\033[13;1H\033[K\033[14;1H\033[K\033[15;1H\033[K\033[16;1H\033[K"
  
  if validate_api_key "$github_token" "github"; then
    if [[ -n "$github_token" ]]; then
      printf "\033[14;1H${CLEAR_LINE}${GREEN}✔ GitHub token entered (hidden)${NC}"
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
# Homebrew (Enhanced for OpenCore/Sequoia)
if ! command_exists brew; then
  # First, install Xcode Command Line Tools if not present
  if ! xcode-select -p >/dev/null 2>&1; then
    update_status "Checking for Xcode Command Line Tools..."
    
    # Clear progress area and show important notice
    printf "\033[15;1H${CLEAR_LINE}${RED}⚠️  SCRIPT WILL PAUSE - USER ACTION REQUIRED${NC}\n"
    printf "\033[16;1H${CLEAR_LINE}${YELLOW}Xcode Command Line Tools need to be installed (required for Homebrew)${NC}\n"
    printf "\033[17;1H${CLEAR_LINE}${CYAN}This will:${NC}\n"
    printf "\033[18;1H${CLEAR_LINE}${CYAN}  1. Open a dialog asking to install Command Line Tools${NC}\n"
    printf "\033[19;1H${CLEAR_LINE}${CYAN}  2. Download ~500MB (may take 5-15 minutes depending on internet)${NC}\n"
    printf "\033[20;1H${CLEAR_LINE}${CYAN}  3. Install automatically after download${NC}\n"
    printf "\033[21;1H${CLEAR_LINE}${GREEN}Press any key to continue and trigger the installation...${NC}"
    read -n 1 -s
    
    # Clear the notice area
    for i in {15..21}; do
      printf "\033[${i};1H${CLEAR_LINE}"
    done
    
    update_status "Triggering Xcode Command Line Tools installation..."
    xcode-select --install 2>/dev/null || true
    
    # Show pause notice
    printf "\033[15;1H${CLEAR_LINE}${YELLOW}📥 SCRIPT PAUSED - Xcode Command Line Tools installing...${NC}\n"
    printf "\033[16;1H${CLEAR_LINE}${CYAN}Please:${NC}\n"
    printf "\033[17;1H${CLEAR_LINE}${CYAN}  1. Click 'Install' in the popup dialog${NC}\n"
    printf "\033[18;1H${CLEAR_LINE}${CYAN}  2. Wait for download to complete (~5-15 minutes)${NC}\n"
    printf "\033[19;1H${CLEAR_LINE}${CYAN}  3. Installation will finish automatically${NC}\n"
    printf "\033[20;1H${CLEAR_LINE}${GREEN}Press any key when you see 'The software was installed' message...${NC}"
    read -n 1 -s
    
    # Clear the pause notice
    for i in {15..20}; do
      printf "\033[${i};1H${CLEAR_LINE}"
    done
    
    update_status "Xcode Command Line Tools installation completed"
  fi
  
  update_status "Installing Homebrew (this may take 5-10 minutes)..."
  
  # Show Homebrew installation notice
  printf "\033[15;1H${CLEAR_LINE}${YELLOW}📦 Installing Homebrew - this may take 5-10 minutes${NC}\n"
  printf "\033[16;1H${CLEAR_LINE}${CYAN}The script will continue automatically when complete...${NC}\n"
  
  # Try Homebrew installation with timeout and fallback
  if timeout 600 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null 2>&1; then
    # Clear notice area
    printf "\033[15;1H${CLEAR_LINE}\033[16;1H${CLEAR_LINE}"
    update_status "Homebrew installed successfully"
  else
    # Fallback: Manual installation for OpenCore/problematic systems
    printf "\033[15;1H${CLEAR_LINE}\033[16;1H${CLEAR_LINE}"
    update_status "Standard install failed, trying manual installation..."
    
    printf "\033[15;1H${CLEAR_LINE}${YELLOW}⚠️  Standard Homebrew install failed, trying manual method...${NC}\n"
    printf "\033[16;1H${CLEAR_LINE}${CYAN}This may take a few more minutes...${NC}\n"
    
    # Create homebrew directory structure manually
    sudo mkdir -p /opt/homebrew 2>/dev/null || true
    sudo chown -R $(whoami) /opt/homebrew 2>/dev/null || true
    
    # Download and extract Homebrew manually
    cd /tmp
    if curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C /opt/homebrew 2>/dev/null; then
      printf "\033[15;1H${CLEAR_LINE}\033[16;1H${CLEAR_LINE}"
      update_status "Homebrew manual installation successful"
    else
      printf "\033[15;1H${CLEAR_LINE}\033[16;1H${CLEAR_LINE}"
      printf "\033[15;1H${CLEAR_LINE}${RED}❌ Homebrew installation failed completely${NC}\n"
      printf "\033[16;1H${CLEAR_LINE}${YELLOW}You'll need to install Homebrew manually after the script${NC}\n"
      sleep 3
      printf "\033[15;1H${CLEAR_LINE}\033[16;1H${CLEAR_LINE}"
      update_status "Homebrew installation failed - continuing with other components"
      SETUP_SUCCESS=false
    fi
  fi
  
  # Add Homebrew to PATH regardless of installation method
  if [[ $(uname -m) == "arm64" ]]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile 2>/dev/null || true
    eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
  else
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile 2>/dev/null || true
    eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
  fi
  
  # Final verification
  if command_exists brew; then
    update_status "Homebrew setup completed successfully"
  else
    update_status "Homebrew installation issues - some packages may fail"
    SETUP_SUCCESS=false
  fi
else
  update_status "Homebrew already installed - skipping"
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
  echo -e "${CYAN}📄 Setup log saved to: ${LOG_FILE}${NC}"
  echo -e "${CYAN}⚙️  Configuration saved to: ${CONFIG_FILE}${NC}"
  
  # Offer to clean up config
  echo -e "\n${YELLOW}Clean up saved configuration? (y/N):${NC}"
  read -t 5 -r cleanup_response || cleanup_response="n"
  if [[ "$cleanup_response" =~ ^[Yy]$ ]]; then
    rm -f "$CONFIG_FILE" 2>/dev/null || true
    echo -e "${GREEN}✔ Configuration file removed${NC}"
  else
    echo -e "${GREEN}✔ Configuration kept for future runs${NC}"
    echo -e "${CYAN}💡 Run with --reset flag to clear saved config next time${NC}"
  fi
  
  echo -e "\n${CYAN}💻 Rebooting in 10 seconds (Ctrl+C to cancel)...${NC}"
  for i in {10..1}; do
    printf "${CLEAR_LINE}\rRebooting in $i seconds..."
    sleep 1
  done
  
  echo -e "\n${GREEN}🔄 Rebooting...${NC}"
  sudo reboot
else
  echo -e "${YELLOW}⚠️  Setup completed with some errors.${NC}"
  echo -e "${RED}📄 Check the detailed log at: ${LOG_FILE}${NC}"
  echo -e "${CYAN}⚙️  Your configuration is saved at: ${CONFIG_FILE}${NC}"
  echo -e "${GREEN}💡 Re-run the script to retry failed components${NC}"
  
  # Auto-open log
  if command_exists code; then
    code "$LOG_FILE"
  elif command_exists open; then
    open "$LOG_FILE"  
  fi
  
  read -p "Reboot anyway? (y/N): " response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    sudo reboot
  else
    echo -e "${YELLOW}Setup paused. Your progress and config are saved.${NC}"
    echo -e "${CYAN}Run the script again to continue where you left off.${NC}"
  fi
fi\n\t'

LOG_FILE="/tmp/mac_setup.log"
CONFIG_FILE="/tmp/mac_setup_config.sh"
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
# Configuration Management
save_config() {
  cat > "$CONFIG_FILE" << EOF
# Mac Setup Configuration - Generated $(date)
git_username="$git_username"
git_email="$git_email"
ssh_email="$ssh_email"
openai_api_key="$openai_api_key"
claude_api_key="$claude_api_key"
github_token="$github_token"
config_saved="true"
EOF
  chmod 600 "$CONFIG_FILE"  # Secure the config file
}

load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    return 0
  else
    return 1
  fi
}

show_saved_config() {
  printf "\033[15;1H${GREEN}📋 Found previous configuration:${NC}\n"
  printf "\033[16;1H${CYAN}  Git: ${git_username} <${git_email}>${NC}\n"
  printf "\033[17;1H${CYAN}  SSH: ${ssh_email:-"Not set"}${NC}\n"
  printf "\033[18;1H${CYAN}  OpenAI: ${openai_api_key:+***Hidden***}${openai_api_key:-"Not set"}${NC}\n"
  printf "\033[19;1H${CYAN}  Claude: ${claude_api_key:+***Hidden***}${claude_api_key:-"Not set"}${NC}\n"
  printf "\033[20;1H${CYAN}  GitHub: ${github_token:+***Hidden***}${github_token:-"Not set"}${NC}\n"
  printf "\033[21;1H${GREEN}Use this configuration? (Y/n): ${NC}"
}

clear_config_display() {
  for i in {15..22}; do
    printf "\033[${i};1H${CLEAR_LINE}"
  done
}

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
  # Show input line (line 14) and clear any previous content
  printf "\033[14;1H${CLEAR_LINE}${GREEN}${prompt}${NC}"
}

clear_input() {
  # Clear input line and the line above it to remove any residual text
  printf "\033[14;1H${CLEAR_LINE}"
  printf "\033[13;1H\033[K"
  printf "\033[15;1H\033[K"
  printf "\033[16;1H\033[K"
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

# API Keys with validation (secure input)
while true; do
  show_input "OpenAI API key (optional, starts with sk-proj- or sk-): "
  read -s openai_api_key
  clear_input
  # Clear entire screen area where key might have been displayed
  printf "\033[13;1H\033[K\033[14;1H\033[K\033[15;1H\033[K\033[16;1H\033[K"
  
  if validate_api_key "$openai_api_key" "openai"; then
    if [[ -n "$openai_api_key" ]]; then
      printf "\033[14;1H${CLEAR_LINE}${GREEN}✔ OpenAI API key entered (hidden)${NC}"
      sleep 1
      clear_input
    fi
    break
  fi
  clear_input
done

while true; do
  show_input "Claude API key (optional, starts with sk-ant-): "
  read -s claude_api_key
  clear_input
  # Clear entire screen area where key might have been displayed
  printf "\033[13;1H\033[K\033[14;1H\033[K\033[15;1H\033[K\033[16;1H\033[K"
  
  if validate_api_key "$claude_api_key" "claude"; then
    if [[ -n "$claude_api_key" ]]; then
      printf "\033[14;1H${CLEAR_LINE}${GREEN}✔ Claude API key entered (hidden)${NC}"
      sleep 1
      clear_input
    fi
    break
  fi
  clear_input
done

# GitHub Token for Copilot (secure input)
while true; do
  show_input "GitHub token (for Copilot, optional, starts with ghp_): "
  read -s github_token
  clear_input
  # Clear entire screen area where token might have been displayed
  printf "\033[13;1H\033[K\033[14;1H\033[K\033[15;1H\033[K\033[16;1H\033[K"
  
  if validate_api_key "$github_token" "github"; then
    if [[ -n "$github_token" ]]; then
      printf "\033[14;1H${CLEAR_LINE}${GREEN}✔ GitHub token entered (hidden)${NC}"
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
# Homebrew (Enhanced for OpenCore/Sequoia)
if ! command_exists brew; then
  # First, install Xcode Command Line Tools if not present
  if ! xcode-select -p >/dev/null 2>&1; then
    update_status "Checking for Xcode Command Line Tools..."
    
    # Clear progress area and show important notice
    printf "\033[15;1H${CLEAR_LINE}${RED}⚠️  SCRIPT WILL PAUSE - USER ACTION REQUIRED${NC}\n"
    printf "\033[16;1H${CLEAR_LINE}${YELLOW}Xcode Command Line Tools need to be installed (required for Homebrew)${NC}\n"
    printf "\033[17;1H${CLEAR_LINE}${CYAN}This will:${NC}\n"
    printf "\033[18;1H${CLEAR_LINE}${CYAN}  1. Open a dialog asking to install Command Line Tools${NC}\n"
    printf "\033[19;1H${CLEAR_LINE}${CYAN}  2. Download ~500MB (may take 5-15 minutes depending on internet)${NC}\n"
    printf "\033[20;1H${CLEAR_LINE}${CYAN}  3. Install automatically after download${NC}\n"
    printf "\033[21;1H${CLEAR_LINE}${GREEN}Press any key to continue and trigger the installation...${NC}"
    read -n 1 -s
    
    # Clear the notice area
    for i in {15..21}; do
      printf "\033[${i};1H${CLEAR_LINE}"
    done
    
    update_status "Triggering Xcode Command Line Tools installation..."
    xcode-select --install 2>/dev/null || true
    
    # Show pause notice
    printf "\033[15;1H${CLEAR_LINE}${YELLOW}📥 SCRIPT PAUSED - Xcode Command Line Tools installing...${NC}\n"
    printf "\033[16;1H${CLEAR_LINE}${CYAN}Please:${NC}\n"
    printf "\033[17;1H${CLEAR_LINE}${CYAN}  1. Click 'Install' in the popup dialog${NC}\n"
    printf "\033[18;1H${CLEAR_LINE}${CYAN}  2. Wait for download to complete (~5-15 minutes)${NC}\n"
    printf "\033[19;1H${CLEAR_LINE}${CYAN}  3. Installation will finish automatically${NC}\n"
    printf "\033[20;1H${CLEAR_LINE}${GREEN}Press any key when you see 'The software was installed' message...${NC}"
    read -n 1 -s
    
    # Clear the pause notice
    for i in {15..20}; do
      printf "\033[${i};1H${CLEAR_LINE}"
    done
    
    update_status "Xcode Command Line Tools installation completed"
  fi
  
  update_status "Installing Homebrew (this may take 5-10 minutes)..."
  
  # Show Homebrew installation notice
  printf "\033[15;1H${CLEAR_LINE}${YELLOW}📦 Installing Homebrew - this may take 5-10 minutes${NC}\n"
  printf "\033[16;1H${CLEAR_LINE}${CYAN}The script will continue automatically when complete...${NC}\n"
  
  # Try Homebrew installation with timeout and fallback
  if timeout 600 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null 2>&1; then
    # Clear notice area
    printf "\033[15;1H${CLEAR_LINE}\033[16;1H${CLEAR_LINE}"
    update_status "Homebrew installed successfully"
  else
    # Fallback: Manual installation for OpenCore/problematic systems
    printf "\033[15;1H${CLEAR_LINE}\033[16;1H${CLEAR_LINE}"
    update_status "Standard install failed, trying manual installation..."
    
    printf "\033[15;1H${CLEAR_LINE}${YELLOW}⚠️  Standard Homebrew install failed, trying manual method...${NC}\n"
    printf "\033[16;1H${CLEAR_LINE}${CYAN}This may take a few more minutes...${NC}\n"
    
    # Create homebrew directory structure manually
    sudo mkdir -p /opt/homebrew 2>/dev/null || true
    sudo chown -R $(whoami) /opt/homebrew 2>/dev/null || true
    
    # Download and extract Homebrew manually
    cd /tmp
    if curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C /opt/homebrew 2>/dev/null; then
      printf "\033[15;1H${CLEAR_LINE}\033[16;1H${CLEAR_LINE}"
      update_status "Homebrew manual installation successful"
    else
      printf "\033[15;1H${CLEAR_LINE}\033[16;1H${CLEAR_LINE}"
      printf "\033[15;1H${CLEAR_LINE}${RED}❌ Homebrew installation failed completely${NC}\n"
      printf "\033[16;1H${CLEAR_LINE}${YELLOW}You'll need to install Homebrew manually after the script${NC}\n"
      sleep 3
      printf "\033[15;1H${CLEAR_LINE}\033[16;1H${CLEAR_LINE}"
      update_status "Homebrew installation failed - continuing with other components"
      SETUP_SUCCESS=false
    fi
  fi
  
  # Add Homebrew to PATH regardless of installation method
  if [[ $(uname -m) == "arm64" ]]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile 2>/dev/null || true
    eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
  else
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile 2>/dev/null || true
    eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
  fi
  
  # Final verification
  if command_exists brew; then
    update_status "Homebrew setup completed successfully"
  else
    update_status "Homebrew installation issues - some packages may fail"
    SETUP_SUCCESS=false
  fi
else
  update_status "Homebrew already installed - skipping"
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
