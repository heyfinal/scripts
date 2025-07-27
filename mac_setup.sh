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

# Track missing items
missing_items=()

# ————————————————————————————————————————————————————————————————————— #
# Banner
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

echo -e "${CYAN}🔧 Starting macOS setup analysis...${NC}"

# ————————————————————————————————————————————————————————————————————— #
# Helper functions
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

brew_installed() {
    brew list "$1" >/dev/null 2>&1
}

cask_installed() {
    brew list --cask "$1" >/dev/null 2>&1
}

check_item() {
    local name="$1"
    local check_command="$2"
    
    echo -n "  ${name}... "
    if eval "$check_command"; then
        echo -e "${GREEN}✓ Installed${NC}"
    else
        echo -e "${RED}✗ Missing${NC}"
        missing_items+=("$name")
    fi
    return 0  # Always return success to continue script execution
}

# ————————————————————————————————————————————————————————————————————— #
# Check installations
echo -e "\n${CYAN}📋 CHECKING CURRENT INSTALLATIONS:${NC}\n"

echo -e "${YELLOW}🔧 Development Tools:${NC}"
check_item "Xcode Command Line Tools" "xcode-select -p >/dev/null 2>&1"
check_item "Homebrew" "command_exists brew"
check_item "Git" "command_exists git"
check_item "Node.js" "command_exists node"
check_item "Python3" "command_exists python3"

check_item "Docker" "command_exists docker"
check_item "OpenAI CLI" "command_exists openai"

echo -e "\n${YELLOW}🛠 CLI Utilities:${NC}"
check_item "wget" "command_exists wget"
check_item "curl" "command_exists curl"
check_item "htop" "command_exists htop"
check_item "tree" "command_exists tree"
check_item "jq" "command_exists jq"
check_item "fzf" "command_exists fzf"
check_item "ripgrep (rg)" "command_exists rg"
check_item "bat" "command_exists bat"

echo -e "\n${YELLOW}💻 GUI Applications:${NC}"
if command_exists brew; then
    check_item "iTerm2" "cask_installed iterm2"
    check_item "VLC" "cask_installed vlc"
    check_item "The Unarchiver" "cask_installed the-unarchiver"
else
    echo -e "${RED}  Skipping GUI apps check (Homebrew not installed)${NC}"
fi

# ————————————————————————————————————————————————————————————————————— #
# Idempotent Preference Setter
set_pref() {
  local domain=$1
  local key=$2
  local value=$3
  local current
  current=$(defaults read "$domain" "$key" 2>/dev/null || echo "__unset__")
  if [[ "$current" != "$value" ]]; then
    echo -e "${YELLOW}🔁 Setting $domain $key to $value${NC}"
    defaults write "$domain" "$key" "$value"
  else
    echo -e "${GREEN}✔ $domain $key is already $value${NC}"
  fi
}

# ————————————————————————————————————————————————————————————————————— #
# Apply system preferences (your existing code)
echo -e "\n${CYAN}🛠 Checking System Preferences...${NC}"

# Finder: List view and sort by kind
set_pref com.apple.finder FXPreferredViewStyle "Nlsv"
set_pref com.apple.finder FXArrangeGroupViewBy "kind"
set_pref com.apple.finder DesktopViewSettings.IconViewSettings.arrangeBy "kind"

# Mouse and trackpad
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
# Install missing items or show completion message

