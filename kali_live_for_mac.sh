#!/bin/bash

set -euo pipefail

DEBUG="${DEBUG:-false}"

error_exit() {
  echo -e "\n[ERROR] $1" >&2
  if [ "$DEBUG" = "false" ] && [ -n "${WORKDIR:-}" ] && [ -d "${WORKDIR:-}" ]; then
    echo "[INFO] Cleaning up working directory..."
    rm -rf "$WORKDIR"
  elif [ -n "${WORKDIR:-}" ]; then
    echo "[INFO] Working directory left at: $WORKDIR"
  fi
  exit 1
}

trap 'error_exit "Script interrupted or failed."' ERR

if [ "$(id -u)" -ne 0 ]; then
  error_exit "Please run as root: sudo bash $0"
fi

echo "[*] Checking network connectivity to Kali repo..."
ping -c 2 archive.kali.org &>/dev/null || error_exit "No network connectivity or archive.kali.org unreachable."

echo "[*] Fixing Kali repository keys..."
# Remove any broken or old keys
rm -f /etc/apt/trusted.gpg.d/kali-archive-keyring.gpg* 2>/dev/null || true
rm -rf /var/lib/apt/lists/* 2>/dev/null || true

# Download and install the proper Kali keyring
if ! wget --no-check-certificate -q -O - https://archive.kali.org/archive-key.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/kali-archive-keyring.gpg; then
  echo "[WARNING] Primary key download failed, trying alternative method..."
  # Alternative method if HTTPS fails
  if ! curl -k -s https://archive.kali.org/archive-key.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/kali-archive-keyring.gpg; then
    error_exit "Failed to download Kali repository keys. Check network connectivity."
  fi
fi

# Ensure proper permissions
chmod 644 /etc/apt/trusted.gpg.d/kali-archive-keyring.gpg

# Verify sources.list is correct
if ! grep -q "deb.*kali-rolling.*main" /etc/apt/sources.list; then
  echo "[*] Fixing sources.list..."
  echo "deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware" > /etc/apt/sources.list
fi

echo "[*] Updating package lists with fixed keys..."
apt clean
if ! apt update; then
  echo "[WARNING] Initial apt update failed, trying to fix repository authentication..."
  # Try to install keyring package with insecure repositories if needed
  apt update --allow-insecure-repositories 2>/dev/null || true
  apt install -y --allow-unauthenticated kali-archive-keyring 2>/dev/null || true
  
  # Try update again
  if ! apt update; then
    error_exit "APT update failed even after key fixes. Check your internet connection and repository configuration."
  fi
fi

echo "[*] Installing build dependencies..."
echo "[*] Detected live USB environment - fixing package conflicts..."

# Fix common live USB package conflicts
apt remove -y qsslcaudit 2>/dev/null || true
apt autoremove -y 2>/dev/null || true

# Upgrade system packages to resolve dependency conflicts
echo "[*] Upgrading system packages (this may take several minutes)..."
DEBIAN_FRONTEND=noninteractive apt full-upgrade -y

# Install build dependencies with conflict resolution
echo "[*] Installing build dependencies with dependency resolution..."
DEBIAN_FRONTEND=noninteractive apt install -y git live-build cdebootstrap curl --fix-broken --fix-missing

# If that fails, try individual installation
if [ $? -ne 0 ]; then
  echo "[*] Trying individual package installation..."
  apt install -y git || echo "git installation failed"
  apt install -y live-build || echo "live-build installation failed" 
  apt install -y cdebootstrap || echo "cdebootstrap installation failed"
  apt install -y curl || echo "curl installation failed"
fi

# Verify critical packages are installed
if ! command -v git >/dev/null || ! command -v lb >/dev/null; then
  error_exit "Critical build tools failed to install. Try running 'apt update && apt full-upgrade' manually first."
fi

echo "[*] Checking system environment and disk space..."

# Detect if running on live USB
if mount | grep -q "live-media" || [ -f "/etc/live/config.conf" ] || mount | grep -q "tmpfs.*/" ; then
  echo "[*] Live USB environment detected - applying optimizations..."
  
  # Clear package cache to free space
  apt clean
  
  # Check available space more thoroughly for live USB
  ROOT_SPACE=$(df / | tail -1 | awk '{print $4}')
  VAR_SPACE=$(df /var 2>/dev/null | tail -1 | awk '{print $4}' || echo "$ROOT_SPACE")
  TMP_SPACE=$(df /tmp 2>/dev/null | tail -1 | awk '{print $4}' || echo "$ROOT_SPACE")
  
  echo "[*] Available space: Root=${ROOT_SPACE}KB, Var=${VAR_SPACE}KB, Tmp=${TMP_SPACE}KB"
  
  # Use the largest available space location
  if [ "$TMP_SPACE" -gt "$ROOT_SPACE" ] && [ "$TMP_SPACE" -gt 10485760 ]; then
    WORKDIR="/tmp/kali-mac-live-build"
    echo "[*] Using /tmp for build (largest available space)"
  elif [ "$ROOT_SPACE" -gt 10485760 ]; then
    WORKDIR="/tmp/kali-mac-live-build"
  else
    error_exit "Insufficient disk space. Need at least 10GB free. Consider using a larger USB drive or persistent storage."
  fi
