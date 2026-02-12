#!/bin/bash
################################################################################
# KALI ANONYMIZATION SUITE - COMPLETE PRIVACY & ANONYMIZATION
# Version: 1.0
# Purpose: Comprehensive anonymization for legitimate penetration testing
# WARNING: For authorized security research and testing only
################################################################################

set -e

#==============================================================================
# COLORS & FORMATTING
#==============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

#==============================================================================
# CONFIGURATION
#==============================================================================
SCRIPT_VERSION="1.0"
LOG_FILE="/var/log/kali_anonymize.log"
BACKUP_DIR="/root/anonymize_backup"
STATE_FILE="/var/run/anonymize_state"

# Network settings
TOR_PORT=9050
DNS_SERVERS="127.0.0.1"  # Will use Tor DNS
VPN_CONFIG_DIR="/etc/openvpn"

#==============================================================================
# LOGGING & ERROR HANDLING
#==============================================================================
log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${msg}" | tee -a "$LOG_FILE"
}

info() { log "INFO" "${GREEN}✓${NC} $*"; }
warn() { log "WARN" "${YELLOW}⚠${NC} $*"; }
error() { log "ERROR" "${RED}✗${NC} $*"; }
success() { echo -e "${GREEN}${BOLD}✅ $*${NC}"; log "SUCCESS" "$*"; }
fail() { echo -e "${RED}${BOLD}❌ $*${NC}"; log "FAIL" "$*"; }

#==============================================================================
# BANNER
#==============================================================================
show_banner() {
    clear
    echo -e "${PURPLE}${BOLD}"
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║   🔒 KALI ANONYMIZATION SUITE - COMPLETE PRIVACY 🔒           ║
║                                                                ║
║   • Tor Network Integration                                   ║
║   • VPN Support                                               ║
║   • MAC Address Randomization                                 ║
║   • DNS Privacy Protection                                    ║
║   • Proxychains Configuration                                 ║
║   • Browser Anonymization                                     ║
║   • Metadata Removal                                          ║
║                                                                ║
║   ⚠️  FOR AUTHORIZED TESTING ONLY ⚠️                          ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

#==============================================================================
# SYSTEM CHECKS
#==============================================================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        fail "This script must be run as root (sudo)"
        exit 1
    fi
}

check_kali() {
    if ! grep -q "Kali" /etc/os-release 2>/dev/null; then
        warn "This script is optimized for Kali Linux"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
    fi
    info "OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
}

#==============================================================================
# BACKUP SYSTEM
#==============================================================================
backup_configs() {
    info "📦 Backing up original configurations..."
    
    mkdir -p "$BACKUP_DIR"
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    
    # Backup network configs
    [[ -f /etc/resolv.conf ]] && cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf.$backup_timestamp"
    [[ -f /etc/proxychains4.conf ]] && cp /etc/proxychains4.conf "$BACKUP_DIR/proxychains4.conf.$backup_timestamp"
    [[ -f /etc/tor/torrc ]] && cp /etc/tor/torrc "$BACKUP_DIR/torrc.$backup_timestamp"
    
    # Save current MAC addresses
    ip link show | grep -E "link/ether" > "$BACKUP_DIR/mac_addresses.$backup_timestamp"
    
    # Save hostname
    hostname > "$BACKUP_DIR/hostname.$backup_timestamp"
    
    success "Backups saved to $BACKUP_DIR"
}

#==============================================================================
# PACKAGE INSTALLATION
#==============================================================================
install_packages() {
    info "📦 Installing required packages..."
    
    local packages=(
        "tor"
        "torbrowser-launcher"
        "proxychains4"
        "macchanger"
        "openvpn"
        "resolvconf"
        "dnsutils"
        "curl"
        "mat2"
        "bleachbit"
    )
    
    apt-get update -qq
    
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$pkg"; then
            info "Installing: $pkg"
            apt-get install -y "$pkg" 2>&1 | tee -a "$LOG_FILE"
        else
            info "Already installed: $pkg"
        fi
    done
    
    success "All packages installed"
}

