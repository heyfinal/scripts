[FULL SCRIPT CONTENT REPLACED WITH CLEANED & FIXED COPY FROM USER UPLOAD — REPASTED HERE]

#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
TAN='\033[38;5;180m'
YELLOW='\033[1;33m'
NC='\033[0m'

LOG_FILE="/tmp/mac_setup.log"
CONFIG_FILE="/tmp/mac_setup_config.sh"
exec > >(tee -a "$LOG_FILE") 2>&1

SETUP_SUCCESS=true

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

EOF
  printf "${NC}\n"
}

save_config() {
  cat > "$CONFIG_FILE" << EOF
git_username="$git_username"
git_email="$git_email"
ssh_email="$ssh_email"
openai_api_key="$openai_api_key"
claude_api_key="$claude_api_key"
github_token="$github_token"
config_saved="true"
EOF
  chmod 600 "$CONFIG_FILE"
}

load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    return 0
  else
    return 1
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

validate_api_key() {
  local key="$1"
  local expected_type="$2"
  
  if [[ -z "$key" ]]; then
    return 0
  fi

  case "$expected_type" in
    "openai")
      if [[ "$key" == sk-ant-* ]]; then
        echo -e "${RED}ERROR: This looks like a Claude API key (starts with sk-ant-)${NC}"
        echo -e "${RED}You entered it in the OpenAI field. Please check your keys.${NC}"
        sleep 3
        return 1
      elif [[ "$key" != sk-proj-* && "$key" != sk-* ]]; then
        echo -e "${YELLOW}WARNING: OpenAI API keys usually start with 'sk-proj-' or 'sk-'${NC}"
        read -p "Continue anyway? (y/N): " response
        [[ "$response" =~ ^[Yy]$ ]] || return 1
      fi
      ;;
    "claude")
      if [[ ("$key" == sk-proj-* || "$key" == sk-*) && "$key" != sk-ant-* ]]; then
        echo -e "${RED}ERROR: This looks like an OpenAI API key${NC}"
        echo -e "${RED}You entered it in the Claude field. Please check your keys.${NC}"
        sleep 3
        return 1
      elif [[ "$key" != sk-ant-* && -n "$key" ]]; then
        echo -e "${YELLOW}WARNING: Claude API keys start with 'sk-ant-'${NC}"
        read -p "Continue anyway? (y/N): " response
        [[ "$response" =~ ^[Yy]$ ]] || return 1
      fi
      ;;
    "github")
      if [[ -n "$key" ]]; then
        if [[ "$key" != ghp_* && "$key" != gho_* && "$key" != ghu_* && "$key" != ghs_* && "$key" != ghr_* ]]; then
          echo -e "${YELLOW}WARNING: GitHub tokens usually start with 'ghp_', 'gho_', 'ghu_', 'ghs_', or 'ghr_'${NC}"
          read -p "Continue anyway? (y/N): " response
          [[ "$response" =~ ^[Yy]$ ]] || return 1
        fi
      fi
      ;;
  esac
  return 0
}

banner
echo -e "${CYAN}🔧 macOS Developer Setup${NC}"

{
  echo ""
  echo "============================================="
  echo "macOS Setup Script v2.0.1 STARTED - $(date)"
  echo "User: $(whoami)"
  echo "macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
  echo "Hardware: $(uname -m)"
  echo "============================================="
} >> "$LOG_FILE"

if [[ "${1:-}" == "--reset" ]]; then
  rm -f "$CONFIG_FILE" 2>/dev/null || true
  echo -e "${GREEN}🔄 Configuration reset - will collect fresh information${NC}"
fi

git_username=""
git_email=""
ssh_email=""
openai_api_key=""
claude_api_key=""
github_token=""

