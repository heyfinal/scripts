#!/bin/bash
#!/usr/bin/env bash

# Combined macOS setup script:
# - Merges default_tools.sh and setup_mac.sh functionalities
# - Adds extensive system tweaks, personalization, and tool installations

# Continue on errors
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Progress tracking
TOTAL_STEPS=64
CURRENT_STEP=0
FAILED_STEPS=()

# Error handling
handle_error() {
    local step_name="$1"
    local error_msg="$2"
    echo -e "${RED}❌ Error in step: $step_name${NC}"
    echo -e "${RED}   $error_msg${NC}"
    echo -e "${YELLOW}⏭️  Continuing with next step...${NC}\n"
    FAILED_STEPS+=("$step_name")
}

# Progress bar display
progress_bar() {
    local current=$1 total=$2 description="$3"
    local percent=$((current * 100 / total))
    local filled=$((percent * 50 / 100)) empty=$((50 - filled))
    printf "\r${BLUE}[${GREEN}"
    for ((i=0; i<filled; i++)); do printf "█"; done
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "${BLUE}] ${WHITE}%3d%% ${YELLOW}(%d/%d) ${CYAN}%s${NC}" "$percent" "$current" "$total" "$description"
}

# Step wrapper
step() {
    ((CURRENT_STEP++))
    echo -e "\n"
    progress_bar $CURRENT_STEP $TOTAL_STEPS "$1"
    echo -e "\n${WHITE}🚀 Step $CURRENT_STEP/$TOTAL_STEPS: ${GREEN}$1${NC}"
}

# Safe command execution
safe_execute() {
    local name="$1"; shift
    if ! eval "$*"; then
        handle_error "$name" "Command failed: $*"
    fi
}

# Check for command
command_exists() { command -v "$1" &>/dev/null; }

# ASCII Art header
show_final_ascii() {
    echo -e "${CYAN}"
    cat << 'EOF'

▓█████▄▓█████  █████▄▄▄      █    ██ ██▓ ▄▄▄█████▓
▒██▀ ██▓█   ▀▓██   ▒████▄    ██  ▓██▓██▒ ▓  ██▒ ▓▒
░██   █▒███  ▒████ ▒██  ▀█▄ ▓██  ▒██▒██░ ▒ ▓██░ ▒░
░▓█▄   ▒▓█  ▄░▓█▒  ░██▄▄▄▄██▓▓█  ░██▒██░ ░ ▓██▓ ░ 
░▒████▓░▒████░▒█░   ▓█   ▓██▒▒█████▓░██████▒██▒ ░ 
 ▒▒▓  ▒░░ ▒░ ░▒ ░   ▒▒   ▓▒█░▒▓▒ ▒ ▒░ ▒░▓  ▒ ░░   
 ░ ▒  ▒ ░ ░  ░░      ▒   ▒▒ ░░▒░ ░ ░░ ░ ▒  ░ ░    
 ░ ░  ░   ░   ░ ░    ░   ▒   ░░░ ░ ░  ░ ░  ░      
   ░      ░  ░           ░  ░  ░        ░  ░      
 ░                                                
                              
    Ultimate macOS DEFAULT SetuP! By final🐢
EOF
    echo -e "${NC}"
}

