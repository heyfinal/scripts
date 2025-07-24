#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

LOG_FILE="/tmp/mac_setup.log"
> "$LOG_FILE"
trap 'warn "⚠️  An error occurred. See $LOG_FILE"; open "$LOG_FILE"' ERR

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
  # Render ASCII art in tan
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
                          gen dev installs & pref - by final                      
EOF
  # Reset color
  printf "${NC}\n"
}

# ————————————————————————————————————————————————————————————————————— #
# Logging & Helpers
log()        { echo -e "$1" | tee -a "$LOG_FILE"; }
log_color()  { echo -e "${2}$1${NC}" | tee -a "$LOG_FILE"; }
warn()       { log_color "⚠️  $1" "$YELLOW"; }
info()       { log_color "ℹ️  $1" "$CYAN"; }

# Check status and exit on failure
status() {
  if [ "$1" -eq 0 ]; then
    log_color "✅ $2" "$GREEN"
  else
    log_color "❌ $2" "$RED"
    exit 1
  fi
}

# Progress bar
progress_bar() {
  local current=$1 total=$2 width=40 filled empty pct
  filled=$(( current * width / total ))
  empty=$(( width - filled ))
  pct=$(( current * 100 / total ))
  printf "\r["
  printf "%0.s#" $(seq 1 $filled)
  printf "%0.s-" $(seq 1 $empty)
  printf "] %d/%d (%d%%)" $current $total $pct
}

# Detect architecture & ensure brew in PATH
get_brew_path() { [[ "$(uname -m)" == "arm64" ]] && echo "/opt/homebrew/bin/brew" || echo "/usr/local/bin/brew"; }
setup_brew() {
  local bp
  bp=$(get_brew_path)
  if [[ ! -x "$bp" ]]; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >> "$LOG_FILE" 2>&1
    status $? "Homebrew installed"
  else
    info "Homebrew found at $bp"
  fi
  eval "$("$bp" shellenv)"
}

# Tasks list
tasks=(
  "Update Homebrew"
  "Install Ranger"
  "Install chkrootkit"
  "Install VLC"
  "Install qBittorrent"
  "Install Gitleaks"
  "Install Trivy"
  "Install zsh-autosuggestions"
  "Install zsh-syntax-highlighting",
  "Install Jackett"
)

# Main execution
main() {
  clear
  tput civis
  tput smcup
  banner
  tput cup 10 0
  setup_brew

  total=${#tasks[@]}
  i=0
  for task in "${tasks[@]}"; do
    ((i++))
    info "$task..."
    case "$task" in
      "Update Homebrew")
        brew update >> "$LOG_FILE" 2>&1
        ;;
      "Install Ranger")
        if ! brew list ranger &>/dev/null; then
  info "Installing ranger..."
  brew install ranger >> "$LOG_FILE" 2>&1
  status $? "ranger installed"
else
  info "ranger already installed — skipping"
fi
        ;;
      "Install chkrootkit")
        if ! brew list chkrootkit &>/dev/null; then
  info "Installing chkrootkit..."
  brew install chkrootkit >> "$LOG_FILE" 2>&1
  status $? "chkrootkit installed"
else
  info "chkrootkit already installed — skipping"
fi
        ;;
      "Install VLC")
        if ! brew list --cask vlc &>/dev/null; then
  info "Installing vlc..."
  brew install --cask vlc >> "$LOG_FILE" 2>&1
  status $? "vlc installed"
else
  info "vlc already installed — skipping"
fi
        ;;
      "Install qBittorrent")
        if ! brew list --cask qbittorrent &>/dev/null; then
  info "Installing qbittorrent..."
  brew install --cask qbittorrent >> "$LOG_FILE" 2>&1
  status $? "qbittorrent installed"
else
  info "qbittorrent already installed — skipping"
fi
        ;;
      "Install Gitleaks")
        if ! brew list gitleaks &>/dev/null; then
  info "Installing gitleaks..."
  brew install gitleaks >> "$LOG_FILE" 2>&1
  status $? "gitleaks installed"
else
  info "gitleaks already installed — skipping"
fi
        ;;
      "Install Trivy")
        if ! brew list aquasecurity/trivy/trivy &>/dev/null; then
  info "Installing aquasecurity/trivy/trivy..."
  brew install aquasecurity/trivy/trivy >> "$LOG_FILE" 2>&1
  status $? "aquasecurity/trivy/trivy installed"
else
  info "aquasecurity/trivy/trivy already installed — skipping"
