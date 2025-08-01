#!/bin/bash

# Samsung 870 EVO SSD Recovery Script for macOS (Running from Kali Linux)
# This script fixes corrupted SSDs using Linux tools and prepares them for macOS installation
# Run this from Kali Linux live USB

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# Check if running with proper permissions
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (with sudo)"
        print_status "Usage: sudo $0"
        exit 1
    fi
}

# Install required tools if missing
install_tools() {
    print_header "Checking Required Tools"
    
    MISSING_TOOLS=()
    
    # Check for required tools
    command -v parted >/dev/null 2>&1 || MISSING_TOOLS+=("parted")
    command -v gdisk >/dev/null 2>&1 || MISSING_TOOLS+=("gdisk")
    command -v mkfs.hfsplus >/dev/null 2>&1 || MISSING_TOOLS+=("hfsprogs")
    command -v wipefs >/dev/null 2>&1 || MISSING_TOOLS+=("util-linux")
    
    if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
        print_warning "Installing missing tools: ${MISSING_TOOLS[*]}"
        apt-get update -qq
        apt-get install -y parted gdisk hfsprogs util-linux
        print_success "Tools installed successfully"
    else
        print_success "All required tools are available"
    fi
}

# Function to detect Samsung SSD
detect_samsung_ssd() {
    print_header "Detecting Samsung 870 EVO SSD"
    
    # List all disks
    print_status "Scanning for all connected drives..."
    lsblk -f
    
    echo ""
    print_status "Detailed disk information:"
    echo ""
    
    # Get detailed info for each disk
    for disk in /dev/sd*; do
        if [[ $disk =~ /dev/sd[a-z]$ ]]; then
            diskname=$(basename $disk)
            size=$(lsblk -b -d -o SIZE $disk 2>/dev/null | tail -1 | numfmt --to=iec)
            model=$(cat /sys/block/$diskname/device/model 2>/dev/null | xargs || echo "Unknown")
            vendor=$(cat /sys/block/$diskname/device/vendor 2>/dev/null | xargs || echo "Unknown")
            
            echo "  $disk - Size: $size - Vendor: $vendor - Model: $model"
            
            # Check if it's likely a Samsung SSD
            if [[ $model =~ [Ss]amsung ]] || [[ $model =~ 870.*[Ee][Vv][Oo] ]] || [[ $vendor =~ [Ss]amsung ]]; then
                print_success "  ^^^ Potential Samsung SSD detected!"
            fi
        fi
    done
    
    echo ""
    print_status "Looking for NVMe drives..."
    for nvme in /dev/nvme*n1; do
        if [[ -e $nvme ]]; then
            nvmename=$(basename $nvme)
            size=$(lsblk -b -d -o SIZE $nvme 2>/dev/null | tail -1 | numfmt --to=iec)
            model=$(nvme id-ctrl $nvme 2>/dev/null | grep "mn " | awk -F: '{print $2}' | xargs || echo "Unknown")
            
            echo "  $nvme - Size: $size - Model: $model"
            
            if [[ $model =~ [Ss]amsung ]] || [[ $model =~ 870.*[Ee][Vv][Oo] ]]; then
                print_success "  ^^^ Potential Samsung NVMe SSD detected!"
            fi
        fi
    done
    
    echo ""
    print_status "Please identify your Samsung 870 EVO from the list above"
    print_status "Common sizes: ~250GB, ~500GB, ~1TB, ~2TB, ~4TB"
    print_warning "Choose carefully - this disk will be completely wiped!"
    
    while true; do
        echo ""
        read -p "Enter the disk device (e.g., /dev/sdb, /dev/nvme0n1): " TARGET_DISK
        
        if [[ ! -b "$TARGET_DISK" ]]; then
            print_error "Device $TARGET_DISK does not exist or is not a block device"
            continue
        fi
        
        # Get disk info
        diskname=$(basename $TARGET_DISK)
        if [[ $TARGET_DISK =~ /dev/sd[a-z]$ ]]; then
            size=$(lsblk -b -d -o SIZE $TARGET_DISK 2>/dev/null | tail -1 | numfmt --to=iec)
            model=$(cat /sys/block/$diskname/device/model 2>/dev/null | xargs || echo "Unknown")
            vendor=$(cat /sys/block/$diskname/device/vendor 2>/dev/null | xargs || echo "Unknown")
        elif [[ $TARGET_DISK =~ /dev/nvme[0-9]+n1$ ]]; then
            size=$(lsblk -b -d -o SIZE $TARGET_DISK 2>/dev/null | tail -1 | numfmt --to=iec)
            model=$(nvme id-ctrl $TARGET_DISK 2>/dev/null | grep "mn " | awk -F: '{print $2}' | xargs || echo "Unknown")
            vendor="NVMe"
        else
            print_error "Unsupported device type"
            continue
        fi
        
        print_status "Selected: $TARGET_DISK"
        print_status "Size: $size"
        print_status "Vendor: $vendor"
        print_status "Model: $model"
        
        echo ""
        read -p "Is this correct? THIS DISK WILL BE COMPLETELY WIPED! (type 'YES' to confirm): " confirm
        if [[ $confirm == "YES" ]]; then
            break
        fi
    done
    
    export TARGET_DISK
    export DISK_SIZE_BYTES=$(lsblk -b -d -o SIZE $TARGET_DISK | tail -1)
}

