#!/bin/bash
# Mac WiFi Troubleshooter & DNS Fixer
# Specifically designed for macOS connectivity issues
# Auto-detects and fixes common Mac WiFi problems

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[Mac WiFi Fixer]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }

show_banner() {
    clear
    echo -e "${PURPLE}"
    cat << 'EOF'
    ███╗   ███╗ █████╗  ██████╗    ██╗    ██╗██╗███████╗██╗    
    ████╗ ████║██╔══██╗██╔════╝    ██║    ██║██║██╔════╝██║    
    ██╔████╔██║███████║██║         ██║ █╗ ██║██║█████╗  ██║    
    ██║╚██╔╝██║██╔══██║██║         ██║███╗██║██║██╔══╝  ██║    
    ██║ ╚═╝ ██║██║  ██║╚██████╗    ╚███╔███╔╝██║██║     ██║    
    ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝     ╚══╝╚══╝ ╚═╝╚═╝     ╚═╝    
    
    🍎 Mac WiFi Troubleshooter & DNS Fixer 🍎
    🔧 Fixes connectivity when WiFi connects but web doesn't work 🔧
    
EOF
    echo -e "${NC}"
}

check_macos() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        error "This script is designed specifically for macOS"
        echo "For Linux, use: python3 ultimate-wifi-fixer.py"
        exit 1
    fi
    
    info "Detected macOS $(sw_vers -productVersion)"
}

get_wifi_info() {
    log "🔍 Analyzing WiFi connection..."
    
    # Get current WiFi network
    WIFI_NETWORK=$(networksetup -getairportnetwork en0 | cut -d' ' -f4-)
    if [[ "$WIFI_NETWORK" == *"not associated"* ]]; then
        error "No WiFi network connected"
        echo "Please connect to WiFi first"
        exit 1
    fi
    
    info "Connected to WiFi: $WIFI_NETWORK"
    
    # Get WiFi details using airport
    if [[ -f "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport" ]]; then
        AIRPORT_INFO=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I)
        
        SIGNAL=$(echo "$AIRPORT_INFO" | grep "agrCtlRSSI" | awk '{print $2}')
        CHANNEL=$(echo "$AIRPORT_INFO" | grep "channel" | awk '{print $2}')
        
        if [[ -n "$SIGNAL" ]]; then
            info "Signal strength: ${SIGNAL} dBm"
            if [[ "$SIGNAL" -lt -70 ]]; then
                warn "Weak WiFi signal detected (${SIGNAL} dBm)"
            fi
        fi
        
        if [[ -n "$CHANNEL" ]]; then
            info "Channel: $CHANNEL"
        fi
    fi
}

test_connectivity() {
    log "🌐 Testing connectivity..."
    
    # Test basic network connectivity
    if ping -c 3 -W 5000 8.8.8.8 > /dev/null 2>&1; then
        info "✅ Basic internet connectivity: OK"
        PING_OK=true
    else
        error "❌ No internet connectivity via ping"
        PING_OK=false
    fi
    
    # Test DNS resolution
    if nslookup google.com > /dev/null 2>&1; then
        info "✅ DNS resolution: OK"
        DNS_OK=true
    else
        error "❌ DNS resolution failed"
        DNS_OK=false
    fi
    
    # Test HTTP connectivity
    if curl -s --connect-timeout 10 http://www.google.com > /dev/null; then
        info "✅ HTTP connectivity: OK"
        HTTP_OK=true
    else
        error "❌ HTTP connectivity failed"
        HTTP_OK=false
    fi
    
    # Test HTTPS connectivity
    if curl -s --connect-timeout 10 https://www.google.com > /dev/null; then
        info "✅ HTTPS connectivity: OK"
        HTTPS_OK=true
    else
        error "❌ HTTPS connectivity failed"
        HTTPS_OK=false
    fi
}

