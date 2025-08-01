#!/bin/bash

# Samsung SSD Hardware Detection & Troubleshooting Script
# For iMac 13.2 - Detects missing/unrecognized Samsung SSDs
# Run this BEFORE the main recovery script if SSD is not detected

set +e  # Don't exit on errors - we want to continue checking

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

print_debug() {
    echo -e "${MAGENTA}[DEBUG]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        print_status "Usage: sudo $0"
        exit 1
    fi
}

# Install detection tools if missing
install_detection_tools() {
    print_header "Installing Detection Tools"
    
    TOOLS=("smartmontools" "hdparm" "util-linux" "parted" "gdisk")
    MISSING=()
    
    for tool in "${TOOLS[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$tool"; then
            MISSING+=("$tool")
        fi
    done
    
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        print_status "Installing missing tools: ${MISSING[*]}"
        apt-get update -qq > /dev/null 2>&1
        apt-get install -y "${MISSING[@]}" > /dev/null 2>&1
        print_success "Tools installed"
    else
        print_success "All detection tools available"
    fi
}

# Basic system detection
initial_scan() {
    print_header "Initial System Scan"
    
    print_status "Current block devices:"
    lsblk -f
    
    echo ""
    print_status "All partitions in /proc/partitions:"
    cat /proc/partitions
    
    echo ""
    print_status "Available storage devices:"
    ls -la /dev/sd* /dev/nvme* 2>/dev/null || print_warning "No standard storage devices found"
}

# Deep SATA/NVMe detection
deep_hardware_scan() {
    print_header "Deep Hardware Detection"
    
    print_status "Rescanning SATA buses..."
    for host in /sys/class/scsi_host/host*; do
        if [[ -f "$host/scan" ]]; then
            echo "- - -" > "$host/scan" 2>/dev/null
            print_debug "Rescanned $(basename $host)"
        fi
    done
    
    print_status "Rescanning NVMe devices..."
    echo 1 > /sys/bus/pci/rescan 2>/dev/null || print_debug "PCI rescan not available"
    
    # Wait for detection
    sleep 3
    
    print_status "Post-rescan device list:"
    lsblk -f
    
    echo ""
    print_status "Checking for new devices in dmesg..."
    dmesg | tail -20 | grep -i -E "(sata|nvme|samsung|ata|scsi)" || print_warning "No recent storage device messages"
}

# Check system messages for hardware issues
check_system_messages() {
    print_header "System Hardware Messages"
    
    print_status "Recent SATA/storage messages:"
    dmesg | grep -i -E "(sata|ata[0-9]|sd[a-z])" | tail -10 || print_warning "No SATA messages found"
    
    echo ""
    print_status "Samsung-specific messages:"
    dmesg | grep -i samsung || print_warning "No Samsung device messages found"
    
    echo ""
    print_status "NVMe messages:"
    dmesg | grep -i nvme || print_warning "No NVMe messages found"
    
    echo ""
    print_status "Storage error messages:"
    dmesg | grep -i -E "(error|fail|timeout)" | grep -i -E "(sata|ata|nvme|disk)" | tail -5 || print_success "No recent storage errors"
}

# Try alternative detection methods
alternative_detection() {
    print_header "Alternative Detection Methods"
    
    print_status "Checking smartctl device scan..."
    smartctl --scan 2>/dev/null || print_warning "smartctl scan failed"
    
    echo ""
    print_status "Checking with hdparm..."
    for dev in /dev/sd{a..z}; do
        if [[ -e "$dev" ]]; then
            MODEL=$(hdparm -I "$dev" 2>/dev/null | grep "Model Number" | awk -F: '{print $2}' | xargs)
            if [[ -n "$MODEL" ]]; then
                SIZE=$(lsblk -b -d -o SIZE "$dev" 2>/dev/null | tail -1 | numfmt --to=iec)
                echo "  $dev: $MODEL ($SIZE)"
                if [[ $MODEL =~ [Ss]amsung.*870.*[Ee][Vv][Oo] ]]; then
                    print_success "  ^^^ FOUND SAMSUNG 870 EVO!"
                    FOUND_SAMSUNG="$dev"
                fi
            fi
        fi
    done
    
    echo ""
    print_status "Checking NVMe devices..."
    for nvme in /dev/nvme*n1; do
        if [[ -e "$nvme" ]]; then
            MODEL=$(nvme id-ctrl "$nvme" 2>/dev/null | grep "mn " | awk -F: '{print $2}' | xargs)
            if [[ -n "$MODEL" ]]; then
                SIZE=$(lsblk -b -d -o SIZE "$nvme" 2>/dev/null | tail -1 | numfmt --to=iec)
                echo "  $nvme: $MODEL ($SIZE)"
                if [[ $MODEL =~ [Ss]amsung.*870.*[Ee][Vv][Oo] ]]; then
                    print_success "  ^^^ FOUND SAMSUNG 870 EVO!"
                    FOUND_SAMSUNG="$nvme"
                fi
            fi
        fi
    done
    
    echo ""
    print_status "Parted device scan..."
    parted -l 2>/dev/null | grep -A5 -B2 -i samsung || print_warning "No Samsung devices found in parted"
}