main() {
    clear; show_final_ascii
    echo -e "${PURPLE}Starting combined setup...${NC}\n"

    # ========== Default Tools Steps ==========
    step "Checking macOS version"; sw_vers
    step "Installing Xcode Command Line Tools"
    if ! xcode-select -p &>/dev/null; then
        xcode-select --install
        echo "Complete install and press Enter..."; read -r
    fi
    step "Installing Homebrew"
    if ! command_exists brew; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    step "Updating Homebrew"; safe_execute "Homebrew update" brew update
    step "Skipping MacPorts install"
    step "Installing Git and core tools"; safe_execute "Core tools" brew install git pv wget curl nmap
    step "Configuring Git"; git config --global user.name "hey final"; git config --global user.email "dgillapy@me.com"; git config --global init.defaultBranch main
    step "Installing Python 3.13"; safe_execute "Python 3.13" brew install python@3.13
    step "Installing Node.js"; safe_execute "Node.js" brew install node
    step "Installing Java OpenJDK 24"; safe_execute "Java" brew install openjdk@24
    step "Installing GUI Applications"; safe_execute "GUI apps" brew install --cask visual-studio-code iterm2 dropbox
    step "Installing Build Tools"; safe_execute "Build tools" brew install cmake ninja ccache
    step "Installing Network Analysis Tools"; safe_execute "Network tools" brew install tcpdump
    step "Setting up Python environment"
    if command_exists python3.13; then
        safe_execute "pip upgrade" python3.13 -m pip install --upgrade pip
        step "Installing Python packages"; safe_execute "opencv-python" python3.13 -m pip install opencv-python; safe_execute "pyaudio" python3.13 -m pip install pyaudio; safe_execute "numpy" python3.13 -m pip install numpy; safe_execute "esptool" python3.13 -m pip install esptool; safe_execute "virtualenv" python3.13 -m pip install virtualenv
    else
        handle_error "Python env" "python3.13 not found"
    fi
    step "Generating SSH Key (ED25519)"
    if [[ ! -f ~/.ssh/id_ed25519 ]]; then
        ssh-keygen -t ed25519 -C "dgillapy@me.com" -f ~/.ssh/id_ed25519 -N ""; eval "$(ssh-agent -s)"; ssh-add ~/.ssh/id_ed25519
    fi
    step "Enabling macOS Firewall"; safe_execute "Firewall" sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

    step "Setting up shell aliases"
    cat >> ~/.zshrc << 'EOL'
# Turtle-powered aliases
alias ll='ls -la'
alias brewup='brew update && brew upgrade && brew cleanup'
EOL
    step "Setting up environment variables"
    cat >> ~/.zshrc << 'EOL'
export JAVA_HOME=$(/usr/libexec/java_home -v 24)
export PATH="/opt/homebrew/bin/python3.13:$PATH"
EOL
    step "Cleanup Homebrew"; brew cleanup

    # ========== Setup_mac.sh Steps ==========
    step "Configuring TextEdit to plain text"; safe_execute "TextEdit RichText" defaults write com.apple.TextEdit RichText -int 0; safe_execute "TextEdit Dark BG" defaults write com.apple.TextEdit "NSWindow Dark Background" -bool true
    step "Enabling Dark Mode"; safe_execute "Dark Mode" sudo defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
    step "Configuring Dock settings"; safe_execute "Dock tile size" sudo defaults write com.apple.dock tilesize -int 36; safe_execute "Dock magnification" sudo defaults write com.apple.dock magnification -bool true; safe_execute "Dock large size" sudo defaults write com.apple.dock largesize -int 80; safe_execute "Restart Dock" sudo killall Dock
    step "Updating Homebrew (setup_mac)"; safe_execute "brew update" brew update
    step "Installing essential brew tools"; safe_execute "brew install tools" brew install git python3 node go ruby docker kubernetes-cli terraform awscli nmap wireshark john hydra sqlmap metasploit aircrack-ng kismet nikto openvpn tor wget curl vim neovim tmux zsh fzf jq yq htop tree bat exa fd ripgrep tldr ansible vault direnv gh
    step "Verifying installations"; for cmd in git python3 node go ruby docker kubectl terraform aws nmap wireshark john hydra sqlmap msfconsole aircrack-ng kismet nikto openvpn tor wget curl vim nvim tmux zsh fzf jq yq htop tree bat exa fd rg tldr ansible vault direnv gh; do if command_exists "$cmd"; then echo -e "${GREEN}$cmd OK${NC}"; else echo -e "${YELLOW}$cmd missing${NC}"; fi; done
    step "Configuring iTerm2 for Dark Mode"; safe_execute "iTerm2 Dark" defaults write com.googlecode.iterm2 "NSWindow Dark Background" -bool true

main() {
    # ========== Additional User Requests ==========
    step "Configuring Finder list view & sort by Kind"; safe_execute "Finder list view" defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"; safe_execute "Finder arrange by Kind" defaults write com.apple.finder FXArrangeGroupViewBy -string "kind"; safe_execute "Finder preferred group by Kind" defaults write com.apple.finder FXPreferredGroupBy -string "kind"; safe_execute "Restart Finder" killall Finder
    step "Taking ownership of all files & folders"; safe_execute "Take ownership" sudo chown -R "$(whoami):$(id -gn)" /
    step "Setting mouse sensitivity to 8/10"; safe_execute "Mouse sensitivity" defaults write -g com.apple.mouse.scaling -int 8
    step "Show all file extensions & hidden files in Finder"; safe_execute "Show extensions" defaults write NSGlobalDomain AppleShowAllExtensions -bool true; safe_execute "Show hidden files" defaults write com.apple.finder AppleShowAllFiles -bool true; safe_execute "Restart Finder" killall Finder
    step "Customize screenshot location to ~/Screenshots"; safe_execute "Create folder" mkdir -p ~/Screenshots; safe_execute "Set screenshot location" defaults write com.apple.screencapture location ~/Screenshots && killall SystemUIServer
    step "Set screenshot format to JPG"; safe_execute "Screenshot format" defaults write com.apple.screencapture type jpg && killall SystemUIServer
    step "Speed up keyboard repeat & disable press-and-hold"; safe_execute "Key repeat rate" defaults write NSGlobalDomain KeyRepeat -int 1; safe_execute "Disable press-and-hold" defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
    step "Enable tap-to-click & three-finger drag"; safe_execute "Tap-to-click" defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true; safe_execute "Three-finger drag" defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
    step "Disable Notification Center & Do Not Disturb"; safe_execute "Disable NotificationCenter" launchctl unload -w /System/Library/LaunchAgents/com.apple.notificationcenterui.plist; safe_execute "Disable DoNotDisturb" defaults write com.apple.ncprefs dndEnabled -bool true; safe_execute "Restart NotificationCenter" killall NotificationCenter
    step "Set faster Mission Control animations"; safe_execute "Mission Control animations" defaults write com.apple.dock expose-animation-duration -float 0.1 && killall Dock
    step "Turn off 'Are you sure you want to open this app?' dialogs"; safe_execute "Disable quarantine" defaults write com.apple.LaunchServices LSQuarantine -bool false
    step "Enable Firewall stealth mode"; safe_execute "Firewall stealth" sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
    step "Setup global Git ignore"; safe_execute "Create gitignore" bash -c "printf '%s\n' '.DS_Store' 'node_modules/' '__pycache__/' > ~/.gitignore_global"; safe_execute "Set gitignore config" git config --global core.excludesfile ~/.gitignore_global

    # ========== New Suggested Tweaks ==========
    step "Enable automatic system & app updates"; safe_execute "Schedule updates" sudo softwareupdate --schedule on; safe_execute "Homebrew autoupdate" brew tap homebrew/autoupdate; safe_execute "Start brew autoupdate" brew autoupdate start --upgrade --cleanup
    step "Enable FileVault encryption"; safe_execute "FileVault" sudo fdesetup enable -user "$(whoami)"
    step "Disable smart text features"; safe_execute "Disable dashes" defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false; safe_execute "Disable quotes" defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

    # ========== Finalization ==========
    step "Final cleanup"; safe_execute "Brew cleanup" brew cleanup; safe_execute "Brew doctor" brew doctor
    step "Restarting affected services"; safe_execute "Restart Dock" killall Dock; safe_execute "Restart Finder" killall Finder

    # ========== Completion ==========
    echo -e "\n${GREEN}✅ Setup complete!${NC}"
    echo -e "${YELLOW}Total steps executed: $CURRENT_STEP/$TOTAL_STEPS${NC}"
    
    if [ ${#FAILED_STEPS[@]} -ne 0 ]; then
        echo -e "\n${RED}⚠️  The following steps had errors:${NC}"
        for step in "${FAILED_STEPS[@]}"; do
            echo -e "${RED}  - $step${NC}"
        done
    fi
    
    echo -e "\n${CYAN}Please restart your Mac to apply all changes.${NC}"
}

}
main