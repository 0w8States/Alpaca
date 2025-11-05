#!/bin/bash
#
# Ubuntu Server Security Setup Script
# This script safely configures a new Ubuntu server with security hardening
#
# Usage: sudo bash ubuntu-secure-setup.sh
#
# IMPORTANT: Run this while connected as root, and follow all prompts carefully

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Ubuntu Security Setup Script${NC}"
echo -e "${GREEN}================================${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

# ============================================================================
# STEP 1: Create New User
# ============================================================================
echo -e "\n${GREEN}[STEP 1] Creating New User${NC}"
echo -e "${YELLOW}Enter the username for the new user:${NC}"
read -p "Username: " NEW_USER

if id "$NEW_USER" &>/dev/null; then
    echo -e "${YELLOW}User $NEW_USER already exists. Skipping creation.${NC}"
else
    adduser "$NEW_USER"
    usermod -aG sudo "$NEW_USER"
    echo -e "${GREEN}✓ User $NEW_USER created and added to sudo group${NC}"
fi

# ============================================================================
# STEP 2: Set Up SSH Keys
# ============================================================================
echo -e "\n${GREEN}[STEP 2] Setting Up SSH Keys${NC}"
echo -e "${YELLOW}Paste your SSH public key (entire content of id_rsa.pub):${NC}"
echo -e "${YELLOW}Press Enter when done, then Ctrl+D on a new line${NC}"

SSH_KEY=$(cat)

if [ -n "$SSH_KEY" ]; then
    USER_HOME=$(eval echo ~$NEW_USER)
    mkdir -p "$USER_HOME/.ssh"
    echo "$SSH_KEY" > "$USER_HOME/.ssh/authorized_keys"
    chown -R "$NEW_USER:$NEW_USER" "$USER_HOME/.ssh"
    chmod 700 "$USER_HOME/.ssh"
    chmod 600 "$USER_HOME/.ssh/authorized_keys"
    echo -e "${GREEN}✓ SSH key installed for $NEW_USER${NC}"
else
    echo -e "${RED}No SSH key provided. You will need to set this up manually!${NC}"
    read -p "Press Enter to continue..."
fi

# ============================================================================
# CRITICAL CHECKPOINT
# ============================================================================
echo -e "\n${RED}================================${NC}"
echo -e "${RED}CRITICAL CHECKPOINT${NC}"
echo -e "${RED}================================${NC}"
echo -e "${YELLOW}Before continuing, you MUST test the new user account!${NC}\n"
echo -e "From another terminal window, run:"
echo -e "${GREEN}  ssh $NEW_USER@$(hostname -I | awk '{print $1}')${NC}\n"
echo -e "Verify that:"
echo -e "  1. You can connect without a password"
echo -e "  2. You can run: sudo ls -la /root"
echo -e "\n${RED}DO NOT CONTINUE until you've verified this works!${NC}"
read -p "Press Enter once you've confirmed the new user works..."

# ============================================================================
# STEP 3: Get Current IP Address for Whitelisting
# ============================================================================
echo -e "\n${GREEN}[STEP 3] Detecting Your IP Address${NC}"
CURRENT_IP=$(echo $SSH_CLIENT | awk '{print $1}')
if [ -z "$CURRENT_IP" ]; then
    echo -e "${YELLOW}Could not detect your IP automatically.${NC}"
    read -p "Enter your current IP address: " CURRENT_IP
fi
echo -e "${GREEN}Your IP: $CURRENT_IP${NC}"
echo -e "${YELLOW}This IP will be whitelisted in fail2ban to prevent accidental lockout.${NC}"

# ============================================================================
# STEP 4: Update System
# ============================================================================
echo -e "\n${GREEN}[STEP 4] Updating System${NC}"
apt update && apt upgrade -y
echo -e "${GREEN}✓ System updated${NC}"

# ============================================================================
# STEP 5: Configure UFW Firewall
# ============================================================================
echo -e "\n${GREEN}[STEP 5] Configuring UFW Firewall${NC}"
apt install -y ufw

# Set defaults
ufw default deny incoming
ufw default allow outgoing

# Allow SSH FIRST (critical!)
ufw allow 22/tcp comment 'SSH'

# Allow HTTP and HTTPS
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Enable firewall
echo "y" | ufw enable

# Show status
ufw status verbose
echo -e "${GREEN}✓ Firewall configured${NC}"

# ============================================================================
# STEP 6: Install and Configure fail2ban
# ============================================================================
echo -e "\n${GREEN}[STEP 6] Installing and Configuring fail2ban${NC}"
apt install -y fail2ban