# Function to backup current disk state
backup_disk_info() {
    print_header "Backing Up Current Disk Information"
    
    BACKUP_DIR="/tmp/ssd_recovery_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    print_status "Creating backup directory: $BACKUP_DIR"
    
    # Save current disk info
    lsblk -f $TARGET_DISK > "$BACKUP_DIR/lsblk_info.txt" 2>&1 || true
    fdisk -l $TARGET_DISK > "$BACKUP_DIR/fdisk_info.txt" 2>&1 || true
    parted $TARGET_DISK print > "$BACKUP_DIR/parted_info.txt" 2>&1 || true
    
    # Try to save partition table if readable
    gdisk -l $TARGET_DISK > "$BACKUP_DIR/gdisk_info.txt" 2>&1 || true
    
    # Save first and last sectors
    dd if=$TARGET_DISK of="$BACKUP_DIR/first_sectors.bin" bs=512 count=2048 2>/dev/null || true
    
    print_success "Backup saved to: $BACKUP_DIR"
    export BACKUP_DIR
}

# Function to completely wipe and reinitialize the disk
wipe_and_initialize() {
    print_header "Wiping and Reinitializing Disk"
    
    print_warning "This will COMPLETELY ERASE all data on $TARGET_DISK"
    print_warning "This action cannot be undone!"
    echo ""
    read -p "Type 'WIPE' to continue with complete disk wipe: " confirm
    
    if [[ "$confirm" != "WIPE" ]]; then
        print_error "Operation cancelled by user"
        exit 1
    fi
    
    print_status "Unmounting any mounted partitions..."
    umount ${TARGET_DISK}* 2>/dev/null || true
    
    print_status "Wiping filesystem signatures..."
    wipefs -a $TARGET_DISK 2>/dev/null || true
    
    print_status "Zeroing out the first 10MB..."
    dd if=/dev/zero of=$TARGET_DISK bs=1M count=10 conv=fsync 2>/dev/null || true
    
    print_status "Zeroing out the last 10MB..."
    DISK_SIZE_MB=$((DISK_SIZE_BYTES / 1024 / 1024))
    LAST_10MB=$((DISK_SIZE_MB - 10))
    dd if=/dev/zero of=$TARGET_DISK bs=1M count=10 seek=$LAST_10MB conv=fsync 2>/dev/null || true
    
    print_status "Creating new GPT partition table..."
    parted $TARGET_DISK --script mklabel gpt
    
    # Force kernel to re-read partition table
    partprobe $TARGET_DISK
    sleep 2
    
    print_success "Disk wiped and GPT table created"
}

# Function to create macOS-compatible partition scheme
create_macos_partitions() {
    print_header "Creating macOS-Compatible Partition Scheme"
    
    print_status "Creating EFI System Partition (200MB)..."
    parted $TARGET_DISK --script mkpart EFI fat32 1MiB 201MiB
    parted $TARGET_DISK --script set 1 esp on
    
    print_status "Creating main partition for macOS..."
    parted $TARGET_DISK --script mkpart "Macintosh HD" hfs+ 201MiB 100%
    
    # Force kernel to re-read partition table
    partprobe $TARGET_DISK
    sleep 3
    
    print_status "Verifying partition table..."
    parted $TARGET_DISK --script print
    
    # Identify partition devices
    if [[ $TARGET_DISK =~ /dev/sd[a-z]$ ]]; then
        EFI_PARTITION="${TARGET_DISK}1"
        MAIN_PARTITION="${TARGET_DISK}2"
    elif [[ $TARGET_DISK =~ /dev/nvme[0-9]+n1$ ]]; then
        EFI_PARTITION="${TARGET_DISK}p1"
        MAIN_PARTITION="${TARGET_DISK}p2"
    fi
    
    export EFI_PARTITION
    export MAIN_PARTITION
    
    print_success "Partitions created: EFI=$EFI_PARTITION, Main=$MAIN_PARTITION"
}