#==============================================================================
# TOR CONFIGURATION
#==============================================================================
configure_tor() {
    info "🧅 Configuring Tor..."
    
    # Create Tor config
    cat > /etc/tor/torrc << 'TORRC_EOF'
# Tor Configuration for Kali Anonymization
# Generated automatically

# SOCKS proxy
SOCKSPort 9050
SOCKSPolicy accept 127.0.0.1/8
SOCKSPolicy reject *

# DNS
DNSPort 5353

# Transparent proxy
TransPort 9040
TransListenAddress 127.0.0.1

# Control port
ControlPort 9051
CookieAuthentication 1

# Privacy settings
AvoidDiskWrites 1
HardwareAccel 1

# Circuit settings
CircuitBuildTimeout 60
LearnCircuitBuildTimeout 0
MaxCircuitDirtiness 600

# Entry/Exit nodes (uncomment to specify countries)
# ExitNodes {US},{GB},{DE}
# EntryNodes {US},{GB},{DE}
# StrictNodes 1

# Logging
Log notice file /var/log/tor/notices.log
TORRC_EOF
    
    # Set permissions
    chmod 644 /etc/tor/torrc
    
    # Start Tor
    systemctl enable tor
    systemctl restart tor
    
    # Wait for Tor to establish circuits
    info "Waiting for Tor to establish circuits..."
    sleep 10
    
    # Verify Tor is running
    if systemctl is-active --quiet tor; then
        success "Tor is running"
        
        # Test Tor connection
        if curl --socks5 127.0.0.1:9050 -s https://check.torproject.org/ | grep -q "Congratulations"; then
            success "Tor connection verified!"
        else
            warn "Tor is running but connection test failed"
        fi
    else
        error "Tor failed to start"
        return 1
    fi
}

#==============================================================================
# PROXYCHAINS CONFIGURATION
#==============================================================================
configure_proxychains() {
    info "🔗 Configuring Proxychains..."
    
    cat > /etc/proxychains4.conf << 'PROXY_EOF'
# Proxychains Configuration
# Routes all TCP traffic through Tor

strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
socks5 127.0.0.1 9050
PROXY_EOF
    
    success "Proxychains configured"
}

#==============================================================================
# MAC ADDRESS RANDOMIZATION
#==============================================================================
randomize_mac() {
    info "🎭 Randomizing MAC addresses..."
    
    # Get all network interfaces
    local interfaces=$(ip link show | grep -E "^[0-9]+:" | cut -d: -f2 | tr -d ' ' | grep -v "lo")
    
    for interface in $interfaces; do
        info "Randomizing MAC for: $interface"
        
        # Bring interface down
        ip link set "$interface" down 2>/dev/null || true
        
        # Randomize MAC
        if command -v macchanger &>/dev/null; then
            macchanger -r "$interface" 2>&1 | grep -E "New|Permanent" | tee -a "$LOG_FILE"
        fi
        
        # Bring interface up
        ip link set "$interface" up 2>/dev/null || true
        
        sleep 2
    done
    
    success "MAC addresses randomized"
}

#==============================================================================
# DNS PRIVACY
#==============================================================================
configure_dns() {
    info "🔒 Configuring DNS privacy..."
    
    # Make resolv.conf immutable temporarily
    chattr -i /etc/resolv.conf 2>/dev/null || true
    
    # Configure DNS to use Tor
    cat > /etc/resolv.conf << 'DNS_EOF'
# DNS Configuration for Tor
# All DNS queries go through Tor
nameserver 127.0.0.1
options edns0
DNS_EOF
    
    # Make immutable to prevent overwrites
    chattr +i /etc/resolv.conf
    
    success "DNS configured to use Tor"
}

#==============================================================================
# HOSTNAME RANDOMIZATION
#==============================================================================
randomize_hostname() {
    info "🎲 Randomizing hostname..."
    
    local random_name="kali-$(openssl rand -hex 4)"
    
    # Set hostname
    hostnamectl set-hostname "$random_name"
    
    # Update /etc/hosts
    sed -i "s/127.0.1.1.*/127.0.1.1\t$random_name/" /etc/hosts
    
    success "Hostname changed to: $random_name"
}