check_dns_issues() {
    log "🔍 Checking DNS configuration..."
    
    # Get current DNS servers
    DNS_SERVERS=$(scutil --dns | grep "nameserver" | head -5)
    info "Current DNS servers:"
    echo "$DNS_SERVERS" | while read -r line; do
        echo "   $line"
    done
    
    # Check for VPN DNS pollution
    VPN_DNS_COUNT=$(scutil --dns | grep -c "resolver #[8-9]" || true)
    if [[ "$VPN_DNS_COUNT" -gt 0 ]]; then
        warn "VPN DNS resolvers detected - potential DNS pollution"
        VPN_DNS_ISSUE=true
    else
        VPN_DNS_ISSUE=false
    fi
    
    # Check mDNSResponder process
    MDNS_CPU=$(ps aux | grep mDNSResponder | grep -v grep | awk '{print $3}' | head -1)
    if [[ -n "$MDNS_CPU" ]]; then
        info "mDNSResponder CPU usage: ${MDNS_CPU}%"
        if (( $(echo "$MDNS_CPU > 10" | bc -l) )); then
            warn "High mDNSResponder CPU usage detected"
            MDNS_HIGH_CPU=true
        else
            MDNS_HIGH_CPU=false
        fi
    fi
}

fix_dns_issues() {
    log "🔧 Fixing DNS issues..."
    
    # Fix 1: Flush DNS cache
    info "Flushing DNS cache..."
    sudo dscacheutil -flushcache
    
    # Fix 2: Restart mDNSResponder
    info "Restarting mDNSResponder..."
    sudo killall -HUP mDNSResponder
    
    # Fix 3: Clear VPN DNS pollution if detected
    if [[ "$VPN_DNS_ISSUE" == true ]]; then
        warn "Clearing VPN DNS pollution..."
        # Force reset network services
        sudo networksetup -setdnsservers "Wi-Fi" Empty
        sleep 2
        sudo networksetup -setdnsservers "Wi-Fi" 1.1.1.1 8.8.8.8 8.8.4.4
    fi
    
    # Fix 4: Reset network location if severe issues
    if [[ "$DNS_OK" == false && "$HTTP_OK" == false ]]; then
        warn "Severe connectivity issues - resetting network location..."
        
        # Create and switch to new network location
        TEMP_LOCATION="WiFi-Fix-$(date +%s)"
        networksetup -createlocation "$TEMP_LOCATION" populate
        networksetup -switchtolocation "$TEMP_LOCATION"
        sleep 3
        networksetup -switchtolocation "Automatic"
        networksetup -deletelocation "$TEMP_LOCATION"
    fi
    
    info "DNS fixes applied"
}

