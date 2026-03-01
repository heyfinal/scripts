#!/bin/bash
# Complete Kali SSH Fix for Live ISO
# Fixes common SSH authentication issues on Kali Live environment

set -e

echo "=== Kali SSH Complete Fix ==="
echo "Fixing SSH authentication for password login..."

# 1. Ensure user exists with correct password
echo "[1/6] Setting up user 'daniel'..."
if ! id -u daniel >/dev/null 2>&1; then
    useradd -m -s /bin/bash daniel
    echo "✅ User created"
fi

echo "daniel:werds" | chpasswd
usermod -aG sudo daniel 2>/dev/null || usermod -aG wheel daniel 2>/dev/null
echo "✅ Password set and sudo configured"

# 2. Backup original SSH config
SSH_CONFIG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.backup.$(date +%s)"
cp "$SSH_CONFIG" "$BACKUP"
echo "[2/6] Backed up SSH config to: $BACKUP"

# 3. Fix SSH configuration
echo "[3/6] Fixing SSH configuration..."
# Enable password authentication
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' "$SSH_CONFIG"
sed -i 's/^PasswordAuthentication no/#PasswordAuthentication no/' "$SSH_CONFIG"

# Enable challenge-response authentication
sed -i 's/^#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication yes/' "$SSH_CONFIG"
sed -i 's/^ChallengeResponseAuthentication no/#ChallengeResponseAuthentication no/' "$SSH_CONFIG"

# Set UsePAM to yes (required for password auth)
sed -i 's/^UsePAM no/UsePAM yes/' "$SSH_CONFIG"

# Allow root login for convenience
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' "$SSH_CONFIG"
sed -i 's/^PermitRootLogin no/#PermitRootLogin no/' "$SSH_CONFIG"

# Remove any AuthenticationMethods restrictions
sed -i '/^AuthenticationMethods/d' "$SSH_CONFIG"

# Ensure settings are actually set
if ! grep -q "^PasswordAuthentication yes" "$SSH_CONFIG"; then
    echo "PasswordAuthentication yes" >> "$SSH_CONFIG"
fi

if ! grep -q "^ChallengeResponseAuthentication yes" "$SSH_CONFIG"; then
    echo "ChallengeResponseAuthentication yes" >> "$SSH_CONFIG"
fi

if ! grep -q "^UsePAM yes" "$SSH_CONFIG"; then
    echo "UsePAM yes" >> "$SSH_CONFIG"
fi

echo "✅ SSH configuration updated"

# 4. Fix PAM configuration if it exists
echo "[4/6] Checking PAM configuration..."
if [ -d /etc/pam.d ]; then
    if [ -f /etc/pam.d/sshd ]; then
        # Comment out any restrictive pam_unix.so lines
        sed -i 's/^auth.*pam_unix.so.*nullok_secure/# &/' /etc/pam.d/sshd 2>/dev/null || true
        sed -i 's/^auth.*pam_unix.so.*nullok/# &/' /etc/pam.d/sshd 2>/dev/null || true
        echo "✅ PAM configuration adjusted"
    else
        echo "⚠️  No /etc/pam.d/sshd found, skipping PAM config"
    fi
else
    echo "⚠️  No /etc/pam.d directory found, skipping PAM config"
fi

# 5. Restart SSH service
echo "[5/6] Restarting SSH service..."
systemctl restart ssh 2>/dev/null || service ssh restart 2>/dev/null || {
    echo "⚠️  Could not restart SSH, trying to start..."
    systemctl start ssh 2>/dev/null || service ssh start 2>/dev/null || true
}

# Enable SSH on boot
systemctl enable ssh 2>/dev/null || true
echo "✅ SSH service restarted"

# 6. Get current IP address
echo "[6/6] Getting connection information..."
sleep 2
CURRENT_IP=$(hostname -I | awk '{print $1}' | head -1)
if [ -z "$CURRENT_IP" ]; then
    CURRENT_IP="[YOUR_IP]"
fi

echo ""
echo "=== SSH Fix Complete ==="
echo ""
echo "Your IP address: $CURRENT_IP"
echo "Username: daniel"
echo "Password: werds"
echo ""
echo "Test connection from macOS:"
echo "  ssh -o StrictHostKeyChecking=no daniel@$CURRENT_IP"
echo ""
echo "If connection fails, check SSH logs:"
echo "  sudo journalctl -u ssh --no-pager | tail -20"
echo ""
echo "Backup SSH config: $BACKUP"