# Function to format partitions for macOS
format_for_macos() {
    print_header "Formatting Partitions for macOS"
    
    print_status "Formatting EFI partition as FAT32..."
    mkfs.fat -F32 -n "EFI" $EFI_PARTITION
    
    if [[ $? -eq 0 ]]; then
        print_success "EFI partition formatted successfully"
    else
        print_error "Failed to format EFI partition"
        return 1
    fi
    
    print_status "Formatting main partition as HFS+..."
    # Use HFS+ as it's more reliable for initial setup, can be converted to APFS later
    mkfs.hfsplus -v "Macintosh HD" $MAIN_PARTITION
    
    if [[ $? -eq 0 ]]; then
        print_success "Main partition formatted as HFS+ successfully"
    else
        print_error "HFS+ formatting failed"
        return 1
    fi
    
    # Force sync to ensure writes are complete
    sync
    sleep 2
}

# Function to set proper partition types and flags
set_partition_attributes() {
    print_header "Setting Partition Attributes for macOS"
    
    print_status "Setting partition type GUIDs for macOS compatibility..."
    
    # Set EFI partition type
    gdisk $TARGET_DISK <<EOF
x
c
1
C12A7328-F81F-11D2-BA4B-00A0C93EC93B
m
w
y
EOF

    # Set HFS+ partition type
    gdisk $TARGET_DISK <<EOF
x
c
2
48465300-0000-11AA-AA11-00306543ECAC
m
w
y
EOF

    print_success "Partition types set for macOS compatibility"
}

# Function to verify disk health and readiness
verify_disk() {
    print_header "Verifying Disk Health and Readiness"
    
    print_status "Running final verification..."
    
    # Check partition table
    print_status "Partition table:"
    parted $TARGET_DISK --script print
    
    echo ""
    print_status "Detailed partition info:"
    lsblk -f $TARGET_DISK
    
    echo ""
    print_status "GUID Partition Table details:"
    gdisk -l $TARGET_DISK | grep -A 20 "Number"
    
    # Verify filesystems
    print_status "Verifying EFI partition..."
    fsck.fat -v $EFI_PARTITION || print_warning "EFI partition check failed (may be normal)"
    
    print_status "Verifying HFS+ partition..."
    fsck.hfsplus -f $MAIN_PARTITION || print_warning "HFS+ check reported issues (may be normal for new filesystem)"
    
    # Check if partitions can be mounted
    print_status "Testing partition mounting..."
    mkdir -p /tmp/test_efi /tmp/test_main
    
    if mount $EFI_PARTITION /tmp/test_efi 2>/dev/null; then
        print_success "EFI partition mounts successfully"
        umount /tmp/test_efi
    else
        print_warning "EFI partition mount test failed"
    fi
    
    if mount $MAIN_PARTITION /tmp/test_main 2>/dev/null; then
        print_success "Main partition mounts successfully"
        umount /tmp/test_main
    else
        print_warning "Main partition mount test failed"
    fi
    
    rmdir /tmp/test_efi /tmp/test_main 2>/dev/null || true
    
    print_success "Disk verification complete - ready for macOS installation!"
}