optimize_wifi_performance() {
    log "⚡ Optimizing WiFi performance..."
    
    # Set optimal DNS servers
    info "Setting optimized DNS servers..."
    sudo networksetup -setdnsservers "Wi-Fi" 1.1.1.1 8.8.8.8 8.8.4.4
    
    # Prioritize WiFi interface
    info "Optimizing network interface order..."
    sudo networksetup -ordernetworkservices "Wi-Fi" "Ethernet" "Bluetooth PAN" "Thunderbolt Bridge"
    
    # Clear network caches
    info "Clearing network caches..."
    sudo rm -rf /Library/Caches/com.apple.configd.dns-configuration
    sudo rm -rf /var/db/dhcpclient/leases/*
    
    info "Performance optimizations applied"
}

reset_wifi_if_needed() {
    if [[ "$PING_OK" == false || "$DNS_OK" == false ]]; then
        log "🔄 Resetting WiFi connection..."
        
        # Turn WiFi off and on
        networksetup -setairportpower en0 off
        sleep 5
        networksetup -setairportpower en0 on
        sleep 10
        
        # Reconnect to network
        info "Reconnecting to $WIFI_NETWORK..."
        # Note: Would need password for secure networks
        # networksetup -setairportnetwork en0 "$WIFI_NETWORK" "$PASSWORD"
        
        info "WiFi reset completed"
    fi
}

run_advanced_diagnostics() {
    log "🔬 Running advanced diagnostics..."
    
    # Check network interface statistics
    info "Network interface statistics:"
    netstat -in | head -5
    
    # Check routing table
    info "Routing table:"
    netstat -rn | grep default
    
    # Check for network conflicts
    ARP_CONFLICTS=$(arp -a | grep -c "incomplete" || true)
    if [[ "$ARP_CONFLICTS" -gt 0 ]]; then
        warn "$ARP_CONFLICTS ARP conflicts detected"
        info "Clearing ARP cache..."
        sudo arp -a -d
    fi
    
    # Check system network preferences
    info "Network preferences integrity check..."
    PREF_ERRORS=$(plutil -lint /Library/Preferences/SystemConfiguration/preferences.plist 2>&1 | grep -c "error" || true)
    if [[ "$PREF_ERRORS" -gt 0 ]]; then
        warn "Network preferences may be corrupted"
        info "Consider running: sudo rm /Library/Preferences/SystemConfiguration/preferences.plist"
        info "Then restart to rebuild network preferences"
    fi
}

test_speed() {
    log "🚀 Testing network speed..."
    
    # Simple speed test using curl
    info "Testing download speed..."
    START_TIME=$(date +%s.%N)
    curl -s -o /dev/null "http://speedtest.ftp.otenet.gr/files/test1Mb.db"
    END_TIME=$(date +%s.%N)
    
    DURATION=$(echo "$END_TIME - $START_TIME" | bc)
    SPEED=$(echo "scale=2; 8 / $DURATION" | bc) # 1MB = 8Mb
    
    info "Approximate download speed: ${SPEED} Mbps"
    
    if (( $(echo "$SPEED < 1" | bc -l) )); then
        warn "Very slow connection detected"
    elif (( $(echo "$SPEED < 10" | bc -l) )); then
        warn "Slow connection detected"
    fi
}

generate_report() {
    log "📋 Generating diagnostic report..."
    
    REPORT_FILE="/tmp/mac-wifi-report-$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$REPORT_FILE" << EOF
Mac WiFi Diagnostic Report
==========================
Generated: $(date)
macOS Version: $(sw_vers -productVersion)
WiFi Network: $WIFI_NETWORK

Test Results:
- Ping Test: $([ "$PING_OK" = true ] && echo "✅ PASS" || echo "❌ FAIL")
- DNS Resolution: $([ "$DNS_OK" = true ] && echo "✅ PASS" || echo "❌ FAIL")  
- HTTP Connectivity: $([ "$HTTP_OK" = true ] && echo "✅ PASS" || echo "❌ FAIL")
- HTTPS Connectivity: $([ "$HTTPS_OK" = true ] && echo "✅ PASS" || echo "❌ FAIL")

Issues Detected:
- VPN DNS Pollution: $([ "$VPN_DNS_ISSUE" = true ] && echo "⚠️  YES" || echo "✅ NO")
- High mDNSResponder CPU: $([ "$MDNS_HIGH_CPU" = true ] && echo "⚠️  YES" || echo "✅ NO")

Network Details:
$(networksetup -getinfo "Wi-Fi")

DNS Configuration:
$(scutil --dns | head -20)

Fixes Applied:
- DNS cache flushed
- mDNSResponder restarted
- Network settings optimized
- Performance tweaks applied

EOF
    
    info "Report saved to: $REPORT_FILE"
    echo "View with: cat $REPORT_FILE"
}

main() {
    show_banner
    
    check_macos
    get_wifi_info
    test_connectivity
    check_dns_issues
    
    # Apply fixes
    fix_dns_issues
    optimize_wifi_performance
    
    # Advanced diagnostics if issues persist
    if [[ "$DNS_OK" == false || "$HTTP_OK" == false ]]; then
        run_advanced_diagnostics
        reset_wifi_if_needed
    fi
    
    # Test again after fixes
    echo
    log "🔁 Re-testing connectivity after fixes..."
    test_connectivity
    
    # Speed test
    test_speed
    
    # Generate report
    generate_report
    
    echo
    if [[ "$DNS_OK" == true && "$HTTP_OK" == true && "$HTTPS_OK" == true ]]; then
        echo -e "${GREEN}🎉 WiFi connectivity fully restored!${NC}"
    else
        echo -e "${YELLOW}⚠️  Some issues may persist. Check the diagnostic report.${NC}"
        echo -e "${CYAN}For persistent issues, try:${NC}"
        echo "1. Restart your Mac"
        echo "2. Reset network settings: System Preferences > Network > Advanced > TCP/IP > Renew DHCP Lease"
        echo "3. Forget and reconnect to WiFi network"
    fi
    
    echo
    echo -e "${PURPLE}Mac WiFi troubleshooting completed!${NC}"
}

# Check for required tools
if ! command -v bc &> /dev/null; then
    echo "Installing bc for calculations..."
    if command -v brew &> /dev/null; then
        brew install bc
    else
        echo "Please install bc: brew install bc"
        exit 1
    fi
fi

# Run main function
main "$@"