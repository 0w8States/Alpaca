# Ubuntu Server Secure Setup Guide

## What Went Wrong in Your Previous Attempt

Based on your steps, **fail2ban most likely banned your IP address**. Here's why:

### The Problem Chain:
1. You set `maxretry = 3` in fail2ban for SSH
2. You set `PasswordAuthentication no` in SSH config
3. If you made any authentication mistakes (wrong key, tried as root, etc.), you hit the retry limit
4. **fail2ban banned your IP** → Connection timeout

### Why Connection Timeout (Not Auth Failure)?
- **Banned IP** = firewall blocks your packets = timeout
- **Auth failure** = server rejects login = "Permission denied"

## Safe Setup Order

The order matters! Here's the correct sequence:

### 1. Create New User FIRST ✓
```bash
sudo adduser johnh
sudo usermod -aG sudo johnh
```
**Why first:** Need a non-root user before disabling root

### 2. Set Up SSH Keys ✓
```bash
# On server as the new user
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys  # Paste your public key
chmod 600 ~/.ssh/authorized_keys
```
**Why second:** Need working key auth before disabling passwords

### 3. TEST NEW USER CONNECTION ⚠️ CRITICAL
```bash
# From your local machine
ssh johnh@your-server-ip
sudo ls -la /root  # Verify sudo works
```
**DO NOT PROCEED** until this works!

### 4. Configure UFW Firewall
```bash
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw enable
```
**Why now:** Firewall before fail2ban prevents lockouts

### 5. Install fail2ban WITH IP WHITELIST ⚠️ CRITICAL
```bash
sudo apt install -y fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```

Edit `/etc/fail2ban/jail.local`:
```ini
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

# CRITICAL: Whitelist your IP!
ignoreip = 127.0.0.1/8 ::1 YOUR.ACTUAL.IP.HERE

[sshd]
enabled = true
port    = ssh
maxretry = 5  # Start with 5, not 3!
bantime = 3600
```

**Why whitelist:** Prevents fail2ban from banning your own IP

### 6. TEST AGAIN
Make 2-3 test connections to ensure fail2ban isn't blocking you.

### 7. Harden SSH (LAST STEP)
```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sudo nano /etc/ssh/sshd_config
```

Apply these settings:
```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
```

Test config and restart:
```bash
sudo sshd -t  # Test for errors
sudo systemctl restart sshd
```

**Why last:** If something goes wrong, you can still get in with the working setup

### 8. FINAL TEST
Open a NEW terminal and test connection before closing your current session!

## Using the Automated Script

I've created `ubuntu-secure-setup.sh` that does all of this safely:

```bash
# Copy the script to your server
scp ubuntu-secure-setup.sh root@your-server:/root/

# SSH as root
ssh root@your-server

# Run the script
sudo bash ubuntu-secure-setup.sh
```

The script will:
- ✓ Prompt for new username
- ✓ Set up SSH keys
- ✓ **Force you to test before continuing**
- ✓ Automatically whitelist your current IP in fail2ban
- ✓ Configure everything in the right order
- ✓ Create checkpoints to prevent lockouts
- ✓ Test SSH config before applying

## Emergency Recovery

If you get locked out again:

### If fail2ban banned you:
```bash
# Via console access
sudo fail2ban-client status sshd
sudo fail2ban-client set sshd unbanip YOUR.IP.ADDRESS
```

### If SSH won't start:
```bash
# Check status
sudo systemctl status sshd

# Check config
sudo sshd -t

# Restore backup
sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### If firewall locked you out:
```bash
# Via console access
sudo ufw disable
sudo ufw allow 22/tcp
sudo ufw enable
```

## Key Takeaways

1. **Always test between major changes** - Don't apply everything at once
2. **Whitelist your IP in fail2ban** - Prevents accidental bans
3. **Keep one session open** - Until you confirm new one works
4. **Order matters** - User → Keys → Test → Firewall → fail2ban → SSH hardening
5. **Use the script** - It has built-in safety checks

## Your Specific Case

For your server at `packages.beckhoff-usa-community.com`:

```bash
# 1. Use the automated script (recommended)
bash ubuntu-secure-setup.sh

# When prompted:
# Username: johnh
# SSH Key: [paste your public key from ~/.ssh/id_rsa.pub]

# The script will detect your IP and whitelist it automatically
```

## Files Included

- `ubuntu-secure-setup.sh` - Automated setup script with safety checks
- `UBUNTU_SETUP_GUIDE.md` - This guide

## Questions?

Common issues:
- **"Connection refused"** → SSH service not running
- **"Connection timed out"** → Firewall blocking or fail2ban banned you
- **"Permission denied"** → SSH key not set up correctly
- **"No route to host"** → Network/routing issue

Good luck with your setup! Remember: **test after each major change!**