# Check for uninitialized or corrupted drives
check_uninitialized() {
    print_header "Checking for Uninitialized/Corrupted Drives"
    
    print_status "Looking for drives without partition tables..."
    
    for dev in /dev/sd{a..z}; do
        if [[ -e "$dev" ]] && [[ ! "$dev" =~ [0-9]$ ]]; then
            # Check if it has partitions
            PARTITIONS=$(lsblk -n -o NAME "$dev" 2>/dev/null | wc -l)
            SIZE=$(lsblk -b -d -o SIZE "$dev" 2>/dev/null | tail -1 | numfmt --to=iec)
            
            if [[ $PARTITIONS -eq 1 ]]; then
                print_warning "$dev has no partitions (Size: $SIZE) - could be corrupted Samsung SSD"
                
                # Try to read any identifying information
                print_debug "Checking $dev for Samsung signatures..."
                
                # Check for any Samsung strings in first sectors
                if dd if="$dev" bs=512 count=1000 2>/dev/null | strings | grep -i samsung > /dev/null; then
                    print_success "Found Samsung signature in $dev!"
                    FOUND_SAMSUNG="$dev"
                fi
                
                # Try to get model info even from corrupted drive
                MODEL=$(hdparm -I "$dev" 2>/dev/null | grep "Model Number" | awk -F: '{print $2}' | xargs)
                if [[ -n "$MODEL" ]]; then
                    print_status "$dev Model: $MODEL"
                    if [[ $MODEL =~ [Ss]amsung ]]; then
                        print_success "This appears to be your Samsung SSD!"
                        FOUND_SAMSUNG="$dev"
                    fi
                fi
            fi
        fi
    done
    
    # Check NVMe drives without partitions
    for nvme in /dev/nvme*n1; do
        if [[ -e "$nvme" ]]; then
            PARTITIONS=$(lsblk -n -o NAME "$nvme" 2>/dev/null | wc -l)
            SIZE=$(lsblk -b -d -o SIZE "$nvme" 2>/dev/null | tail -1 | numfmt --to=iec)
            
            if [[ $PARTITIONS -eq 1 ]]; then
                print_warning "$nvme has no partitions (Size: $SIZE) - could be corrupted Samsung SSD"
                
                MODEL=$(nvme id-ctrl "$nvme" 2>/dev/null | grep "mn " | awk -F: '{print $2}' | xargs)
                if [[ -n "$MODEL" ]]; then
                    print_status "$nvme Model: $MODEL"
                    if [[ $MODEL =~ [Ss]amsung ]]; then
                        print_success "This appears to be your Samsung SSD!"
                        FOUND_SAMSUNG="$nvme"
                    fi
                fi
            fi
        fi
    done
}

# Force detection and setup if needed
force_detection() {
    print_header "Force Detection and Recovery Setup"
    
    if [[ -n "$FOUND_SAMSUNG" ]]; then
        print_success "Samsung SSD detected at: $FOUND_SAMSUNG"
        
        SIZE=$(lsblk -b -d -o SIZE "$FOUND_SAMSUNG" 2>/dev/null | tail -1 | numfmt --to=iec)
        print_status "Size: $SIZE"
        
        # Try to get more info
        if [[ $FOUND_SAMSUNG =~ /dev/sd ]]; then
            MODEL=$(hdparm -I "$FOUND_SAMSUNG" 2>/dev/null | grep "Model Number" | awk -F: '{print $2}' | xargs)
            SERIAL=$(hdparm -I "$FOUND_SAMSUNG" 2>/dev/null | grep "Serial Number" | awk -F: '{print $2}' | xargs)
        elif [[ $FOUND_SAMSUNG =~ /dev/nvme ]]; then
            MODEL=$(nvme id-ctrl "$FOUND_SAMSUNG" 2>/dev/null | grep "mn " | awk -F: '{print $2}' | xargs)
            SERIAL=$(nvme id-ctrl "$FOUND_SAMSUNG" 2>/dev/null | grep "sn " | awk -F: '{print $2}' | xargs)
        fi
        
        print_status "Model: ${MODEL:-Unknown}"
        print_status "Serial: ${SERIAL:-Unknown}"
        
        echo ""
        print_success "READY FOR RECOVERY!"
        print_status "Use this device in the main recovery script: $FOUND_SAMSUNG"
        
        return 0
    else
        return 1
    fi
}

