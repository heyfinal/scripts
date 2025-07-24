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
  ,M""bMM  .gP"Ya  mMMmm ,6"Yb.`7MM  `7MM    MM mmMMmm  
,AP    MM ,M'   Yb  MM  8)   MM  MM    MM    MM   MM    
8MI    MM 8M""""""  MM   ,pm9MM  MM    MM    MM   MM    
`Mb    MM YM.    ,  MM  8M   MM  MM    MM    MM   MM    
 `Wbmd"MML.`Mbmmd'.JMML.`Moo9^Yo.`Mbod"YML..JMML. `Mbmo 

EOF
  printf "${NC}\n"
}

banner

echo -e "${CYAN}🔧 Starting macOS setup...${NC}"

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
# Preferences Section

echo -e "\n${CYAN}🛠 Applying Finder, Mouse, and System Preferences...${NC}"

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

# Restart Finder to apply changes
killall Finder || true

echo -e "${GREEN}🎉 macOS setup completed.${NC}"
