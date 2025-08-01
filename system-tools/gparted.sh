#!/bin/bash
set -e

ISO_NAME="gparted-live-1.7.0-8-amd64.iso"

echo "📁 Checking for ISO on Desktop..."

if [ ! -f ~/Desktop/$ISO_NAME ]; then
    echo "❌ ISO not found at ~/Desktop/$ISO_NAME"
    exit 1
fi

echo "💽 Insert your USB drive and press ENTER..."
read -r

diskutil list external
echo ""
read -p "🔌 Enter the USB disk identifier (e.g., disk4): " DISK_ID
DEV="/dev/$DISK_ID"

if ! diskutil info "$DEV" > /dev/null 2>&1; then
    echo "❌ Disk $DEV not found."
    exit 1
fi

echo "⚠️ WARNING: This will ERASE ALL DATA on $DEV. Type YES to continue:"
read -r CONFIRM
if [[ "$CONFIRM" != "YES" ]]; then
    echo "❌ Cancelled."
    exit 1
fi

echo "🧽 Unmounting $DEV..."
diskutil unmountDisk "$DEV"

echo "🔥 Flashing ISO to USB... (may take several minutes)"
sudo dd if=~/Desktop/$ISO_NAME of="$DEV" bs=4m status=progress conv=sync

echo "✅ Done. Ejecting USB..."
diskutil eject "$DEV"

echo "🚀 GParted Live USB is now ready!"
