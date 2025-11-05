# Ubuntu Server Security Setup - Corrected Instructions

## Prerequisites
- DigitalOcean droplet created with SSH key for root user
- SSH access to the server as root

---

## 1. Create New User Account

```bash
# Create new user
sudo adduser johnh

# Add user to sudo group
sudo usermod -aG sudo johnh
```

---

## 2. Set Up SSH Key Authentication for New User

**CRITICAL STEP - Do this BEFORE hardening SSH!**

```bash
# Copy root's SSH authorized_keys to the new user
sudo mkdir -p /home/johnh/.ssh
sudo cp /root/.ssh/authorized_keys /home/johnh/.ssh/authorized_keys
sudo chown -R johnh:johnh /home/johnh/.ssh
sudo chmod 700 /home/johnh/.ssh
sudo chmod 600 /home/johnh/.ssh/authorized_keys
```

---

## 3. TEST NEW USER CONNECTION

**DO NOT SKIP THIS STEP!**

Open a NEW terminal window (keep your root session open) and test:

```bash
# Test SSH connection
ssh johnh@packages.beckhoff-usa-community.com

# Verify sudo access
sudo ls -la /root
```

If this doesn't work, **DO NOT PROCEED**. Debug the SSH key setup first.

---

## 4. Security Hardening

### 4.1 UFW Firewall Configuration

```bash
# Install UFW
sudo apt install -y ufw

# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (CRITICAL - do this first!)
sudo ufw allow 22/tcp comment 'SSH'

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# Enable firewall
sudo ufw enable

# Verify status
sudo ufw status verbose
```

---

### 4.2 fail2ban Installation

```bash
# Install fail2ban
sudo apt install -y fail2ban

# Create local configuration
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Edit configuration
sudo nano /etc/fail2ban/jail.local
```

**Key settings to configure in `/etc/fail2ban/jail.local`:**

```ini
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

# CRITICAL: Add your IP address here to prevent self-bans!
# Find your IP: curl ifconfig.me (from your local machine)
ignoreip = 127.0.0.1/8 ::1 YOUR.IP.ADDRESS.HERE

[sshd]
enabled = true
port    = ssh
maxretry = 5
bantime = 3600

[nginx-http-auth]
enabled = true
port    = http,https
logpath = /var/log/nginx/error.log
```

**Start fail2ban:**

```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
sudo fail2ban-client status
```

---

### 4.3 Automatic Security Updates

```bash
# Install unattended-upgrades
sudo apt install -y unattended-upgrades

# Configure unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Edit configuration
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

**Ensure these settings:**

```conf
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
```

---

### 4.4 SSH Hardening

**IMPORTANT: Only do this AFTER confirming johnh can log in with SSH key!**

```bash
# Backup SSH config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Edit configuration
sudo nano /etc/ssh/sshd_config
```

**Recommended settings:**

```sshd_config
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
```

**Test and restart SSH:**

```bash
# Test configuration for errors
sudo sshd -t

# If test passes, restart SSH
sudo systemctl restart sshd
```

---

## 5. FINAL VERIFICATION

**Keep your current SSH session open!**

In a NEW terminal:

```bash
# Test connection as johnh
ssh johnh@packages.beckhoff-usa-community.com

# Verify root login is disabled (should fail)
ssh root@packages.beckhoff-usa-community.com
```

Expected results:
- johnh login: ✓ Success
- root login: ✗ Permission denied

---

## Emergency Recovery

If you get locked out:

### Unban your IP from fail2ban:
```bash
# Via DigitalOcean console access
sudo fail2ban-client status sshd
sudo fail2ban-client set sshd unbanip YOUR.IP.ADDRESS
```

### Restore SSH config:
```bash
# Via DigitalOcean console access
sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### Check SSH service:
```bash
sudo systemctl status sshd
sudo journalctl -u sshd -n 50
```

---

## Summary of Changes from Original Instructions

### Added:
1. **Step 2: SSH Key Setup** - Copy SSH keys from root to johnh
2. **Step 3: Mandatory testing** - Verify johnh can log in BEFORE hardening
3. **ignoreip in fail2ban** - Whitelist your IP to prevent self-bans
4. **Changed maxretry to 5** - Less aggressive ban policy (was 3)
5. **sshd -t test** - Validate SSH config before restart
6. **Final verification step** - Confirm everything works

### Why These Changes Matter:
- **Without SSH key setup**: johnh can't log in after PasswordAuthentication=no
- **Without ignoreip**: fail2ban can ban your IP, causing timeout
- **Without testing**: You won't know there's a problem until you're locked out
- **Without sshd -t**: Invalid SSH config can prevent sshd from starting

---

## Checklist

Before starting:
- [ ] Have DigitalOcean console access ready
- [ ] Know your current IP address (run `curl ifconfig.me` locally)
- [ ] Have snapshot/backup of droplet

During setup:
- [ ] Created user johnh with sudo privileges
- [ ] Copied SSH keys from root to johnh
- [ ] **TESTED johnh login with SSH key - IT WORKS**
- [ ] Configured UFW firewall
- [ ] Added your IP to fail2ban ignoreip list
- [ ] Started fail2ban
- [ ] **TESTED again - no bans**
- [ ] Backed up sshd_config
- [ ] Modified sshd_config
- [ ] Ran `sudo sshd -t` - no errors
- [ ] Restarted sshd
- [ ] **FINAL TEST - johnh works, root denied**

---

**Remember:** Test after EVERY major change! Keep one SSH session open until you confirm the new setup works.
