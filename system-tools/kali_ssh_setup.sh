#!/bin/bash
# Kali SSH Setup - Complete fix for Live ISO
# Fixes common SSH authentication issues

set -e

echo "=== Kali SSH Setup ==="
echo "Setting up SSH with password authentication..."

# Create user if doesn't exist
if ! id -u daniel >/dev/null 2>&1; then
    useradd -m -s /bin/bash daniel
    echo "✅ User 'daniel' created"
fi

# Set password and sudo
echo "daniel:werds" | chpasswd
usermod -aG sudo daniel 2>/dev/null || usermod -aG wheel daniel 2>/dev/null

# Backup SSH config
SSH_CONFIG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.backup.$(date +%s)"
cp "$SSH_CONFIG" "$BACKUP"

# Fix SSH configuration
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' "$SSH_CONFIG"
sed -i 's/^PasswordAuthentication no/#PasswordAuthentication no/' "$SSH_CONFIG"
sed -i 's/^#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication yes/' "$SSH_CONFIG"
sed -i 's/^ChallengeResponseAuthentication no/#ChallengeResponseAuthentication no/' "$SSH_CONFIG"
sed -i 's/^UsePAM no/UsePAM yes/' "$SSH_CONFIG"
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' "$SSH_CONFIG"
sed -i 's/^PermitRootLogin no/#PermitRootLogin no/' "$SSH_CONFIG"
sed -i '/^AuthenticationMethods/d' "$SSH_CONFIG"

# Ensure settings are set
if ! grep -q "^PasswordAuthentication yes" "$SSH_CONFIG"; then
    echo "PasswordAuthentication yes" >> "$SSH_CONFIG"
fi
if ! grep -q "^ChallengeResponseAuthentication yes" "$SSH_CONFIG"; then
    echo "ChallengeResponseAuthentication yes" >> "$SSH_CONFIG"
fi
if ! grep -q "^UsePAM yes" "$SSH_CONFIG"; then
    echo "UsePAM yes" >> "$SSH_CONFIG"
fi

# Fix PAM if exists
if [ -f /etc/pam.d/sshd ]; then
    sed -i 's/^auth.*pam_unix.so.*nullok_secure/# &/' /etc/pam.d/sshd 2>/dev/null || true
fi

# Restart SSH
systemctl restart ssh 2>/dev/null || service ssh restart 2>/dev/null || {
    systemctl start ssh 2>/dev/null || service ssh start 2>/dev/null || true
}

# Get current IP
sleep 2
CURRENT_IP=$(hostname -I | awk '{print $1}' | head -1)
if [ -z "$CURRENT_IP" ]; then
    CURRENT_IP="[YOUR_IP]"
fi

echo ""
echo "=== SSH Setup Complete ==="
echo "Connect: ssh daniel@$CURRENT_IP"
echo "Password: werds"
echo ""
echo "Test: ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 daniel@$CURRENT_IP 'echo ✅'"
echo ""
echo "Backup: $BACKUP"