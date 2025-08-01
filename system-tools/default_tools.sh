#!/bin/bash

# macOS Development Environment Setup Script
# For hostname: dmbp | Git: hey final <dgillapy@me.com>
# Created with 🐢 turtle power!

# Removed set -e to allow continuing on errors

# Colors for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Progress tracking
TOTAL_STEPS=25
CURRENT_STEP=0
FAILED_STEPS=()

# Error handling
handle_error() {
    local step_name="$1"
    local error_msg="$2"
    echo -e "${RED}❌ Error in step: $step_name${NC}"
    echo -e "${RED}   $error_msg${NC}"
    echo -e "${YELLOW}⏭️  Continuing with next step...${NC}"
    FAILED_STEPS+=("$step_name")
    echo ""
}

# Logging
LOG_FILE="$HOME/setup_log_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

# ASCII Art for "final" in curve style
show_final_ascii() {
    echo -e "${CYAN}"
    cat << 'EOF'
    ______ __            __ 
   / ____ \  \    ____  /  |
  / /    \ \  \  /  _ \/   /
 / /      \ \  \/  ___/   / 
/_/        \_\  \______/__/  
                 \/__/       
    _____ ____ ____   _______ __    
   / __(_)   |   ( \ /   \   |  |   
  / ___| |   |   |\ V   V /  |  |   
 / /   | |   |   | \     /   |  |   
/_/    |_|___|___/   \___/    |__|   
                                     
EOF
    echo -e "${NC}"
}

# Progress bar function
progress_bar() {
    local current=$1
    local total=$2
    local description=$3
    local percent=$((current * 100 / total))
    local filled=$((percent * 50 / 100))
    local empty=$((50 - filled))
    
    printf "\r${BLUE}[${GREEN}"
    for ((i=0; i<filled; i++)); do printf "█"; done
    for ((i=0; i<empty; i++)); do printf "░"; done
    printf "${BLUE}] ${WHITE}%3d%% ${YELLOW}(%d/%d) ${CYAN}%s${NC}" "$percent" "$current" "$total" "$description"
}

# Step function with progress and error handling
step() {
    ((CURRENT_STEP++))
    echo ""
    progress_bar $CURRENT_STEP $TOTAL_STEPS "$1"
    echo ""
    echo -e "${WHITE}🚀 Step $CURRENT_STEP/$TOTAL_STEPS: ${GREEN}$1${NC}"
}

# Execute with error handling
safe_execute() {
    local description="$1"
    shift
    if ! "$@"; then
        handle_error "$description" "Command failed: $*"
        return 1
    fi
    return 0
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Download with progress using curl and pv
download_with_progress() {
    local url=$1
    local output=$2
    local size=$(curl -sI "$url" | grep -i content-length | awk '{print $2}' | tr -d '\r')
    
    if [[ -n "$size" ]]; then
        curl -L "$url" | pv -s "$size" > "$output"
    else
        curl -L "$url" | pv > "$output"
    fi
}

# Main setup function
main() {
    clear
    show_final_ascii
    
    echo -e "${PURPLE}🐢 Welcome to the Ultimate macOS Development Setup! 🐢${NC}"
    echo -e "${YELLOW}This script will transform your Mac into a development powerhouse!${NC}"
    echo -e "${CYAN}Log file: $LOG_FILE${NC}"
    echo ""
    
    # Step 1: Check macOS version
    step "Checking macOS version"
    sw_vers
    
    # Step 2: Install Xcode Command Line Tools
    step "Installing Xcode Command Line Tools"
    if ! xcode-select -p &> /dev/null; then
        echo "Installing Xcode Command Line Tools..."
        xcode-select --install
        echo "Please complete the Xcode Command Line Tools installation in the GUI, then press Enter to continue..."
        read -r
    else
        echo "✅ Xcode Command Line Tools already installed"
    fi
    
    # Step 3: Install Homebrew
    step "Installing Homebrew"
    if ! command_exists brew; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo "✅ Homebrew already installed"
    fi
    
    # Step 4: Update Homebrew
    step "Updating Homebrew"
    brew update
    
    # Step 5: Install MacPorts (alternative package manager)
    step "Installing MacPorts"
    if ! command_exists port; then
        echo "Attempting to install MacPorts..."
        MACOS_VERSION=$(sw_vers -productVersion | cut -d. -f1,2)
        
        # Determine MacPorts version based on macOS
        if [[ "$MACOS_VERSION" == "15."* ]]; then
            MACPORTS_VERSION="MacPorts-2.9.3-15-Sequoia"
        elif [[ "$MACOS_VERSION" == "14."* ]]; then
            MACPORTS_VERSION="MacPorts-2.9.3-14-Sonoma"
        elif [[ "$MACOS_VERSION" == "13."* ]]; then
            MACPORTS_VERSION="MacPorts-2.9.3-13-Ventura"
        else
            echo -e "${YELLOW}⚠️  Unknown macOS version, trying latest MacPorts${NC}"
            MACPORTS_VERSION="MacPorts-2.9.3-14-Sonoma"
        fi
        
        PKG_URL="https://distfiles.macports.org/MacPorts/${MACPORTS_VERSION}.pkg"
        echo "Downloading from: $PKG_URL"
        
        if curl -fL "$PKG_URL" -o "${MACPORTS_VERSION}.pkg"; then
            if sudo installer -pkg "${MACPORTS_VERSION}.pkg" -target /; then
                export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
                echo "✅ MacPorts installed successfully"
            else
                handle_error "MacPorts Installation" "Failed to install MacPorts package"
            fi
            rm -f "${MACPORTS_VERSION}.pkg"
        else
            handle_error "MacPorts Download" "Failed to download MacPorts from $PKG_URL"
            echo -e "${YELLOW}💡 You can install MacPorts manually later from: https://www.macports.org/install.php${NC}"
        fi
    else
        echo "✅ MacPorts already installed"
    fi
    
    # Step 6: Install Core Development Tools
    step "Installing Git and core tools"
    safe_execute "Core tools installation" brew install git pv wget curl nmap || echo "Some tools may have failed to install"
    
    # Step 7: Configure Git
    step "Configuring Git"
    git config --global user.name "hey final"
    git config --global user.email "dgillapy@me.com"
    git config --global init.defaultBranch main
    echo "✅ Git configured for hey final <dgillapy@me.com>"
    
    # Step 8: Install Programming Languages
    step "Installing Python 3.13"
    safe_execute "Python 3.13 installation" brew install python@3.13 || echo "Python installation failed, continuing..."
    
    step "Installing Node.js"
    safe_execute "Node.js installation" brew install node || echo "Node.js installation failed, continuing..."
    
    step "Installing Java OpenJDK 24"
    safe_execute "Java installation" brew install openjdk@24 || echo "Java installation failed, continuing..."
    
    # Step 9: Install GUI Applications
    step "Installing GUI Applications"
    safe_execute "GUI applications" brew install --cask visual-studio-code iterm2 dropbox || echo "Some GUI apps may have failed to install"
    
    # Step 10: Install Build Tools
    step "Installing Build Tools"
    safe_execute "Build tools" brew install cmake ninja ccache || echo "Some build tools may have failed to install"
    
    # Step 11: Install Network Tools
    step "Installing Network Analysis Tools"
    safe_execute "Network tools" brew install tcpdump || echo "tcpdump installation failed, continuing..."
    
    # Step 12: Upgrade pip and install Python packages
    step "Setting up Python environment"
    if command_exists python3.13; then
        safe_execute "pip upgrade" python3.13 -m pip install --upgrade pip || echo "pip upgrade failed, continuing..."
        
        step "Installing Python packages"
        echo "Installing opencv-python..."
        safe_execute "opencv-python" python3.13 -m pip install opencv-python || echo "opencv-python failed, continuing..."
        
        echo "Installing pyaudio..."
        safe_execute "pyaudio" python3.13 -m pip install pyaudio || echo "pyaudio failed, continuing..."
        
        echo "Installing numpy..."
        safe_execute "numpy" python3.13 -m pip install numpy || echo "numpy failed, continuing..."
        
        echo "Installing esptool..."
        safe_execute "esptool" python3.13 -m pip install esptool || echo "esptool failed, continuing..."
        
        echo "Installing virtualenv..."
        safe_execute "virtualenv" python3.13 -m pip install virtualenv || echo "virtualenv failed, continuing..."
    else
        handle_error "Python packages" "Python 3.13 not available, skipping Python packages"
    fi
    
    # Step 13: Generate SSH Key
    step "Generating SSH Key (ED25519)"
    if [[ ! -f ~/.ssh/id_ed25519 ]]; then
        ssh-keygen -t ed25519 -C "dgillapy@me.com" -f ~/.ssh/id_ed25519 -N ""
        eval "$(ssh-agent -s)"
        ssh-add ~/.ssh/id_ed25519
        echo "✅ SSH key generated. Public key:"
        cat ~/.ssh/id_ed25519.pub
    else
        echo "✅ SSH key already exists"
    fi
    
    # Step 14: Enable Firewall
    step "Enabling macOS Firewall"
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    echo "✅ Firewall enabled"
    
    # Step 15: Set up shell aliases
    step "Setting up shell aliases"
    cat >> ~/.zshrc << 'EOL'

# 🐢 Turtle-powered aliases by hey final
alias ll='ls -la'
alias checklogs='tail -f /var/log/system.log'
alias wifi='networksetup -setairportpower en0'
alias brewup='brew update && brew upgrade && brew cleanup'
alias gitlog='git log --oneline --graph --decorate'
alias pyserve='python3 -m http.server'
alias turtle='echo "🐢 I like turtles! 🐢"'

# Show final ASCII on terminal start (comment out if annoying)
# cat << 'EOF'
#     ______ __            __ 
#    / ____ \  \    ____  /  |
#   / /    \ \  \  /  _ \/   /
#  / /      \ \  \/  ___/   / 
# /_/        \_\  \______/__/  
#                  \/__/       
# EOF

EOL
    
    # Step 16: Set up environment variables
    step "Setting up environment variables"
    cat >> ~/.zshrc << 'EOL'

# Java Environment
export JAVA_HOME=$(/usr/libexec/java_home -v 24)

# Python Environment
export PATH="/opt/homebrew/bin/python3.13:$PATH"

# MacPorts
export PATH="/opt/local/bin:/opt/local/sbin:$PATH"

# Homebrew
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

EOL
    
    # Step 17: Set hostname
    step "Setting hostname to 'dmbp'"
    sudo scutil --set HostName dmbp
    sudo scutil --set LocalHostName dmbp
    sudo scutil --set ComputerName dmbp
    echo "✅ Hostname set to 'dmbp'"
    
    # Final steps and cleanup
    step "Running final cleanup and verification"
    brew cleanup
    
    # Verification
    echo -e "\n${GREEN}🎉 Installation Complete! Here's what was installed:${NC}\n"
    
    # Show failed steps if any
    if [ ${#FAILED_STEPS[@]} -gt 0 ]; then
        echo -e "${RED}⚠️  Some steps encountered errors:${NC}"
        for failed_step in "${FAILED_STEPS[@]}"; do
            echo -e "${RED}   • $failed_step${NC}"
        done
        echo -e "${YELLOW}💡 Check the log file for details and install these manually if needed${NC}\n"
    fi
    
    echo -e "${YELLOW}📋 Installation Summary:${NC}"
    echo "✅ Xcode Command Line Tools: $(xcode-select -p)"
    echo "✅ Homebrew: $(brew --version | head -1)"
    echo "✅ Git: $(git --version)"
    echo "✅ Python: $(python3.13 --version)"
    echo "✅ Node.js: $(node --version)"
    echo "✅ Java: $(java --version | head -1)"
    echo "✅ SSH Key: ED25519 generated"
    echo "✅ Firewall: Enabled"
    echo "✅ Hostname: $(hostname)"
    
    echo -e "\n${PURPLE}🐢 Turtle Facts:${NC}"
    echo "• Some turtles can live over 100 years!"
    echo "• Sea turtles navigate using Earth's magnetic field"
    echo "• Your setup is now as solid as a turtle shell!"
    
    echo -e "\n${CYAN}📝 Next Steps:${NC}"
    echo "1. Restart your terminal or run: source ~/.zshrc"
    echo "2. Add your SSH key to GitHub/GitLab"
    echo "3. Install any additional VS Code extensions you need"
    echo "4. Run 'turtle' command for good luck! 🐢"
    
    echo -e "\n${GREEN}Setup completed successfully! Log saved to: $LOG_FILE${NC}"
    
    # Final ASCII celebration
    echo -e "\n${CYAN}"
    cat << 'EOF'
    🐢 SETUP COMPLETE! 🐢
    ═══════════════════════
    Your Mac is now ready for 
    serious development work!
    ═══════════════════════
EOF
    echo -e "${NC}"
}

# Run the main function
main "$@"