#==============================================================================
# IPTABLES RULES FOR TOR
#==============================================================================
configure_iptables() {
    info "🛡️  Configuring iptables for Tor..."
    
    # Flush existing rules
    iptables -F
    iptables -t nat -F
    
    # Default policies
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT DROP
    
    # Allow loopback
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    # Allow Tor
    iptables -A OUTPUT -m owner --uid-owner debian-tor -j ACCEPT
    
    # Allow established connections
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Redirect DNS to Tor
    iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 5353
    
    # Redirect all TCP through Tor TransPort
    iptables -t nat -A OUTPUT -p tcp -j REDIRECT --to-ports 9040
    
    # Allow local network (if needed for SSH, etc)
    iptables -A INPUT -s 192.168.0.0/16 -j ACCEPT
    iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT
    
    # Save rules
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    
    success "iptables configured for Tor transparent proxy"
}

#==============================================================================
# BROWSER ANONYMIZATION
#==============================================================================
setup_tor_browser() {
    info "🌐 Setting up Tor Browser..."
    
    # Tor Browser should be installed via torbrowser-launcher
    # Just provide instructions
    cat > /root/TOR_BROWSER_SETUP.txt << 'TB_EOF'
╔════════════════════════════════════════════════════════════════╗
║               TOR BROWSER SETUP INSTRUCTIONS                   ║
╚════════════════════════════════════════════════════════════════╝

To complete Tor Browser setup:

1. Run as normal user (not root):
   torbrowser-launcher

2. Follow the setup wizard

3. Always use Tor Browser for anonymous web browsing

4. Configure Tor Browser:
   - Use "Safest" security level
   - Disable JavaScript for maximum privacy
   - Never maximize the window (fingerprinting)
   - Clear cookies on exit

5. Additional privacy:
   - Install HTTPS Everywhere
   - Install NoScript
   - Install uBlock Origin

═══════════════════════════════════════════════════════════════
TB_EOF
    
    success "Tor Browser instructions saved to /root/TOR_BROWSER_SETUP.txt"
}