# Hardware troubleshooting guide
hardware_troubleshooting() {
    print_header "Hardware Troubleshooting Guide for iMac 13.2"
    
    print_error "Samsung 870 EVO SSD not detected"
    echo ""
    print_status "This suggests a hardware connection issue. Try these steps:"
    echo ""
    
    echo "1. POWER DOWN COMPLETELY:"
    echo "   - Shut down iMac"
    echo "   - Unplug power cable for 30 seconds"
    echo ""
    
    echo "2. CHECK INTERNAL CONNECTIONS:"
    echo "   - Remove iMac back panel"
    echo "   - Locate Samsung 870 EVO SSD"
    echo "   - Check SATA data cable connection"
    echo "   - Check SATA power cable connection"
    echo "   - Reseat both cables firmly"
    echo ""
    
    echo "3. TRY DIFFERENT SATA PORT:"
    echo "   - If motherboard has multiple SATA ports"
    echo "   - Try connecting to different port"
    echo ""
    
    echo "4. TEST SSD IN EXTERNAL ENCLOSURE:"
    echo "   - Use USB-to-SATA adapter"
    echo "   - Connect SSD externally"
    echo "   - Boot from Kali USB again"
    echo "   - Run this script to see if detected"
    echo ""
    
    echo "5. CHECK FOR DEAD SSD:"
    echo "   - If no detection in external enclosure"
    echo "   - SSD may be completely failed"
    echo "   - Professional data recovery might be needed"
    echo ""
    
    print_warning "If SSD is detected after hardware fixes, run the main recovery script!"
}

# Create detection report
create_report() {
    print_header "Creating Detection Report"
    
    REPORT_DIR="/tmp/samsung_detection_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$REPORT_DIR"
    
    # Save all detection info
    {
        echo "Samsung SSD Detection Report"
        echo "==========================="
        echo "Date: $(date)"
        echo "System: iMac 13.2"
        echo ""
        
        echo "Block Devices:"
        lsblk -f
        echo ""
        
        echo "Partitions:"
        cat /proc/partitions
        echo ""
        
        echo "Recent dmesg (storage related):"
        dmesg | grep -i -E "(sata|ata|nvme|samsung|scsi)" | tail -20
        echo ""
        
        echo "Available devices:"
        ls -la /dev/sd* /dev/nvme* 2>/dev/null
        echo ""
        
        if [[ -n "$FOUND_SAMSUNG" ]]; then
            echo "SAMSUNG SSD FOUND: $FOUND_SAMSUNG"
        else
            echo "SAMSUNG SSD NOT DETECTED - HARDWARE ISSUE LIKELY"
        fi
        
    } > "$REPORT_DIR/detection_report.txt"
    
    print_success "Detection report saved to: $REPORT_DIR/detection_report.txt"
    export REPORT_DIR
}

# Main function
main() {
    print_header "Samsung 870 EVO SSD Detection Script"
    print_header "iMac 13.2 Hardware Troubleshooting"
    
    print_status "This script will thoroughly scan for your Samsung SSD"
    print_status "Run this BEFORE the main recovery script if SSD not detected"
    
    echo ""
    read -p "Press Enter to start detection scan..."
    
    check_root
    install_detection_tools
    initial_scan
    sleep 2
    deep_hardware_scan
    check_system_messages
    alternative_detection
    check_uninitialized
    
    echo ""
    if force_detection; then
        print_header "SUCCESS - Samsung SSD Found!"
        print_success "Device: $FOUND_SAMSUNG"
        print_status "You can now run the main recovery script with this device"
        
        echo ""
        read -p "Do you want to run the main recovery script now? (y/n): " run_recovery
        if [[ $run_recovery =~ ^[Yy]$ ]]; then
            if [[ -f "/media/*/ssd.sh" ]]; then
                print_status "Launching main recovery script..."
                exec /media/*/ssd.sh
            elif [[ -f "./ssd.sh" ]]; then
                print_status "Launching main recovery script..."
                exec ./ssd.sh
            else
                print_error "Main recovery script (ssd.sh) not found"
                print_status "Please locate and run ssd.sh manually"
            fi
        fi
    else
        print_header "Samsung SSD Not Detected"
        hardware_troubleshooting
        
        echo ""
        print_status "After fixing hardware connections, run this script again:"
        print_status "sudo $0"
    fi
    
    create_report
    
    echo ""
    print_status "Detection complete. Report saved to: $REPORT_DIR"
}

# Initialize variables
FOUND_SAMSUNG=""

# Run main function
main "$@"