if [[ ${#missing_items[@]} -eq 0 ]]; then
    echo -e "\n${GREEN}🎉 Script has already busted inside your Mac dumbass${NC}"
    exit 0
fi

echo -e "\n${CYAN}🚀 INSTALLING MISSING ITEMS (${#missing_items[@]} total):${NC}"
for item in "${missing_items[@]}"; do
    echo -e "${YELLOW}  • $item${NC}"
done

echo -e "\n${CYAN}⚡ Starting installations...${NC}\n"

# Install Xcode Command Line Tools
if [[ " ${missing_items[*]} " =~ " Xcode Command Line Tools " ]]; then
    echo -e "${YELLOW}📦 Installing Xcode Command Line Tools...${NC}"
    xcode-select --install || true
fi

# Install Homebrew with bulletproof redundancy
install_homebrew() {
    echo -e "${YELLOW}🍺 Installing Homebrew (bulletproof method)...${NC}"
    
    # Method 1: Official install script
    echo -e "${CYAN}  Attempting official Homebrew installation...${NC}"
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null; then
        echo -e "${GREEN}✓ Official installation successful${NC}"
    else
        echo -e "${RED}✗ Official installation failed, trying alternative method...${NC}"
        
        # Method 2: Manual git clone fallback
        echo -e "${CYAN}  Attempting manual git installation...${NC}"
        if [[ -d "/opt/homebrew" ]] || [[ -d "/usr/local/Homebrew" ]]; then
            echo -e "${YELLOW}  Removing partial installation...${NC}"
            sudo rm -rf /opt/homebrew /usr/local/Homebrew 2>/dev/null || true
        fi
        
        # Determine correct installation path
        if [[ "$(uname -m)" == "arm64" ]]; then
            HOMEBREW_PREFIX="/opt/homebrew"
        else
            HOMEBREW_PREFIX="/usr/local"
        fi
        
        # Create directory and clone
        sudo mkdir -p "$HOMEBREW_PREFIX" 2>/dev/null || true
        sudo chown -R "$(whoami):admin" "$HOMEBREW_PREFIX" 2>/dev/null || true
        
        if git clone https://github.com/Homebrew/brew "$HOMEBREW_PREFIX/Homebrew" 2>/dev/null; then
            # Create symlinks
            mkdir -p "$HOMEBREW_PREFIX/bin" 2>/dev/null || true
            ln -sf "$HOMEBREW_PREFIX/Homebrew/bin/brew" "$HOMEBREW_PREFIX/bin/brew" 2>/dev/null || true
            echo -e "${GREEN}✓ Manual installation successful${NC}"
        else
            echo -e "${RED}✗ Manual installation failed, trying curl fallback...${NC}"
            
            # Method 3: Direct curl with timeout and retries
            for attempt in {1..3}; do
                echo -e "${CYAN}  Curl attempt $attempt/3...${NC}"
                if curl -fsSL --connect-timeout 30 --max-time 300 --retry 3 \
                   https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | \
                   /bin/bash -s -- --unattended </dev/null; then
                    echo -e "${GREEN}✓ Curl installation successful${NC}"
                    break
                elif [[ $attempt -eq 3 ]]; then
                    echo -e "${RED}✗ All Homebrew installation methods failed${NC}"
                    echo -e "${YELLOW}  Please install Homebrew manually from https://brew.sh${NC}"
                    return 1
                fi
                sleep 5
            done
        fi
    fi
    
    # Ensure Homebrew is in PATH
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile 2>/dev/null || true
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile 2>/dev/null || true
    fi
    
    # Verify installation
    if command_exists brew; then
        echo -e "${GREEN}✓ Homebrew successfully installed and configured${NC}"
        brew --version
        return 0
    else
        echo -e "${RED}✗ Homebrew installation verification failed${NC}"
        return 1
    fi
}

# Install Homebrew
if [[ " ${missing_items[*]} " =~ " Homebrew " ]]; then
    install_homebrew || {
        echo -e "${RED}⚠️  Homebrew installation failed. Skipping brew-dependent installations.${NC}"
        exit 1
    }
fi

# Install CLI tools via Homebrew
if command_exists brew; then
    cli_tools=()
    [[ " ${missing_items[*]} " =~ " Git " ]] && cli_tools+=("git")
    [[ " ${missing_items[*]} " =~ " Node.js " ]] && cli_tools+=("node")
    [[ " ${missing_items[*]} " =~ " Python3 " ]] && cli_tools+=("python3")
    [[ " ${missing_items[*]} " =~ " Docker " ]] && cli_tools+=("docker")
    [[ " ${missing_items[*]} " =~ " OpenAI CLI " ]] && cli_tools+=("openai-cli")
    [[ " ${missing_items[*]} " =~ " wget " ]] && cli_tools+=("wget")
    [[ " ${missing_items[*]} " =~ " htop " ]] && cli_tools+=("htop")
    [[ " ${missing_items[*]} " =~ " tree " ]] && cli_tools+=("tree")
    [[ " ${missing_items[*]} " =~ " jq " ]] && cli_tools+=("jq")
    [[ " ${missing_items[*]} " =~ " fzf " ]] && cli_tools+=("fzf")
    [[ " ${missing_items[*]} " =~ " ripgrep (rg) " ]] && cli_tools+=("ripgrep")
    [[ " ${missing_items[*]} " =~ " bat " ]] && cli_tools+=("bat")
    
    if [[ ${#cli_tools[@]} -gt 0 ]]; then
        echo -e "${YELLOW}🔧 Installing CLI tools: ${cli_tools[*]}${NC}"
        brew install "${cli_tools[@]}"
    fi
    
    # Install GUI applications via Homebrew Cask
    cask_apps=()
    [[ " ${missing_items[*]} " =~ " iTerm2 " ]] && cask_apps+=("iterm2")
    [[ " ${missing_items[*]} " =~ " VLC " ]] && cask_apps+=("vlc")
    [[ " ${missing_items[*]} " =~ " The Unarchiver " ]] && cask_apps+=("the-unarchiver")
    
    if [[ ${#cask_apps[@]} -gt 0 ]]; then
        echo -e "${YELLOW}💻 Installing GUI applications: ${cask_apps[*]}${NC}"
        brew install --cask "${cask_apps[@]}"
    fi
    
    # Set up OpenAI CLI global command if it was installed
    if [[ " ${missing_items[*]} " =~ " OpenAI CLI " ]] && command_exists openai; then
        echo -e "${YELLOW}🔧 Setting up OpenAI CLI global command...${NC}"
        # Create symlink for global 'openai' command (similar to claude-code)
        if [[ ! -L /usr/local/bin/openai ]]; then
            sudo ln -sf "$(which openai)" /usr/local/bin/openai 2>/dev/null || true
        fi
        echo -e "${GREEN}✓ OpenAI CLI available globally as 'openai'${NC}"
    fi
fi

# Restart Finder to apply changes
killall Finder || true

echo -e "\n${GREEN}🎉 macOS setup completed! All missing items have been installed.${NC}"