#==============================================================================
# METADATA REMOVAL TOOLS
#==============================================================================
setup_metadata_tools() {
    info "🗑️  Setting up metadata removal tools..."
    
    # MAT2 is already installed, create helper script
    cat > /usr/local/bin/clean-metadata << 'META_EOF'
#!/bin/bash
# Quick metadata removal script

if [[ $# -eq 0 ]]; then
    echo "Usage: clean-metadata <file_or_directory>"
    echo "Removes metadata from files using MAT2"
    exit 1
fi

mat2 --lightweight "$@"
EOF
    
    chmod +x /usr/local/bin/clean-metadata
    
    success "Metadata removal tools configured (use: clean-metadata <file>)"
}

#==============================================================================
# PRIVACY CHECK SCRIPT
#==============================================================================
create_check_script() {
    info "📊 Creating privacy check script..."
    
    cat > /usr/local/bin/check-anonymity << 'CHECK_EOF'
#!/bin/bash
# Check current anonymization status

echo "═══════════════════════════════════════════════════════════════"
echo "🔒 ANONYMITY STATUS CHECK"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check Tor
echo "🧅 Tor Status:"
if systemctl is-active --quiet tor; then
    echo "  ✅ Tor is running"
    
    # Check Tor connection
    if curl --socks5 127.0.0.1:9050 -s https://check.torproject.org/ 2>/dev/null | grep -q "Congratulations"; then
        echo "  ✅ Tor connection working"
        
        # Get exit node IP
        exit_ip=$(curl --socks5 127.0.0.1:9050 -s https://api.ipify.org 2>/dev/null)
        echo "  📍 Exit IP: $exit_ip"
    else
        echo "  ❌ Tor connection test failed"
    fi
else
    echo "  ❌ Tor is not running"
fi

echo ""
echo "🎭 MAC Addresses:"
ip link show | grep -A1 "state UP" | grep "link/ether" | awk '{print "  "$2}'

echo ""
echo "🌐 DNS Configuration:"
echo "  $(grep nameserver /etc/resolv.conf)"

echo ""
echo "🔗 Proxychains:"
if [[ -f /etc/proxychains4.conf ]]; then
    echo "  ✅ Configured"
else
    echo "  ❌ Not configured"
fi

echo ""
echo "🛡️  Iptables Rules:"
rule_count=$(iptables -L | grep -c "Chain")
echo "  Active chains: $rule_count"

echo ""
echo "🖥️  Hostname:"
echo "  $(hostname)"

echo ""
echo "═══════════════════════════════════════════════════════════════"
EOF
    
    chmod +x /usr/local/bin/check-anonymity
    
    success "Privacy check script created (use: check-anonymity)"
}

#==============================================================================
# DISABLE SCRIPT (RESTORE NORMAL)
#==============================================================================
create_disable_script() {
    info "🔧 Creating disable script..."
    
    cat > /usr/local/bin/disable-anonymity << 'DISABLE_EOF'
#!/bin/bash
# Disable anonymization and restore normal networking

if [[ $EUID -ne 0 ]]; then
    echo "Must run as root"
    exit 1
fi

echo "🔓 Disabling anonymization..."

# Stop Tor
systemctl stop tor

# Flush iptables
iptables -F
iptables -t nat -F
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Restore DNS
chattr -i /etc/resolv.conf 2>/dev/null || true
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# Restore original MAC addresses (requires reboot or manual reset)
echo "⚠️  MAC addresses will reset on next reboot or manual reset"

echo "✅ Anonymization disabled"
echo "💡 Tip: Reboot to fully restore original configuration"
DISABLE_EOF
    
    chmod +x /usr/local/bin/disable-anonymity
    
    success "Disable script created (use: disable-anonymity)"
}

#==============================================================================
# SAVE STATE
#==============================================================================
save_state() {
    cat > "$STATE_FILE" << EOF
ANONYMIZATION_ENABLED=true
TIMESTAMP=$(date +%s)
TOR_ENABLED=true
MAC_RANDOMIZED=true
IPTABLES_CONFIGURED=true
HOSTNAME=$(hostname)
EOF
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================
main() {
    show_banner
    
    log "INFO" "=============== KALI ANONYMIZATION SUITE v$SCRIPT_VERSION ==============="
    
    # Safety warning
    echo -e "${YELLOW}${BOLD}"
    echo "⚠️  WARNING ⚠️"
    echo "This script will configure comprehensive anonymization."
    echo "Use only for authorized penetration testing and security research."
    echo ""
    read -p "Do you understand and agree? (yes/no): " -r
    echo -e "${NC}"
    
    if [[ ! $REPLY == "yes" ]]; then
        error "User did not agree. Exiting."
        exit 1
    fi
    
    # Pre-flight checks
    check_root
    check_kali
    
    # Backup
    backup_configs
    
    # Install packages
    install_packages
    
    # Configure everything
    configure_tor
    configure_proxychains
    randomize_mac
    configure_dns
    randomize_hostname
    configure_iptables
    setup_tor_browser
    setup_metadata_tools
    
    # Create utility scripts
    create_check_script
    create_disable_script
    
    # Save state
    save_state
    
    # Final summary
    echo ""
    echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║   ✅ ANONYMIZATION COMPLETE! ✅                               ║${NC}"
    echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}What was configured:${NC}"
    echo "  ✅ Tor Network (all traffic routed through Tor)"
    echo "  ✅ Proxychains (force apps through Tor)"
    echo "  ✅ MAC Address Randomization"
    echo "  ✅ DNS Privacy (Tor DNS)"
    echo "  ✅ Hostname Randomization"
    echo "  ✅ Iptables Firewall (transparent Tor proxy)"
    echo "  ✅ Metadata Removal Tools"
    echo ""
    echo -e "${CYAN}Utility commands:${NC}"
    echo "  check-anonymity       - Check current anonymization status"
    echo "  disable-anonymity     - Disable and restore normal networking"
    echo "  clean-metadata <file> - Remove metadata from files"
    echo "  proxychains4 <cmd>    - Run command through Tor"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Run: check-anonymity"
    echo "  2. Test: curl https://check.torproject.org"
    echo "  3. Browse: torbrowser-launcher (as normal user)"
    echo ""
    echo -e "${YELLOW}⚠️  Important:${NC}"
    echo "  • Backups saved to: $BACKUP_DIR"
    echo "  • Logs saved to: $LOG_FILE"
    echo "  • Some services may need restart"
    echo "  • Reboot recommended for full effect"
    echo ""
}

# Trap signals
trap 'error "Script interrupted"; exit 130' INT TERM

# Execute
main "$@"