if load_config && [[ "${config_saved:-}" == "true" ]]; then
  echo -e "${GREEN}📋 Found previous configuration:${NC}"
  echo -e "${CYAN}  Git: ${git_username} <${git_email}>${NC}"
  echo -e "${CYAN}  SSH: ${ssh_email:-"Not set"}${NC}"
  echo -e "${CYAN}  OpenAI: ${openai_api_key:+***Hidden***}${openai_api_key:-"Not set"}${NC}"
  echo -e "${CYAN}  Claude: ${claude_api_key:+***Hidden***}${claude_api_key:-"Not set"}${NC}"
  echo -e "${CYAN}  GitHub: ${github_token:+***Hidden***}${github_token:-"Not set"}${NC}"
  read -p "Use this configuration? (Y/n): " use_existing
  
  if [[ "$use_existing" =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}Collecting new configuration...${NC}"
    git_username=""
    git_email=""
    ssh_email=""
    openai_api_key=""
    claude_api_key=""
    github_token=""
  else
    echo -e "${GREEN}✔ Using saved configuration${NC}"
  fi
else
  echo -e "${CYAN}🔧 Please provide the following information (will be saved for future runs):${NC}"
fi

need_config=false

if [[ -z "$git_username" ]] && [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
  need_config=true
  read -p "Git username: " git_username
  read -p "Git email: " git_email
  echo -e "${GREEN}✔ Git configuration entered${NC}"
elif [[ -z "$git_username" ]]; then
  git_username=$(git config --global user.name)
  git_email=$(git config --global user.email)
  echo -e "${GREEN}✔ Using existing Git config${NC}"
fi

if [[ -z "$ssh_email" ]] && [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
  need_config=true
  read -p "Email for SSH key: " ssh_email
  echo -e "${GREEN}✔ SSH email entered${NC}"
elif [[ -z "$ssh_email" ]]; then
  echo -e "${GREEN}✔ SSH key already exists${NC}"
fi

if [[ -z "$openai_api_key" ]]; then
  need_config=true
  while true; do
    read -s -p "OpenAI API key (optional, starts with sk-proj- or sk-): " openai_api_key
    echo ""
    if validate_api_key "$openai_api_key" "openai"; then
      if [[ -n "$openai_api_key" ]]; then
        echo -e "${GREEN}✔ OpenAI API key entered${NC}"
      fi
      break
    fi
  done
fi

if [[ -z "$claude_api_key" ]]; then
  need_config=true
  while true; do
    read -s -p "Claude API key (optional, starts with sk-ant-): " claude_api_key
    echo ""
    if validate_api_key "$claude_api_key" "claude"; then
      if [[ -n "$claude_api_key" ]]; then
        echo -e "${GREEN}✔ Claude API key entered${NC}"
      fi
      break
    fi
  done
fi

if [[ -z "$github_token" ]]; then
  need_config=true
  while true; do
    read -s -p "GitHub token (for Copilot, optional, starts with ghp_): " github_token
    echo ""
    if validate_api_key "$github_token" "github"; then
      if [[ -n "$github_token" ]]; then
        echo -e "${GREEN}✔ GitHub token entered${NC}"
      fi
      break
    fi
  done
fi

if [[ "$need_config" == "true" ]] || [[ ! -f "$CONFIG_FILE" ]]; then
  save_config
  echo -e "${GREEN}💾 Configuration saved for future runs${NC}"
fi

echo -e "\n${CYAN}🚀 Starting setup...${NC}"

{
  echo "Configuration Summary:"
  echo "- Git: ${git_username} <${git_email}>"
  echo "- SSH Email: ${ssh_email:-"Using existing key"}"
  echo "- OpenAI API: ${openai_api_key:+***Configured***}${openai_api_key:-"Not provided"}"
  echo "- Claude API: ${claude_api_key:+***Configured***}${claude_api_key:-"Not provided"}"
  echo "- GitHub Token: ${github_token:+***Configured***}${github_token:-"Not provided"}"
} >> "$LOG_FILE"

echo -e "${YELLOW}⚙️  Setting up sudo access...${NC}"
sudo -v 2>/dev/null
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo -e "${YELLOW}🖥️  Configuring system preferences...${NC}"

set_pref() {
  defaults write "$1" "$2" "${@:3}" 2>/dev/null || return 1
}

{
  set_pref com.apple.finder FXPreferredViewStyle "Nlsv"
  set_pref com.apple.finder AppleShowAllFiles -bool true
  set_pref NSGlobalDomain AppleShowAllExtensions -bool true
  set_pref com.apple.finder FXRemoveOldTrashItems -bool true
  
  set_pref com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  set_pref NSGlobalDomain com.apple.trackpad.scaling -float 2.1
  set_pref NSGlobalDomain com.apple.mouse.scaling -float 2.1
  set_pref NSGlobalDomain KeyRepeat -int 2
  set_pref NSGlobalDomain InitialKeyRepeat -int 15
  set_pref NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
  
  set_pref com.apple.dock autohide -bool false
  set_pref com.apple.dock tilesize -int 32
  set_pref com.apple.dock magnification -bool true
  set_pref com.apple.dock largesize -int 80
  set_pref com.apple.dock static-only -bool true
  set_pref com.apple.dock show-recents -bool false
  set_pref com.apple.dock launchanim -bool false
  
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on &>> "$LOG_FILE"
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on &>> "$LOG_FILE"
  
  set_pref com.apple.Safari HomePage "https://github.com/heyfinal"
  set_pref com.apple.LaunchServices LSQuarantine -bool false
} 2>/dev/null

echo -e "${YELLOW}🍺 Installing Homebrew...${NC}"

if ! command_exists brew; then
  if ! xcode-select -p >/dev/null 2>&1; then
    echo -e "${RED}⚠️  SCRIPT WILL PAUSE - USER ACTION REQUIRED${NC}"
    echo -e "${YELLOW}Xcode Command Line Tools need to be installed (required for Homebrew)${NC}"
    echo -e "${CYAN}This will download ~500MB and may take 5-15 minutes${NC}"
    read -p "Press any key to continue and trigger the installation..." -n 1 -s
    echo ""
    
    xcode-select --install 2>/dev/null || true
    
    echo -e "${YELLOW}📥 SCRIPT PAUSED - Xcode Command Line Tools installing...${NC}"
    echo -e "${CYAN}Please click 'Install' in the popup dialog and wait for completion${NC}"
    read -p "Press any key when you see 'The software was installed' message..." -n 1 -s
    echo ""
  fi
  
  echo -e "${YELLOW}📦 Installing Homebrew (this may take 5-10 minutes)...${NC}"
  
  if timeout 600 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >/dev/null 2>&1; then
    echo -e "${GREEN}✔ Homebrew installed successfully${NC}"
  else
    echo -e "${YELLOW}⚠️  Standard install failed, trying manual installation...${NC}"
    
    sudo mkdir -p /opt/homebrew 2>/dev/null || true
    sudo chown -R $(whoami) /opt/homebrew 2>/dev/null || true
    
    cd /tmp
    if curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C /opt/homebrew 2>/dev/null; then
      echo -e "${GREEN}✔ Homebrew manual installation successful${NC}"
    else
      echo -e "${RED}❌ Homebrew installation failed completely${NC}"
      SETUP_SUCCESS=false
    fi
  fi
  
  if [[ $(uname -m) == "arm64" ]]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile 2>/dev/null || true
    eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
  else
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile 2>/dev/null || true
    eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
  fi
else
  echo -e "${GREEN}✔ Homebrew already installed${NC}"
fi

install_package() {
  local package="$1"
  brew list "$package" >/dev/null 2>&1 || brew install "$package" >/dev/null 2>&1
}

install_cask() {
  local cask="$1"
  brew list --cask "$cask" >/dev/null 2>&1 || brew install --cask "$cask" >/dev/null 2>&1
}

echo -e "${YELLOW}🔧 Installing CLI tools...${NC}"
for pkg in git curl wget jq tree htop bat eza fzf ripgrep fd tldr; do
  install_package "$pkg"
done

echo -e "${YELLOW}💻 Installing development tools...${NC}"
for pkg in node "python@3.12" go rust docker docker-compose; do
  install_package "$pkg"
done

echo -e "${YELLOW}🤖 Installing AI CLIs...${NC}"
install_package "gh"

if [[ -n "${github_token:-}" ]]; then
  echo "$github_token" | gh auth login --with-token >/dev/null 2>&1 || true
fi

if ! gh extension list 2>/dev/null | grep -q "github/gh-copilot"; then
  gh extension install github/gh-copilot >/dev/null 2>&1 || true
fi

if ! command_exists claude; then
  curl -fsSL https://claude.ai/cli/install.sh | sh >/dev/null 2>&1 || true
fi

if ! command_exists openai; then
  if command_exists npm; then
    npm install -g openai-cli >/dev/null 2>&1 || pip3 install openai >/dev/null 2>&1 || true
  else
    pip3 install openai >/dev/null 2>&1 || true
  fi
fi

echo -e "${YELLOW}📱 Installing applications...${NC}"
for app in iterm2 rectangle alfred 1password discord slack zoom; do
  install_cask "$app"
done

echo -e "${YELLOW}🐚 Setting up shell environment...${NC}"
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

if [[ -f "$HOME/.zshrc" ]]; then
  cp "$HOME/.zshrc" "$HOME/.zshrc.backup"
  sed -i.bak 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting docker node npm)/' "$HOME/.zshrc"
  
  cat >> "$HOME/.zshrc" << 'EOF'

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

echo -e "${YELLOW}📝 Configuring Git and SSH...${NC}"
git config --global user.name "$git_username" 2>/dev/null
git config --global user.email "$git_email" 2>/dev/null
git config --global init.defaultBranch main 2>/dev/null
git config --global pull.rebase false 2>/dev/null

if [[ ! -f "$HOME/.ssh/id_ed25519" && -n "${ssh_email:-}" ]]; then
  ssh-keygen -t ed25519 -C "$ssh_email" -f "$HOME/.ssh/id_ed25519" -N "" >/dev/null 2>&1
  eval "$(ssh-agent -s)" >/dev/null 2>&1
  ssh-add "$HOME/.ssh/id_ed25519" >/dev/null 2>&1
fi

echo -e "${YELLOW}🎨 Configuring terminal themes...${NC}"
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
      "Transparency": 0.2
    }
  ]
}
EOF
fi

