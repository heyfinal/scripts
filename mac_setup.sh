#!/usr/bin/env bash
LOG_FILE="/tmp/test_mac_setup.log"

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

  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on >> "$LOG_FILE" 2>&1
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on >> "$LOG_FILE" 2>&1

  set_pref com.apple.Safari HomePage "https://github.com/heyfinal"
  set_pref com.apple.LaunchServices LSQuarantine -bool false
} 2>/dev/null

echo "System preferences block executed. Check $LOG_FILE for firewall output."
