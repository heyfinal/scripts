#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

LOG_FILE="/tmp/mac_setup.log"
> "$LOG_FILE"
trap 'warn "⚠️  An error occurred. See $LOG_FILE"; open "$LOG_FILE"' ERR

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
TAN='\033[38;5;180m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

log()        { echo -e "$1" | tee -a "$LOG_FILE"; }
log_color()  { echo -e "${2}$1${NC}" | tee -a "$LOG_FILE"; }
warn()       { log_color "⚠️  $1" "$YELLOW"; }
info()       { log_color "ℹ️  $1" "$CYAN"; }
status()     { [ "$1" -eq 0 ] && log_color "✅ $2" "$GREEN" || { log_color "❌ $2" "$RED"; exit 1; }; }
progress_bar() {
  local current=$1 total=$2 width=40
  local filled=$(( current * width / total ))
  local empty=$(( width - filled ))
  local pct=$(( current * 100 / total ))
  printf "\r["
  printf "%0.s#" $(seq 1 $filled)
  printf "%0.s-" $(seq 1 $empty)
  printf "] %d/%d (%d%%)" $current $total $pct
}
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

tasks=(
  "Update Homebrew"
  "Install Google Chrome"
  "Install iTerm2"
  "Install qBittorrent"
  "Install Gitleaks"
  "Install Trivy"
  "Install zsh-autosuggestions"
  "Install zsh-syntax-highlighting"
  "Install Jackett"
)

main() {
  clear
  tput civis
  tput smcup
  banner
  tput cup 10 0

  if ! pgrep -x "Finder" > /dev/null; then
    warn "⚠️  Not in GUI session. Some GUI installs may hang."
  fi

  setup_brew
  brew doctor >> "$LOG_FILE" 2>&1 || warn "brew doctor reported issues."

  # Dev tools
  for pkg in git curl wget htop ncdu jq tree bat ripgrep fzf python@3.12 go rust openjdk node pipx gh open-cli knock; do
    if ! brew list $pkg &>/dev/null; then
      info "Installing $pkg..."
      brew install $pkg >> "$LOG_FILE" 2>&1
      status $? "$pkg installed"
    else
      info "$pkg already installed — skipping"
    fi
  done

  pipx ensurepath >> "$LOG_FILE" 2>&1

  total=${#tasks[@]}
  i=0
  for task in "${tasks[@]}"; do
    ((i++))
    info "$task..."
    case "$task" in
      "Update Homebrew")
        brew update >> "$LOG_FILE" 2>&1
        ;;
      "Install Google Chrome")
        if ! brew list --cask google-chrome &>/dev/null; then
          brew install --cask google-chrome >> "$LOG_FILE" 2>&1
        else info "Google Chrome already installed — skipping"; fi
        ;;
      "Install iTerm2")
        if ! brew list --cask iterm2 &>/dev/null; then
          brew install --cask iterm2 >> "$LOG_FILE" 2>&1
        else info "iTerm2 already installed — skipping"; fi
        ;;
      "Install qBittorrent")
        if ! brew list --cask qbittorrent &>/dev/null; then
          brew install --cask qbittorrent >> "$LOG_FILE" 2>&1
        else info "qBittorrent already installed — skipping"; fi
        ;;
      "Install Gitleaks")
        if ! brew list gitleaks &>/dev/null; then
          brew install gitleaks >> "$LOG_FILE" 2>&1
        else info "Gitleaks already installed — skipping"; fi
        ;;
      "Install Trivy")
        if ! brew list trivy &>/dev/null; then
          brew install aquasecurity/trivy/trivy >> "$LOG_FILE" 2>&1
        else info "Trivy already installed — skipping"; fi
        ;;
      "Install zsh-autosuggestions")
        if ! brew list zsh-autosuggestions &>/dev/null; then
          brew install zsh-autosuggestions >> "$LOG_FILE" 2>&1
        else info "zsh-autosuggestions already installed — skipping"; fi
        ;;
      "Install zsh-syntax-highlighting")
        if ! brew list zsh-syntax-highlighting &>/dev/null; then
          brew install zsh-syntax-highlighting >> "$LOG_FILE" 2>&1
        else info "zsh-syntax-highlighting already installed — skipping"; fi
        ;;
      "Install Jackett")
        if ! brew list --cask jackett &>/dev/null; then
          brew install --cask jackett >> "$LOG_FILE" 2>&1
          status $? "Jackett installed"
          mkdir -p ~/Library/LaunchAgents
          ln -sf /opt/homebrew/Caskroom/jackett/*/Jackett.app/Contents/MacOS/Jackett ~/Library/LaunchAgents/jackett
          open -a Jackett
        else info "Jackett already installed — skipping"; fi
        ;;
    esac
    status $? "$task completed"
    progress_bar $i $total
  done

  echo "alias openz='open -a textedit'" >> ~/.zshrc
  echo "alias chz='chmod +x'" >> ~/.zshrc
  source ~/.zshrc
  info "✅ Aliases added to .zshrc"

  defaults write -g NSUserDictionaryReplacementItems -array-add '{
    on = 1;
    replace = "openz";
    with = "open -a textedit ";
}' '{
    on = 1;
    replace = "chz";
    with = "chmod +x ";
}'
  info "✅ macOS text replacements set for openz and chz"

  mkdir -p ~/Library/Scripts/MacSetupShortcuts
  cat <<EOT > ~/Library/Scripts/MacSetupShortcuts/LaunchTerminal.scpt
tell application "Terminal"
    activate
end tell
EOT

  cat <<EOT > ~/Library/Scripts/MacSetupShortcuts/LaunchiTerm2.scpt
tell application "iTerm"
    activate
end tell
EOT

  chmod +x ~/Library/Scripts/MacSetupShortcuts/*.scpt
  info "✅ AppleScripts created for Terminal/iTerm2 hotkeys"

  # Theming
  curl -sL -o ~/MacSetup_Kali.itermcolors https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/schemes/Kali.itermcolors
  open ~/MacSetup_Kali.itermcolors
  sleep 2
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

  info "🌐 Launching MacPorts website..."
  open "https://www.macports.org/install.php"

  brew cleanup -s >> "$LOG_FILE" 2>&1
  rm -rf ~/Library/Caches/* >> "$LOG_FILE" 2>&1
  cp "$LOG_FILE" ~/Desktop/mac_setup_summary.log

  tput rmcup
  tput cnorm
  info "✅ Setup complete. Log saved to ~/Desktop/mac_setup_summary.log"
}

main