fi
        ;;
      "Install zsh-autosuggestions")
        if ! brew list zsh-autosuggestions &>/dev/null; then
  info "Installing zsh-autosuggestions..."
  brew install zsh-autosuggestions >> "$LOG_FILE" 2>&1
  status $? "zsh-autosuggestions installed"
else
  info "zsh-autosuggestions already installed — skipping"
fi
        ;;
      "Install zsh-syntax-highlighting")
        if ! brew list zsh-syntax-highlighting &>/dev/null; then
  info "Installing zsh-syntax-highlighting..."
  brew install zsh-syntax-highlighting >> "$LOG_FILE" 2>&1
  status $? "zsh-syntax-highlighting installed"
else
  info "zsh-syntax-highlighting already installed — skipping"
fi
        ;;
      "Install Jackett")
        if ! brew list --cask jackett &>/dev/null; then
  info "Installing jackett..."
  brew install --cask jackett >> "$LOG_FILE" 2>&1
  status $? "jackett installed"
else
  info "jackett already installed — skipping"
fi
        status $? "Jackett installed"
        info "Setting Jackett to launch at login..."
        mkdir -p ~/Library/LaunchAgents
        ln -sf /opt/homebrew/Caskroom/jackett/*/Jackett.app/Contents/MacOS/Jackett ~/Library/LaunchAgents/jackett
        open -a Jackett
        status $? "Jackett launched"
        info "Jackett runs at: http://127.0.0.1:9117"
        ;;
    esac
    status $? "$task completed"
    progress_bar $i $total
  done

  printf "\n"
  
  info "Cleaning up system..."
  brew cleanup -s >> "$LOG_FILE" 2>&1
  rm -rf ~/Library/Caches/* >> "$LOG_FILE" 2>&1
  status $? "System cleanup complete"

  info "📝 Setup complete. Log file saved at $LOG_FILE"
  cp "$LOG_FILE" ~/Desktop/mac_setup_summary.log
  info "🧾 Summary copied to Desktop as mac_setup_summary.log"
  info "🔧 Configuring browser download settings..."

  # Set Safari to ask where to save each download
  defaults write com.apple.Safari AskEveryTime -bool true

  # Set Chrome to ask where to save each download
  /usr/bin/defaults write com.google.Chrome PromptForDownloadLocation -bool true

  
info "🎨 Applying Terminal & iTerm2 theme..."

# Terminal.app - Create profile with black background and semi-transparency
osascript <<EOF
tell application "Terminal"
    set newProfile to (make new settings set with properties {name:"MacSetupBlack"})
    set background color of newProfile to {0, 0, 0}
    set text color of newProfile to {65535, 65535, 65535}
    set font size of newProfile to 14
    set transparency of newProfile to 0.3
    set default settings to newProfile
    set current settings of front window to newProfile
end tell
EOF

# iTerm2 - Import and apply Kali theme
curl -sL -o ~/MacSetup_Kali.itermcolors https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/schemes/Kali.itermcolors
open ~/MacSetup_Kali.itermcolors
sleep 2

osascript <<EOF
tell application "iTerm"
    repeat with aProfile in profiles
        if name of aProfile is "Kali" then
            set default profile to "Kali"
            exit repeat
        end if
    end repeat
end tell
EOF

info "✅ Terminal and iTerm2 appearance configured."

# Terminal.app - Create profile with black background and semi-transparency
osascript <<EOF
tell application "Terminal"
    set newProfile to (make new settings set with properties {name:"MacSetupBlack"})
    set background color of newProfile to {0, 0, 0}
    set text color of newProfile to {65535, 65535, 65535}
    set font size of newProfile to 14
    set transparency of newProfile to 0.3
    set default settings to newProfile
    set current settings of front window to newProfile
end tell
EOF

# iTerm2 - Import and apply Kali-style dark theme
curl -sL -o ~/MacSetup_Kali.itermcolors https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/schemes/Kali.itermcolors
open ~/MacSetup_Kali.itermcolors
sleep 2
osascript <<EOF
tell application "iTerm2"
    tell current window
        set current session's profile name to "Kali"
    end tell
end tell
EOF

info "✅ Terminal and iTerm2 appearance configured."


  info "🌐 Launching MacPorts website..."
  tput rmcup
  tput cnorm
  open "https://www.macports.org/install.php" >> "$LOG_FILE" 2>&1 || warn "Unable to open MacPorts site"

}

main