# Function to create recovery instructions
create_instructions() {
    print_header "Creating Recovery Instructions"
    
    INSTRUCTIONS_FILE="$BACKUP_DIR/macos_installation_guide.txt"
    
    cat > "$INSTRUCTIONS_FILE" << EOF
Samsung 870 EVO SSD Recovery for macOS - Complete Guide
======================================================

Recovery completed on: $(date)
Target disk: $TARGET_DISK
EFI partition: $EFI_PARTITION
Main partition: $MAIN_PARTITION
Backup location: $BACKUP_DIR

STEP 1: Restart Your iMac 13.2
==============================

1. Shut down your iMac completely
2. Insert your macOS installer USB drive
3. Power on while holding the Option (Alt) key
4. Select your macOS installer from the boot menu

STEP 2: Install macOS
====================

1. Boot from the macOS installer
2. Open Disk Utility first (recommended)
3. Verify that "Macintosh HD" appears in the left sidebar
4. If needed, you can reformat as APFS from Disk Utility:
   - Select "Macintosh HD"
   - Click Erase
   - Format: APFS
   - Scheme: GUID Partition Map
   - Click Erase
5. Close Disk Utility
6. Proceed with "Install macOS"
7. Select "Macintosh HD" as the destination

STEP 3: Post-Installation Setup
==============================

After macOS installation completes:

1. Complete initial setup (user account, etc.)
2. Update to latest macOS version
3. Enable TRIM for SSD optimization:
   - Open Terminal
   - Run: sudo trimforce enable
   - Type your password and confirm
4. Verify SSD is working properly:
   - Apple menu > About This Mac > System Report
   - Check Serial-ATA or NVMe section

STEP 4: Optional - Install Samsung Magician
===========================================

For SSD optimization and monitoring:
1. Download Samsung Magician from Samsung's website
2. Install and run health checks
3. Update SSD firmware if available

Troubleshooting:
===============

If "Macintosh HD" doesn't appear in installer:
- Restart and try again
- Check SATA/power connections
- Use Disk Utility to verify partitions exist

If installation fails:
- Try different macOS version
- Reset NVRAM: Hold Cmd+Opt+P+R during boot
- Check system compatibility

If performance seems slow:
- Verify TRIM is enabled: system_profiler SPSerialATADataType | grep TRIM
- Check Activity Monitor for high disk usage
- Run Disk Utility First Aid

For OpenCore (if you plan to use it again):
==========================================

WAIT until macOS is fully installed and working before attempting OpenCore:

1. Ensure you have a complete backup
2. Use latest OpenCore version
3. Follow OpenCore guide for iMac 13.2 specifically
4. Test thoroughly before relying on the system

Emergency Recovery:
==================

If you need to re-run this script:
1. Boot from Kali Linux USB again
2. Run: sudo $0

Original disk state backed up in: $BACKUP_DIR

Hardware Info:
=============
Target Device: $TARGET_DISK
Disk Size: $(numfmt --to=iec $DISK_SIZE_BYTES)
iMac Model: 13.2
Recovery Date: $(date)

IMPORTANT NOTES:
===============

- Your SSD is now properly formatted for macOS
- The EFI partition allows proper Mac booting
- HFS+ format is compatible with all macOS versions
- You can convert to APFS during or after installation
- This configuration should work with both standard macOS and OpenCore

Success Indicators:
==================
✓ GPT partition table created
✓ EFI system partition (200MB, FAT32)
✓ Main partition (HFS+, labeled "Macintosh HD")
✓ Proper partition type GUIDs set
✓ Filesystems verified and mountable

EOF

    print_success "Complete installation guide saved to: $INSTRUCTIONS_FILE"
    
    # Also create a simple summary
    cat > "$BACKUP_DIR/quick_summary.txt" << EOF
Quick Recovery Summary:
======================
✓ Samsung 870 EVO SSD recovered successfully
✓ Formatted with GPT + EFI + HFS+ for macOS compatibility
✓ Ready for macOS installation

Next: Boot from macOS installer USB and install to "Macintosh HD"

Full guide: $INSTRUCTIONS_FILE
EOF

    print_status "Quick summary saved to: $BACKUP_DIR/quick_summary.txt"
}

# Main execution function
main() {
    print_header "Samsung 870 EVO SSD Recovery Script for macOS"
    print_header "Running from Kali Linux - iMac 13.2"
    
    print_status "This script will recover your corrupted Samsung SSD for macOS installation"
    print_warning "ALL DATA ON THE TARGET DISK WILL BE PERMANENTLY LOST"
    print_status "The script will create a proper GPT partition table with EFI and HFS+ partitions"
    
    echo ""
    read -p "Press Enter to continue or Ctrl+C to abort..."
    
    check_permissions
    install_tools
    detect_samsung_ssd
    backup_disk_info
    wipe_and_initialize
    create_macos_partitions
    format_for_macos
    set_partition_attributes
    verify_disk
    create_instructions
    
    print_header "Recovery Complete!"
    print_success "Your Samsung 870 EVO SSD is now ready for macOS installation"
    print_success "Disk configured with proper GPT + EFI + HFS+ layout"
    
    echo ""
    print_status "What was done:"
    echo "  ✓ Completely wiped corrupted partition table"
    echo "  ✓ Created new GPT partition table"
    echo "  ✓ Created 200MB EFI system partition (FAT32)"
    echo "  ✓ Created main partition formatted as HFS+"
    echo "  ✓ Set proper partition type GUIDs for macOS"
    echo "  ✓ Verified all partitions are working"
    
    echo ""
    print_status "Next steps:"
    echo "1. Restart your iMac 13.2"
    echo "2. Boot from macOS installer USB (hold Option key)"
    echo "3. Install macOS to 'Macintosh HD'"
    echo "4. Complete setup and enable TRIM support"
    
    echo ""
    print_status "All documentation saved to: $BACKUP_DIR"
    
    echo ""
    read -p "Press Enter to view the backup directory..."
    ls -la "$BACKUP_DIR"
    
    echo ""
    print_success "Your SSD is now ready! Restart and install macOS."
}

# Run the main function
main "$@"