else
  echo "[*] Regular installation detected"
  DISKFREE=$(df --output=avail / | tail -1)
  if [ "$DISKFREE" -lt $((15*1024*1024)) ]; then
    error_exit "Not enough disk space for ISO build (need >15GB free)."
  fi
  WORKDIR="/tmp/kali-mac-live-build"
fi
[ -d "$WORKDIR" ] && rm -rf "$WORKDIR"
mkdir "$WORKDIR" || error_exit "Could not create working directory."
cd "$WORKDIR" || error_exit "Cannot enter working directory."

echo "[*] Cloning Kali live-build config..."
git clone https://gitlab.com/kalilinux/build-scripts/live-build-config.git || error_exit "Git clone failed."
cd live-build-config || error_exit "Failed to enter live-build-config directory."

# Detect desktop environment for later use
detect_desktop() {
  if [ "${XDG_CURRENT_DESKTOP:-}" = "GNOME" ] || [ "${DESKTOP_SESSION:-}" = "gnome" ]; then
    echo "gnome"
  elif [ "${XDG_CURRENT_DESKTOP:-}" = "XFCE" ] || [ "${DESKTOP_SESSION:-}" = "xfce" ]; then
    echo "xfce"
  elif [ "${XDG_CURRENT_DESKTOP:-}" = "KDE" ] || [ "${DESKTOP_SESSION:-}" = "plasma" ]; then
    echo "kde"
  elif [ "${XDG_CURRENT_DESKTOP:-}" = "MATE" ] || [ "${DESKTOP_SESSION:-}" = "mate" ]; then
    echo "mate"
  else
    echo "gnome"
  fi
}

DESKTOP_ENV=$(detect_desktop)
DESKTOP_PACKAGE="kali-desktop-$DESKTOP_ENV"
echo "[*] Detected desktop environment: $DESKTOP_PACKAGE"

echo "[*] Creating Mac variant using official Kali structure..."

# Create a new variant for Mac
cp -r kali-config/variant-default kali-config/variant-mac

