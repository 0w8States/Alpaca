# Step-by-Step Guide: Enable SFTP on Windows 11

This guide will walk you through setting up an SFTP server on Windows 11 with `C:\SFTP` as the base directory for users.

## Prerequisites

- Windows 11 (Pro, Enterprise, or Education edition recommended)
- Administrator access
- Basic knowledge of PowerShell and Windows administration

---

## Step 1: Install OpenSSH Server

1. **Open Windows Settings**
   - Press `Win + I` to open Settings
   - Or search for "Settings" in the Start menu

2. **Navigate to Optional Features**
   - Go to **Apps** → **Optional features**
   - Or search for "Optional features" in Settings

3. **Add OpenSSH Server**
   - Click **View features** (or **Add a feature**)
   - Scroll down and find **OpenSSH Server**
   - Check the box next to it
   - Click **Install**
   - Wait for the installation to complete (may take a few minutes)

### Alternative: Install via PowerShell

Open PowerShell as Administrator and run:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
```

---

## Step 2: Start and Configure OpenSSH Server Service

1. **Open PowerShell as Administrator**
   - Right-click Start menu → **Terminal (Admin)** or **Windows PowerShell (Admin)**

2. **Start the SSH Server service**

```powershell
Start-Service sshd
```

3. **Set the service to start automatically**

```powershell
Set-Service -Name sshd -StartupType 'Automatic'
```

4. **Verify the service is running**

```powershell
Get-Service sshd
```

You should see the service status as "Running"

---

## Step 3: Configure Windows Firewall

OpenSSH Server typically configures firewall rules automatically, but verify:

1. **Check firewall rule exists**

```powershell
Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP"
```

2. **If the rule doesn't exist, create it**

```powershell
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
```

---

## Step 4: Create the SFTP Base Directory

1. **Create the C:\SFTP directory**

```powershell
New-Item -Path "C:\SFTP" -ItemType Directory -Force
```

2. **Set appropriate permissions**

```powershell
# Grant Users group read and execute permissions
icacls "C:\SFTP" /grant "Users:(OI)(CI)RX"

# Grant Administrators full control
icacls "C:\SFTP" /grant "Administrators:(OI)(CI)F"
```

3. **Create subdirectories for different users (optional)**

```powershell
# Example: Create a directory for a specific user
New-Item -Path "C:\SFTP\username" -ItemType Directory -Force
icacls "C:\SFTP\username" /grant "username:(OI)(CI)F"
```

---

## Step 5: Configure SFTP to Use C:\SFTP as Base Directory

### Option A: Using ChrootDirectory (Recommended for Security)

This restricts users to only access the C:\SFTP directory.

1. **Open the SSH configuration file**

```powershell
notepad C:\ProgramData\ssh\sshd_config
```

2. **Add the following configuration at the end of the file**

```
# SFTP Configuration
Subsystem sftp sftp-server.exe

# Chroot users to C:\SFTP
Match Group "sftp_users"
    ChrootDirectory C:/SFTP
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
```

**Note:** Use forward slashes `/` in the path for OpenSSH configuration.

3. **Create the sftp_users group**

```powershell
net localgroup sftp_users /add /comment:"SFTP Users Group"
```

4. **Save the file and restart the SSH service**

```powershell
Restart-Service sshd
```

### Option B: Set Default Directory per User

Edit each user's home directory to point to C:\SFTP\username:

1. **Open Computer Management**
   - Press `Win + X` → **Computer Management**
   - Navigate to **Local Users and Groups** → **Users**

2. **Right-click on a user** → **Properties**
   - Go to the **Profile** tab
   - Set **Home folder** to: `C:\SFTP\username`

---

## Step 6: Create SFTP User Accounts

1. **Create a new local user account**

```powershell
# Create user
$Password = Read-Host -AsSecureString "Enter password for new user"
New-LocalUser -Name "sftpuser" -Password $Password -FullName "SFTP User" -Description "SFTP access account"
```

2. **Add user to sftp_users group**

```powershell
Add-LocalGroupMember -Group "sftp_users" -Member "sftpuser"
```

3. **Create user's home directory**

```powershell
New-Item -Path "C:\SFTP\sftpuser" -ItemType Directory -Force
icacls "C:\SFTP\sftpuser" /grant "sftpuser:(OI)(CI)F"
```

4. **Set proper permissions for ChrootDirectory**

For ChrootDirectory to work, C:\SFTP must be owned by Administrator and not writable by the user:

```powershell
# Set owner to Administrators
icacls "C:\SFTP" /setowner "Administrators"

# Remove write access for Users
icacls "C:\SFTP" /remove:g "Users"

