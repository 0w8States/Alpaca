# Ubuntu Server Setup - Quick Reference

## ⚠️ What Caused Your Lockout

**fail2ban banned your IP** because:
- You set `maxretry = 3` (too strict)
- Any auth failures → IP ban → connection timeout
- No IP whitelist = can ban yourself

## ✅ Correct Order (IMPORTANT!)

```
1. Create user + sudo
2. Set up SSH keys
3. ⚠️ TEST LOGIN ⚠️
4. Configure UFW firewall
5. Install fail2ban WITH IP whitelist
6. ⚠️ TEST AGAIN ⚠️
7. Harden SSH config
8. ⚠️ FINAL TEST ⚠️
```

## 🚀 Quick Start

### Option 1: Use the Automated Script (Recommended)
```bash
# On your server as root
bash ubuntu-secure-setup.sh
```
Includes safety checks and automatic IP whitelisting!

### Option 2: Manual Setup

**Step 1: Create User**
```bash
sudo adduser johnh
sudo usermod -aG sudo johnh
```

**Step 2: SSH Keys**
```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys  # Paste public key
chmod 600 ~/.ssh/authorized_keys
```

**Step 3: TEST** ⚠️
```bash
ssh johnh@your-server  # Must work before continuing!
```

**Step 4: Firewall**
```bash
sudo ufw allow 22/tcp
sudo ufw enable
```

**Step 5: fail2ban (WITH WHITELIST!)**
```bash
sudo apt install fail2ban
```
Edit `/etc/fail2ban/jail.local`:
```ini
[DEFAULT]
ignoreip = 127.0.0.1/8 YOUR.IP.HERE  # ← ADD THIS!
maxretry = 5

[sshd]
enabled = true
maxretry = 5
```

**Step 6: SSH Hardening**
```bash
sudo nano /etc/ssh/sshd_config
```
```
PermitRootLogin no
PasswordAuthentication no
```
```bash
sudo sshd -t  # Test first!
sudo systemctl restart sshd
```

## 🔧 Emergency Commands

**Unban yourself from fail2ban:**
```bash
sudo fail2ban-client set sshd unbanip YOUR.IP
```

**Check who's banned:**
```bash
sudo fail2ban-client status sshd
```

**Restore SSH config:**
```bash
sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
sudo systemctl restart sshd
```

## 🎯 Critical Rules

1. **ALWAYS test before moving to next step**
2. **WHITELIST your IP in fail2ban**
3. **Keep one SSH session open until confirmed working**
4. **Start with maxretry = 5, not 3**
5. **Backup configs before changes**

## 📋 Pre-flight Checklist

Before starting:
- [ ] Have console access ready (in case of lockout)
- [ ] Know your current IP address
- [ ] Have SSH public key ready
- [ ] Have snapshot/backup of server

During setup:
- [ ] Tested new user login before disabling root
- [ ] Whitelisted IP in fail2ban
- [ ] Tested SSH after each major change
- [ ] Kept one session open during SSH restart

## 🆘 Error Types

- **"Connection timed out"** → Firewall or fail2ban ban
- **"Connection refused"** → SSH service down
- **"Permission denied"** → SSH key/auth issue
- **"No route to host"** → Network problem

## 📁 Files Created

- `ubuntu-secure-setup.sh` - Automated setup script
- `UBUNTU_SETUP_GUIDE.md` - Detailed guide
- `QUICK_REFERENCE.md` - This file

---
**Remember:** Test → Test → Test!