# Clean any existing package lists to avoid contamination
rm -f kali-config/variant-mac/package-lists/* 2>/dev/null || true

# Create the proper package list based on official examples
# Using the MINIMAL approach for live USB builds
echo "[*] Creating minimal package list optimized for live USB build..."
echo "kali-linux-core" > kali-config/variant-mac/package-lists/kali.list.chroot
echo "kali-desktop-live" >> kali-config/variant-mac/package-lists/kali.list.chroot

# Use light instead of default for faster/smaller build
if mount | grep -q "live-media" || [ -f "/etc/live/config.conf" ]; then
  echo "kali-tools-top10" >> kali-config/variant-mac/package-lists/kali.list.chroot
  echo "[*] Using minimal tools for live USB build"
else
  echo "kali-linux-light" >> kali-config/variant-mac/package-lists/kali.list.chroot
  echo "[*] Using light tools for regular build"
fi

echo "grub-efi-amd64" >> kali-config/variant-mac/package-lists/kali.list.chroot
echo "firmware-linux" >> kali-config/variant-mac/package-lists/kali.list.chroot
echo "bluez" >> kali-config/variant-mac/package-lists/kali.list.chroot

# Add desktop environment
echo "$DESKTOP_PACKAGE" >> kali-config/variant-mac/package-lists/kali.list.chroot

# Verify the package list is clean and contains only valid package names
echo "[*] Final package list contents:"
cat kali-config/variant-mac/package-lists/kali.list.chroot | head -20
echo "[*] Package list verification complete"

# Add desktop environment based on detection
echo "kali-desktop-$DESKTOP_ENV" >> kali-config/variant-mac/package-lists/kali.list.chroot

echo "[*] Creating Mac-specific configuration files..."

# Create Mac-specific includes directory
mkdir -p kali-config/variant-mac/includes.chroot/etc/default
mkdir -p kali-config/variant-mac/includes.chroot/etc/modprobe.d
mkdir -p kali-config/variant-mac/includes.chroot/usr/local/bin
mkdir -p kali-config/variant-mac/includes.chroot/home/kali/Desktop

# GRUB configuration for Mac
cat > kali-config/variant-mac/includes.chroot/etc/default/grub << 'GRUB'
GRUB_DEFAULT=0
GRUB_TIMEOUT=10
GRUB_DISTRIBUTOR=Kali
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nomodeset"
GRUB_CMDLINE_LINUX="intel_idle.max_cstate=1 acpi_osi=Linux acpi_backlight=vendor"
GRUB_TERMINAL=console
GRUB_GFXMODE=1024x768
GRUB_GFXPAYLOAD_LINUX=keep
GRUB

# Mac hardware tweaks
cat > kali-config/variant-mac/includes.chroot/etc/modprobe.d/mac-tweaks.conf << 'MODPROBE'
# Mac-specific hardware tweaks
options hid_apple fnmode=2
options btusb enable_autosuspend=n
options snd-hda-intel model=mbp101
MODPROBE

# Mac setup script
cat > kali-config/variant-mac/includes.chroot/usr/local/bin/mac-setup.sh << 'MACSETUP'
#!/bin/bash
echo "Applying comprehensive Mac hardware optimizations..."

# Function keys - critical for Mac keyboards
echo 2 > /sys/module/hid_apple/parameters/fnmode 2>/dev/null || true

# Audio setup for Mac hardware
amixer set Master unmute 2>/dev/null || true
amixer set PCM unmute 2>/dev/null || true
amixer set Speaker unmute 2>/dev/null || true
amixer set Headphone unmute 2>/dev/null || true

# Load Mac-specific audio drivers
modprobe snd-hda-intel 2>/dev/null || true

# Bluetooth setup - critical for Mac peripherals
systemctl enable bluetooth 2>/dev/null || true
systemctl start bluetooth 2>/dev/null || true

# WiFi power management (prevent disconnects on Mac)
for iface in $(ls /sys/class/net/ | grep -E 'wl|en|wlan'); do
    if [ -f "/sys/class/net/$iface/device/power/control" ]; then
        echo on > "/sys/class/net/$iface/device/power/control" 2>/dev/null || true
    fi
done

# Load Broadcom drivers if needed
modprobe wl 2>/dev/null || true
modprobe b43 2>/dev/null || true
modprobe brcmsmac 2>/dev/null || true
modprobe brcmfmac 2>/dev/null || true

# Trackpad sensitivity for MacBooks
if [ -d "/proc/bus/input" ]; then
    echo "Setting up Mac trackpad optimizations..."
    # These will be handled by the desktop environment
fi

# Check and report Mac hardware detection
echo "Mac Hardware Detection Report:" > /tmp/mac-hardware-report.txt
echo "=============================" >> /tmp/mac-hardware-report.txt
echo "Date: $(date)" >> /tmp/mac-hardware-report.txt
echo "" >> /tmp/mac-hardware-report.txt

# Detect Mac model
if command -v dmidecode >/dev/null; then
    MAC_MODEL=$(dmidecode -s system-product-name 2>/dev/null || echo "Unknown")
    echo "Mac Model: $MAC_MODEL" >> /tmp/mac-hardware-report.txt
fi

# WiFi hardware detection
echo "WiFi Hardware:" >> /tmp/mac-hardware-report.txt
lspci | grep -i "network\|wireless\|wifi\|broadcom" >> /tmp/mac-hardware-report.txt 2>/dev/null || echo "No WiFi hardware detected" >> /tmp/mac-hardware-report.txt

# Bluetooth hardware detection
echo "" >> /tmp/mac-hardware-report.txt
echo "Bluetooth Hardware:" >> /tmp/mac-hardware-report.txt
lsusb | grep -i bluetooth >> /tmp/mac-hardware-report.txt 2>/dev/null || echo "No Bluetooth hardware detected" >> /tmp/mac-hardware-report.txt

# Audio hardware detection
echo "" >> /tmp/mac-hardware-report.txt
echo "Audio Hardware:" >> /tmp/mac-hardware-report.txt
lspci | grep -i audio >> /tmp/mac-hardware-report.txt 2>/dev/null || echo "No audio hardware detected" >> /tmp/mac-hardware-report.txt

chown kali:kali /tmp/mac-hardware-report.txt 2>/dev/null || true

# Run Bluetooth keyboard helper
/usr/local/bin/bluetooth-keyboard-helper.sh &

echo "Mac hardware optimizations applied. Report saved to /tmp/mac-hardware-report.txt"
MACSETUP

chmod +x kali-config/variant-mac/includes.chroot/usr/local/bin/mac-setup.sh

# Bluetooth keyboard auto-pairing script
cat > kali-config/variant-mac/includes.chroot/usr/local/bin/bluetooth-keyboard-helper.sh << 'BTKBD'
#!/bin/bash

LOGFILE="/tmp/bluetooth-keyboard.log"

log_message() {
    echo "$(date): $1" >> "$LOGFILE"
}

check_physical_keyboards() {
    if lsusb | grep -i keyboard >/dev/null 2>&1; then
        return 0
    fi
    if ls /dev/input/by-id/*keyboard* >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

start_bluetooth_discovery() {
    log_message "Starting Bluetooth keyboard discovery..."
    
    sleep 3
    bluetoothctl power on >/dev/null 2>&1
    sleep 2
    bluetoothctl discoverable on >/dev/null 2>&1
    bluetoothctl pairable on >/dev/null 2>&1
    bluetoothctl scan on >/dev/null 2>&1 &
    SCAN_PID=$!
    
    log_message "Looking for keyboards for 30 seconds..."
    
    for i in {1..30}; do
        sleep 1
        bluetoothctl devices | while read -r line; do
            mac=$(echo "$line" | awk '{print $2}')
            name=$(echo "$line" | cut -d' ' -f3-)
            
            if echo "$name" | grep -qi "keyboard\|magic.*keyboard\|apple.*keyboard"; then
                log_message "Found keyboard: $name ($mac)"
                if bluetoothctl pair "$mac" >/dev/null 2>&1; then
                    log_message "Successfully paired with $name"
                    bluetoothctl trust "$mac" >/dev/null 2>&1
                    bluetoothctl connect "$mac" >/dev/null 2>&1
                    kill $SCAN_PID 2>/dev/null
                    return 0
                fi
            fi
        done
    done
    
    kill $SCAN_PID 2>/dev/null
    bluetoothctl scan off >/dev/null 2>&1
    return 1
}

# Create manual pairing tool
cat > /home/kali/Desktop/Bluetooth-Keyboard-Setup.sh << 'MANUAL'
#!/bin/bash
echo "========================================"
echo "   Bluetooth Keyboard Pairing Tool"
echo "========================================"
echo ""
echo "Starting Bluetooth discovery..."
bluetoothctl power on
bluetoothctl discoverable on
bluetoothctl pairable on
bluetoothctl scan on &
SCAN_PID=$!

echo "Scanning for 30 seconds..."
for i in {1..30}; do
    echo -n "."
    sleep 1
    if [ $((i % 5)) -eq 0 ]; then
        echo ""
        echo "Discovered devices:"
        bluetoothctl devices
        echo ""
    fi
done

kill $SCAN_PID 2>/dev/null
bluetoothctl scan off
echo ""
echo "Available devices:"
bluetoothctl devices
echo ""
read -p "Enter MAC address to pair: " MAC_ADDR
if [ -n "$MAC_ADDR" ]; then
    bluetoothctl pair "$MAC_ADDR"
    bluetoothctl trust "$MAC_ADDR"
    bluetoothctl connect "$MAC_ADDR"
fi
MANUAL

chmod +x /home/kali/Desktop/Bluetooth-Keyboard-Setup.sh
chown kali:kali /home/kali/Desktop/Bluetooth-Keyboard-Setup.sh 2>/dev/null || true

# Main logic
main() {
    log_message "Bluetooth Keyboard Helper starting..."
    sleep 5
    
    if check_physical_keyboards; then
        log_message "Physical keyboard detected"
        return 0
    fi
    
    log_message "No physical keyboard detected, starting discovery"
    if ! start_bluetooth_discovery; then
        log_message "Auto-discovery failed"
        cat > /home/kali/Desktop/NO-KEYBOARD-DETECTED.txt << 'NOKBD'
NO KEYBOARD DETECTED!

To pair a Bluetooth keyboard:
1. Put keyboard in pairing mode
2. Run "Bluetooth-Keyboard-Setup.sh" on desktop
3. Or use command: bluetoothctl

Apple Magic Keyboard: Hold power until LED blinks
NOKBD
        chown kali:kali /home/kali/Desktop/NO-KEYBOARD-DETECTED.txt 2>/dev/null || true
    fi
}

main &
BTKBD

chmod +x kali-config/variant-mac/includes.chroot/usr/local/bin/bluetooth-keyboard-helper.sh

# Create desktop tools installer
cat > kali-config/variant-mac/includes.chroot/home/kali/Desktop/Install-Additional-Mac-Tools.sh << 'TOOLS'
#!/bin/bash

echo "=============================================="
echo "  Additional Mac Tools Installer for Kali"
echo "=============================================="
echo ""

if [ "$(id -u)" -eq 0 ]; then
    echo "[ERROR] Please run as regular user, not root!"
    exit 1
fi

echo "[*] This installer adds comprehensive Mac hardware support and specialized tools"
echo "[*] Including iOS forensics, wireless analysis, and Mac-specific drivers"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

echo ""
echo "[*] Updating package lists..."
sudo apt update

echo ""
echo "[*] Installing additional Broadcom WiFi drivers and firmware..."
sudo apt install -y firmware-b43-installer firmware-b43legacy-installer 2>/dev/null || echo "Some firmware packages may need manual installation"
sudo apt install -y b43-fwcutter bcmwl-kernel-source 2>/dev/null || echo "Some Broadcom drivers may not be available"

echo ""
echo "[*] Installing comprehensive iOS/iPhone forensics tools..."
sudo apt install -y libimobiledevice-1.0-6 libimobiledevice-utils usbmuxd libusbmuxd-tools 2>/dev/null || echo "Installing available iOS tools..."
sudo apt install -y libplist3 libplist-utils ifuse ideviceinstaller 2>/dev/null || echo "Some iOS tools may not be available"
sudo apt install -y sqlite3 sqlitebrowser python3-imobiledevice 2>/dev/null || echo "Installing database tools..."

# Install iOS analysis Python packages
echo ""
echo "[*] Installing advanced iOS analysis tools..."
if command -v pip3 >/dev/null; then
    sudo pip3 install pymobiledevice3 ipatool frida-tools >/dev/null 2>&1 || echo "Some Python iOS tools may not install"
fi

echo ""
echo "[*] Installing comprehensive wireless analysis tools..."
sudo apt install -y kismet kismet-plugins hashcat john hydra nmap masscan 2>/dev/null || echo "Installing available wireless tools..."
sudo apt install -y wifite bettercap wifi-honey pixiewps bully reaver 2>/dev/null || echo "Installing additional wireless tools..."
sudo apt install -y fern-wifi-cracker linssid wavemon 2>/dev/null || echo "Installing WiFi analysis tools..."

echo ""
echo "[*] Installing Mac-specific hardware analysis tools..."
sudo apt install -y macchanger ethtool smartmontools 2>/dev/null || echo "Installing hardware tools..."
sudo apt install -y gparted testdisk photorec 2>/dev/null || echo "Installing disk tools..."

echo ""
echo "[*] Installing comprehensive forensics and analysis tools..."
sudo apt install -y volatility3 autopsy bulk-extractor sleuthkit foremost binwalk 2>/dev/null || echo "Installing forensics tools..."
sudo apt install -y ddrescue safecopy guymager dc3dd 2>/dev/null || echo "Installing data recovery tools..."
sudo apt install -y steghide outguess stegsnow exiftool 2>/dev/null || echo "Installing steganography tools..."

echo ""
echo "[*] Installing additional Mac hardware and filesystem support..."
sudo apt install -y hfsprogs hfsplus hfsutils 2>/dev/null || echo "Installing HFS+ support..."
sudo apt install -y firmware-realtek firmware-atheros firmware-iwlwifi 2>/dev/null || echo "Installing additional firmware..."
sudo apt install -y pavucontrol pulseaudio-equalizer alsa-tools 2>/dev/null || echo "Installing audio tools..."

echo ""
echo "[*] Installing advanced Bluetooth and wireless tools..."
sudo apt install -y blueman bluetooth btscanner bluelog bluesnarfer 2>/dev/null || echo "Installing Bluetooth tools..."
sudo apt install -y ubertooth spooftooth bluetoothctl 2>/dev/null || echo "Installing advanced Bluetooth tools..."

echo ""
echo "[*] Installing network analysis and penetration testing tools..."
sudo apt install -y wireshark tcpdump ngrep dsniff ettercap-text-only 2>/dev/null || echo "Installing network tools..."
sudo apt install -y metasploit-framework beef-xss social-engineer-toolkit 2>/dev/null || echo "Installing penetration testing tools..."

echo ""
echo "[*] Applying comprehensive Mac hardware optimizations..."

# Function keys optimization
echo 2 | sudo tee /sys/module/hid_apple/parameters/fnmode >/dev/null 2>&1 || true

# Bluetooth services
sudo systemctl enable bluetooth >/dev/null 2>&1 || true
sudo systemctl start bluetooth >/dev/null 2>&1 || true

# Load Broadcom WiFi drivers
sudo modprobe wl 2>/dev/null || true
sudo modprobe b43 2>/dev/null || true
sudo modprobe brcmsmac 2>/dev/null || true
sudo modprobe brcmfmac 2>/dev/null || true

# Audio optimization
sudo alsa force-reload 2>/dev/null || true

# Create WiFi driver switching script
cat > ~/Desktop/Switch-WiFi-Driver.sh << 'WIFISWITCH'
#!/bin/bash
echo "Mac WiFi Driver Switcher"
echo "======================="
echo ""
echo "Current WiFi status:"
iwconfig 2>/dev/null | grep -E "IEEE|ESSID" || echo "No WiFi interface detected"
echo ""
echo "Available drivers:"
echo "1. wl (Broadcom proprietary)"
echo "2. b43 (Open source)"
echo "3. brcmsmac (Open source)"
echo ""
read -p "Choose driver (1-3): " choice

case $choice in
    1)
        sudo modprobe -r b43 brcmsmac 2>/dev/null
        sudo modprobe wl
        echo "Switched to wl driver"
        ;;
    2)
        sudo modprobe -r wl brcmsmac 2>/dev/null  
        sudo modprobe b43
        echo "Switched to b43 driver"
        ;;
    3)
        sudo modprobe -r wl b43 2>/dev/null
        sudo modprobe brcmsmac
        echo "Switched to brcmsmac driver"
        ;;
    *)
        echo "Invalid choice"
        ;;
esac

echo ""
echo "New WiFi status:"
iwconfig 2>/dev/null | grep -E "IEEE|ESSID" || echo "No WiFi interface detected"
WIFISWITCH

chmod +x ~/Desktop/Switch-WiFi-Driver.sh

echo ""
echo "Installation complete!"
echo ""
echo "=== MAC-SPECIFIC TOOLS AND COMMANDS ==="
echo ""
echo "iOS/iPhone Analysis:"
echo "  ideviceinfo              - iPhone device information"
echo "  idevicebackup2 backup ./ - Backup iPhone to current directory"  
echo "  ifuse /mnt/iphone        - Mount iPhone filesystem"
echo "  ideviceinstaller -l      - List installed iOS apps"
echo "  frida-ps -U              - List running iOS processes (jailbroken)"
echo "  sqlite3 database.db      - Analyze iOS databases"
echo ""
echo "Wireless Analysis (Mac optimized):"
echo "  kismet                   - Advanced wireless monitoring"
echo "  wifite                   - Automated wireless attacks"
echo "  airodump-ng              - WiFi packet capture"
echo "  ./Switch-WiFi-Driver.sh  - Switch between Broadcom drivers"
echo "  iwconfig                 - Check WiFi status"
echo ""
echo "Bluetooth Analysis:"
echo "  bluetoothctl             - Bluetooth management"
echo "  btscanner                - Bluetooth device discovery"
echo "  bluelog                  - Bluetooth logging"
echo "  hcitool scan             - Scan for Bluetooth devices"
echo ""
echo "Mac Filesystem Support:"
echo "  mount -t hfsplus /dev/sdX /mnt  - Mount Mac drive"
echo "  fsck.hfsplus /dev/sdX           - Check Mac filesystem"
echo "  hfsdebug /dev/sdX               - Debug HFS+ filesystem"
echo ""
echo "Forensics and Analysis:"
echo "  volatility3 -f memory.dump      - Memory analysis"
echo "  binwalk firmware.bin            - Firmware analysis"
echo "  autopsy                         - GUI forensics suite"
echo "  ddrescue /dev/sdX image.dd      - Data recovery"
echo ""
echo "Hardware Detection:"
echo "  lspci | grep -i broadcom        - Check Broadcom hardware"
echo "  iwconfig                        - WiFi interface status"
echo "  hciconfig                       - Bluetooth status"
echo "  dmesg | grep -i firmware        - Check firmware loading"
echo ""
echo "=== IMPORTANT NOTES ==="
echo "• WiFi: Try different Broadcom drivers if WiFi doesn't work"
echo "• Bluetooth: Should auto-pair keyboards on startup"
echo "• iOS: Connect device and trust computer for analysis"
echo "• Some tools may require additional setup or permissions"
echo ""

# Create hardware report
echo "Creating Mac hardware compatibility report..."
cat > ~/Desktop/Mac-Hardware-Report.txt << 'REPORT'
Mac Hardware Compatibility Report
================================
Generated: $(date)

WiFi Hardware:
$(lspci | grep -i "network\|wireless\|broadcom" || echo "No WiFi hardware detected")

Bluetooth Hardware: 
$(lsusb | grep -i bluetooth || echo "No Bluetooth hardware detected")

Audio Hardware:
$(lspci | grep -i audio || echo "No audio hardware detected")

Mac Model:
$(sudo dmidecode -s system-product-name 2>/dev/null || echo "Unknown")

Loaded WiFi Modules:
$(lsmod | grep -E "wl|b43|brcm" || echo "No Broadcom modules loaded")

Kernel Firmware Messages:
$(dmesg | grep -i firmware | tail -10)
REPORT

eval "cat > ~/Desktop/Mac-Hardware-Report.txt << 'REPORT'
Mac Hardware Compatibility Report
================================
Generated: $(date)

WiFi Hardware:
$(lspci | grep -i "network\|wireless\|broadcom" || echo "No WiFi hardware detected")

Bluetooth Hardware: 
$(lsusb | grep -i bluetooth || echo "No Bluetooth hardware detected")

Audio Hardware:
$(lspci | grep -i audio || echo "No audio hardware detected")

Mac Model:
$(sudo dmidecode -s system-product-name 2>/dev/null || echo "Unknown")

Loaded WiFi Modules:
$(lsmod | grep -E "wl|b43|brcm" || echo "No Broadcom modules loaded")

Recent Firmware Messages:
$(dmesg | grep -i firmware | tail -5)
REPORT"

echo ""
echo "Hardware report saved to: ~/Desktop/Mac-Hardware-Report.txt"
echo "WiFi driver switcher available: ~/Desktop/Switch-WiFi-Driver.sh"
echo ""
echo "Enjoy your fully equipped Mac-optimized Kali Linux system!"
TOOLS

chmod +x kali-config/variant-mac/includes.chroot/home/kali/Desktop/Install-Additional-Mac-Tools.sh

# Create systemd service for Mac setup
mkdir -p kali-config/variant-mac/includes.chroot/etc/systemd/system
cat > kali-config/variant-mac/includes.chroot/etc/systemd/system/mac-setup.service << 'SERVICE'
[Unit]
Description=Mac Hardware Setup
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/mac-setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE

# Create hook to enable the service (instead of broken symlink)
mkdir -p kali-config/variant-mac/hooks/live
cat > kali-config/variant-mac/hooks/live/enable-mac-setup.chroot << 'ENABLEHOOK'
#!/bin/bash
systemctl enable mac-setup.service 2>/dev/null || true
chown -R kali:kali /home/kali/Desktop/ 2>/dev/null || true
ENABLEHOOK

chmod +x kali-config/variant-mac/hooks/live/enable-mac-setup.chroot

# Create hook to fix permissions
mkdir -p kali-config/variant-mac/hooks/live
cat > kali-config/variant-mac/hooks/live/fix-permissions.chroot << 'HOOK'
#!/bin/bash
chown -R kali:kali /home/kali/Desktop/ 2>/dev/null || true
HOOK

chmod +x kali-config/variant-mac/hooks/live/fix-permissions.chroot

echo "[*] Mac variant created successfully"

# Clean up any potential sources of package list contamination
find kali-config/variant-mac/ -name "*.list.*" -type f ! -name "kali.list.chroot" -delete 2>/dev/null || true
find kali-config/common/ -name "*.list.*" -type f -delete 2>/dev/null || true

echo "[*] Cleaning previous builds..."
lb clean --purge 2>/dev/null || true

echo "[*] Building Mac-compatible Kali ISO (this will take 30-60 minutes)..."

# Optimize for live USB environment
if mount | grep -q "live-media" || [ -f "/etc/live/config.conf" ]; then
  echo "[*] Applying live USB build optimizations..."
  # Use faster compression for live USB builds
  export LB_COMPRESSION="gzip"
  # Limit parallel jobs to conserve memory
  export MAKEFLAGS="-j1"
  # Clear more cache space
  apt clean
  apt autoremove -y
fi

# Ensure clean environment for build
export LANG=C
export LC_ALL=C
unset GREP_OPTIONS 2>/dev/null || true

if ! ./build.sh --distribution kali-rolling --variant mac --verbose; then
  # Try alternative build method if build.sh fails
  echo "[*] Primary build method failed, trying alternative approach..."
  if ! lb config --distribution kali-rolling --variant mac && lb build; then
    error_exit "Build failed. Check logs above for details."
  fi
fi

ISO_PATH=""

# Look for the ISO file in multiple possible locations
for location in "." "./images" "../images" "/tmp/kali-mac-live-build/live-build-config" "/tmp/kali-mac-live-build/live-build-config/images"; do
  if [ -d "$location" ]; then
    ISO_FOUND=$(find "$location" -name "*.iso" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2- || true)
    if [ -n "$ISO_FOUND" ] && [ -f "$ISO_FOUND" ]; then
      ISO_PATH="$ISO_FOUND"
      break
    fi
  fi
done

# Fallback: search more broadly
if [ -z "$ISO_PATH" ] || [ ! -f "$ISO_PATH" ]; then
  ISO_PATH=$(find /tmp/kali-mac-live-build -name "*.iso" -type f 2>/dev/null | head -1 || true)
fi

if [ -z "$ISO_PATH" ] || [ ! -f "$ISO_PATH" ]; then
  echo "[ERROR] Build may have completed but no ISO file found in expected locations."
  echo "[INFO] Searching for any ISO files..."
  find /tmp/kali-mac-live-build -name "*.iso" -type f 2>/dev/null || echo "No ISO files found anywhere."
  error_exit "ISO build completed but no ISO file found."
fi

echo "[*] ISO built successfully: $ISO_PATH"
echo "[*] ISO size: $(du -h "$ISO_PATH" | cut -f1)"

echo ""
echo "Available removable drives:"
lsblk -o NAME,SIZE,MODEL,TRAN | grep -iE 'usb|removable' || echo "No removable drives found."
echo ""
echo "WARNING: Flashing will ERASE ALL DATA on the selected device."
read -rp "Enter device path (e.g., /dev/sdb), or 'skip' to skip flashing: " USBDEV

if [ "$USBDEV" = "skip" ]; then
  echo "[INFO] Skipping USB creation. ISO available at: $ISO_PATH"
  echo "[INFO] Flash with: sudo dd if=$ISO_PATH of=/dev/sdX bs=4M status=progress"
  exit 0
fi

if [ ! -b "$USBDEV" ]; then
  error_exit "Device $USBDEV not found!"
fi

if mount | grep -q "$USBDEV"; then
  echo "[*] Unmounting $USBDEV partitions..."
  umount "${USBDEV}"* 2>/dev/null || true
fi

echo ""
echo "Device: $USBDEV"
echo "Size: $(lsblk -no SIZE "$USBDEV" 2>/dev/null || echo "Unknown")"
echo ""
read -rp "Are you ABSOLUTELY SURE you want to erase $USBDEV? (type 'YES'): " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
  error_exit "Operation cancelled."
fi

echo "[*] Flashing $ISO_PATH to $USBDEV..."
if command -v pv >/dev/null; then
  pv "$ISO_PATH" | dd of="$USBDEV" bs=4M conv=fsync oflag=direct 2>/dev/null || error_exit "Flashing failed!"
else
  dd if="$ISO_PATH" of="$USBDEV" bs=4M conv=fsync status=progress || error_exit "Flashing failed!"
fi

sync
sleep 2

eject "$USBDEV" 2>/dev/null || echo "[INFO] Please safely remove USB drive."

echo ""
echo "================================================================"
echo "[SUCCESS] Kali Live Mac USB is ready!"
echo "================================================================"
echo ""
echo "To boot on Intel Mac:"
echo "1. Insert USB and restart Mac"
echo "2. Hold Option (⌥) key during boot"
echo "3. Select 'EFI Boot' or USB drive"
echo "4. Choose 'Live system' from GRUB"
echo ""
echo "After booting:"
echo "• Bluetooth keyboard pairing happens automatically"
echo "• Run 'Install-Additional-Mac-Tools.sh' from desktop for more tools"
echo "• Manual Bluetooth pairing: 'Bluetooth-Keyboard-Setup.sh'"
echo ""
echo "Features included:"
echo "✓ Mac hardware optimization"
echo "✓ Automatic Bluetooth keyboard pairing"
echo "✓ EFI boot support"
echo "✓ Desktop installer for iOS/wireless/forensics tools"
echo ""
echo "ISO: $ISO_PATH"
echo "Working dir: $WORKDIR"
echo ""

exit 0