# Grant read and execute only
icacls "C:\SFTP" /grant "Users:(OI)(CI)RX"
```

---

## Step 7: Test SFTP Connection

1. **Test from Windows (using PowerShell)**

```powershell
sftp sftpuser@localhost
```

2. **Test from another machine**

```bash
sftp sftpuser@<windows-server-ip>
```

3. **Test using an SFTP client**
   - Download and install **WinSCP**, **FileZilla**, or **Cyberduck**
   - Connect using:
     - **Host:** Your Windows 11 IP address
     - **Port:** 22
     - **Protocol:** SFTP
     - **Username:** sftpuser
     - **Password:** (the password you set)

---

## Step 8: Additional Security Configuration (Optional but Recommended)

### Disable Password Authentication (Use SSH Keys Instead)

1. **Edit sshd_config**

```powershell
notepad C:\ProgramData\ssh\sshd_config
```

2. **Add or modify these lines**

```
PasswordAuthentication no
PubkeyAuthentication yes
```

3. **Set up SSH keys for users**

```powershell
# Create .ssh directory in user's profile
New-Item -Path "C:\Users\sftpuser\.ssh" -ItemType Directory -Force

# Create authorized_keys file
New-Item -Path "C:\Users\sftpuser\.ssh\authorized_keys" -ItemType File -Force

# Add public key to authorized_keys (paste the user's public key)
notepad "C:\Users\sftpuser\.ssh\authorized_keys"

# Set proper permissions
icacls "C:\Users\sftpuser\.ssh\authorized_keys" /inheritance:r
icacls "C:\Users\sftpuser\.ssh\authorized_keys" /grant "sftpuser:F"
icacls "C:\Users\sftpuser\.ssh\authorized_keys" /grant "SYSTEM:F"
```

4. **Restart SSH service**

```powershell
Restart-Service sshd
```

### Change Default SSH Port

To reduce automated attacks, change from port 22:

1. **Edit sshd_config**

```powershell
notepad C:\ProgramData\ssh\sshd_config
```

2. **Find and modify the Port line**

```
Port 2222
```

3. **Update firewall rule**

```powershell
New-NetFirewallRule -Name sshd-2222 -DisplayName 'OpenSSH Server (sshd) Custom Port' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 2222
```

4. **Restart SSH service**

```powershell
Restart-Service sshd
```

### Enable Logging

1. **Edit sshd_config**

```powershell
notepad C:\ProgramData\ssh\sshd_config
```

2. **Set logging level**

```
SyslogFacility LOCAL0
LogLevel INFO
```

3. **View logs in Event Viewer**
   - Open Event Viewer → **Applications and Services Logs** → **OpenSSH** → **Operational**

---

## Troubleshooting

### Connection Refused

- Verify SSH service is running: `Get-Service sshd`
- Check firewall rules: `Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP"`
- Test locally first: `sftp localhost`

### Permission Denied

- Check directory permissions: `icacls C:\SFTP`
- Verify user is in sftp_users group: `Get-LocalGroupMember -Group "sftp_users"`
- Check sshd_config syntax: `sshd -t` (may need to run from C:\Windows\System32\OpenSSH)

### ChrootDirectory Not Working

- Ensure C:\SFTP is owned by Administrator
- Ensure C:\SFTP and all parent directories are not writable by the user
- Use forward slashes in sshd_config: `C:/SFTP`
- Check OpenSSH logs in Event Viewer

### Users Can't Write Files

- Check user permissions on their home directory: `icacls C:\SFTP\username`
- Ensure user has modify permissions on their subdirectory, not the root C:\SFTP

---

## Summary

You now have:
- OpenSSH Server installed and running on Windows 11
- SFTP enabled and configured
- C:\SFTP set as the base directory for users
- Users restricted to their designated directories
- Firewall configured to allow SFTP connections

### Key Files and Locations

- **SSH Config:** `C:\ProgramData\ssh\sshd_config`
- **SSH Logs:** Event Viewer → OpenSSH → Operational
- **SFTP Base Directory:** `C:\SFTP`
- **User Home Directories:** `C:\SFTP\username`

### Useful Commands

```powershell
# Check SSH service status
Get-Service sshd

# Restart SSH service
Restart-Service sshd

# Test SSH configuration
& "C:\Windows\System32\OpenSSH\sshd.exe" -t

# View SSH service logs
Get-WinEvent -LogName "OpenSSH/Operational" -MaxEvents 20
```

---

## Next Steps

1. Create additional user accounts as needed
2. Set up automated backups of C:\SFTP
3. Implement SSH key authentication for enhanced security
4. Monitor SSH logs regularly for suspicious activity
5. Consider setting up fail2ban or similar tools for brute force protection

For more information, consult the [OpenSSH documentation](https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_overview).