# Create local configuration
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
# Ban time in seconds (1 hour)
bantime  = 3600
# Time window to count retries (10 minutes)
findtime = 600
# Max retries before ban
maxretry = 5

# Whitelist your current IP to prevent accidental lockout
ignoreip = 127.0.0.1/8 ::1 $CURRENT_IP

[sshd]
enabled = true
port    = ssh
maxretry = 5
bantime = 3600
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[nginx-http-auth]
enabled = false
port    = http,https
logpath = /var/log/nginx/error.log
EOF

# Start fail2ban
systemctl enable fail2ban
systemctl restart fail2ban

echo -e "${GREEN}✓ fail2ban installed and configured${NC}"
fail2ban-client status

# ============================================================================
# STEP 7: Configure Automatic Security Updates
# ============================================================================
echo -e "\n${GREEN}[STEP 7] Configuring Automatic Security Updates${NC}"
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

cat > /etc/apt/apt.conf.d/50unattended-upgrades-custom << EOF
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
EOF

echo -e "${GREEN}✓ Automatic updates configured${NC}"

# ============================================================================
# STEP 8: SSH Hardening
# ============================================================================
echo -e "\n${GREEN}[STEP 8] Hardening SSH Configuration${NC}"

# Backup original config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d-%H%M%S)

# Create new secure config
cat > /etc/ssh/sshd_config << EOF
# SSH Hardened Configuration
# Generated by ubuntu-secure-setup.sh

# Port and Protocol
Port 22
Protocol 2

# Authentication
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Security Settings
X11Forwarding no
MaxAuthTries 3
MaxSessions 10

# Keep connections alive
ClientAliveInterval 300
ClientAliveCountMax 2

# Other settings
UsePAM yes
PrintMotd no
AcceptEnv LANG LC_*

# Subsystems
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

# Test SSH configuration
echo -e "${YELLOW}Testing SSH configuration...${NC}"
sshd -t

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ SSH configuration is valid${NC}"
else
    echo -e "${RED}✗ SSH configuration has errors! Restoring backup...${NC}"
    cp /etc/ssh/sshd_config.backup.$(date +%Y%m%d)* /etc/ssh/sshd_config
    exit 1
fi

# ============================================================================
# FINAL CHECKPOINT
# ============================================================================
echo -e "\n${RED}================================${NC}"
echo -e "${RED}FINAL CHECKPOINT${NC}"
echo -e "${RED}================================${NC}"
echo -e "${YELLOW}SSH is about to be restarted with new security settings.${NC}"
echo -e "${YELLOW}Keep this session open!${NC}\n"
echo -e "The new settings:"
echo -e "  - Root login: ${RED}DISABLED${NC}"
echo -e "  - Password authentication: ${RED}DISABLED${NC}"
echo -e "  - Only SSH key authentication allowed"
echo -e "\n${YELLOW}Test from another terminal:${NC}"
echo -e "${GREEN}  ssh $NEW_USER@$(hostname -I | awk '{print $1}')${NC}\n"

read -p "Press Enter to restart SSH and apply changes..."

# Restart SSH
systemctl restart sshd

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ SSH restarted successfully${NC}"
else
    echo -e "${RED}✗ SSH failed to restart! Restoring backup...${NC}"
    cp /etc/ssh/sshd_config.backup.$(date +%Y%m%d)* /etc/ssh/sshd_config
    systemctl restart sshd
    exit 1
fi

# ============================================================================
# COMPLETION
# ============================================================================
echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}================================${NC}\n"

echo -e "Summary of changes:"
echo -e "  ✓ User '$NEW_USER' created with sudo privileges"
echo -e "  ✓ SSH key authentication configured"
echo -e "  ✓ UFW firewall enabled (ports 22, 80, 443)"
echo -e "  ✓ fail2ban installed (your IP whitelisted: $CURRENT_IP)"
echo -e "  ✓ Automatic security updates enabled"
echo -e "  ✓ SSH hardened (root disabled, key-only auth)"

echo -e "\n${YELLOW}IMPORTANT REMINDERS:${NC}"
echo -e "  1. Test your connection in a NEW terminal before closing this one!"
echo -e "  2. Your IP ($CURRENT_IP) is whitelisted in fail2ban"
echo -e "  3. SSH backup saved: /etc/ssh/sshd_config.backup.*"
echo -e "  4. If you get locked out, use console access to check fail2ban:"
echo -e "     ${GREEN}sudo fail2ban-client status sshd${NC}"
echo -e "     ${GREEN}sudo fail2ban-client set sshd unbanip YOUR_IP${NC}"

echo -e "\n${GREEN}All done! Stay safe.${NC}\n"
