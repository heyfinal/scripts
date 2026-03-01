#!/bin/bash
# Minimal Kali SSH Setup - One-liner version
id -u daniel >/dev/null 2>&1 || useradd -m -s /bin/bash daniel
echo "daniel:werds" | chpasswd
usermod -aG sudo daniel 2>/dev/null || usermod -aG wheel daniel 2>/dev/null
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/; s/#PermitRootLogin prohibit-password/PermitRootLogin yes/; s/^PasswordAuthentication no/#PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh 2>/dev/null || service ssh restart
echo "✅ SSH ready: ssh daniel@172.16.226.128 (pw: werds)"
echo "Test: ssh -o ConnectTimeout=3 daniel@172.16.226.128 'echo ✅'"