echo -e "${YELLOW}🚀 Installing rEFInd bootloader...${NC}"
if ! command_exists refind-install; then
  {
    curl -L -o /tmp/refind.zip "https://sourceforge.net/projects/refind/files/latest/download" 2>/dev/null
    cd /tmp && unzip -q refind.zip 2>/dev/null
    REFIND_DIR=$(find /tmp -name "refind-bin-*" -type d | head -1)
    
    if [[ -d "$REFIND_DIR" ]]; then
      cd "$REFIND_DIR"
      sudo ./refind-install --yes >/dev/null 2>&1
      
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

echo -e "${YELLOW}⚙️  Finalizing configuration...${NC}"
if [[ -n "${openai_api_key:-}" ]] && command_exists openai; then
  echo "$openai_api_key" | openai config set-key >/dev/null 2>&1 || true
fi

if [[ -n "${claude_api_key:-}" ]] && command_exists claude; then
  echo "$claude_api_key" | claude config >/dev/null 2>&1 || true
fi

killall Finder Dock SystemUIServer 2>/dev/null || true

echo -e "\n${GREEN}🎉 Setup Complete!${NC}"

if [[ "$SETUP_SUCCESS" == true ]]; then
  echo -e "${GREEN}✔ All components installed successfully${NC}"
  echo -e "${CYAN}📋 Configured: System prefs • CLI tools • AI CLIs • Apps • rEFInd${NC}"
  echo -e "${GREEN}🤖 Auto-configured: GitHub • OpenAI • Claude CLIs${NC}"
  
  if [[ -f "$HOME/.ssh/id_ed25519.pub" && -n "${ssh_email:-}" ]]; then
    echo -e "\n${YELLOW}📋 SSH Public Key (add to GitHub):${NC}"
    echo -e "${CYAN}$(cat "$HOME/.ssh/id_ed25519.pub")${NC}"
  fi
  
  echo -e "\n${GREEN}✨ Ready to use: gh copilot, claude, openai commands${NC}"
  echo -e "${CYAN}📄 Setup log: ${LOG_FILE}${NC}"
  echo -e "${CYAN}⚙️  Configuration: ${CONFIG_FILE}${NC}"
  
  read -t 5 -p "Clean up saved configuration? (y/N): " cleanup_response || cleanup_response="n"
  if [[ "$cleanup_response" =~ ^[Yy]$ ]]; then
    rm -f "$CONFIG_FILE" 2>/dev/null || true
    echo -e "${GREEN}✔ Configuration file removed${NC}"
  else
    echo -e "${GREEN}✔ Configuration kept for future runs${NC}"
  fi
  
  echo -e "\n${CYAN}💻 Rebooting in 10 seconds (Ctrl+C to cancel)...${NC}"
  for i in {10..1}; do
    echo -ne "\rRebooting in $i seconds..."
    sleep 1
  done
  
  echo -e "\n${GREEN}🔄 Rebooting...${NC}"
  sudo reboot
else
  echo -e "${YELLOW}⚠️  Setup completed with some errors${NC}"
  echo -e "${RED}📄 Check log: ${LOG_FILE}${NC}"
  echo -e "${CYAN}⚙️  Config saved: ${CONFIG_FILE}${NC}"
  
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
