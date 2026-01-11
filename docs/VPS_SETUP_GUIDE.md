# VPS Initial Setup Guide for Claude Code Development

Complete guide for setting up a new Netcup VPS for development with Claude Code, Bun, and TypeScript.

## Overview

**Goal**: Set up a secure VPS for remote development with:
- Dedicated non-root user
- SSH key authentication
- Bun + TypeScript runtime
- Claude Code CLI
- VS Code Remote connection
- Git/GitHub integration

**Time**: ~30 minutes

---

## Part 1: Initial Access (Netcup SCP)

### 1.1 Get Your Credentials

After ordering, you'll receive two emails from Netcup:
- **"Zugangsdaten SCP"** - Server Control Panel login
- **"Ihr vServer bei netcup"** - Root password and IP address

### 1.2 Access Server Control Panel

1. Go to [servercontrolpanel.de](https://servercontrolpanel.de)
2. Log in with SCP credentials
3. **Change your SCP password** (Options → Change Password)
4. Select your server from the dropdown

### 1.3 Note Server Details

From SCP, record:
- **Server IP**: (e.g., `123.45.67.89`)
- **Root password**: (from email)

### 1.4 Reinstall OS (Recommended)

For a clean Ubuntu 22.04 LTS installation:

1. In SCP, go to **Media** → **Images**
2. Select **Ubuntu 22.04** (minimal)
3. Click **Install**
4. Wait for installation (~5-10 minutes)
5. New root password will be shown - **save it**

---

## Part 2: First SSH Connection

### 2.1 Connect as Root

From your local terminal:

```bash
ssh root@YOUR_SERVER_IP
```

Accept the fingerprint prompt, enter the root password.

### 2.2 Change Root Password

```bash
passwd
```

Enter a strong, unique password.

### 2.3 Update System

```bash
apt update && apt upgrade -y
```

---

## Part 3: Create Development User

### 3.1 Create User

```bash
# Create user with home directory
adduser app

# Add to sudo group
usermod -aG sudo app

# Add to docker group (for later)
usermod -aG docker app 2>/dev/null || true
```

Follow prompts to set password and user info.

### 3.2 Set Up SSH Key Authentication

**On your local machine**, generate an SSH key if you don't have one:

```bash
# Generate key (if needed)
ssh-keygen -t ed25519 -C "your-email@example.com"

# Copy public key to server
ssh-copy-id -i ~/.ssh/id_ed25519.pub app@YOUR_SERVER_IP
```

### 3.3 Test SSH Key Login

```bash
# From local machine
ssh app@YOUR_SERVER_IP
```

Should connect without password prompt.

### 3.4 Secure SSH (Optional but Recommended)

Back on the server as root:

```bash
nano /etc/ssh/sshd_config
```

Change these settings:

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
```

Restart SSH:

```bash
systemctl restart ssh
```

**Warning**: Test SSH key login in a new terminal before closing your current session.

---

## Part 4: Install Development Tools

### 4.1 Essential Packages

```bash
sudo apt install -y \
    git \
    curl \
    wget \
    unzip \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release
```

### 4.2 Install Bun

```bash
curl -fsSL https://bun.sh/install | bash
```

Add to PATH (if not automatic):

```bash
echo 'export BUN_INSTALL="$HOME/.bun"' >> ~/.bashrc
echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Verify:

```bash
bun --version
```

### 4.3 TypeScript (via Bun)

Bun has built-in TypeScript support. No additional installation needed.

Test:

```bash
echo 'const msg: string = "Hello TypeScript"; console.log(msg);' > test.ts
bun run test.ts
rm test.ts
```

---

## Part 5: Install Claude Code

### 5.1 Install Claude Code CLI

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Add to PATH if needed:

```bash
source ~/.bashrc
```

Verify:

```bash
claude --version
```

### 5.2 Authenticate

```bash
claude
```

Follow the prompts:
1. Choose authentication method (Claude Pro/Max recommended)
2. Complete OAuth flow in browser (if terminal doesn't support, it shows a URL)
3. Return to terminal

### 5.3 Verify Installation

```bash
claude doctor
```

### 5.4 Install Custom Skills

Transfer your skill files to the server:

```bash
# From your local machine
scp ~/.claude/skills/*.skill app@YOUR_SERVER_IP:~/

# On the server
mkdir -p ~/.claude/skills
cd ~
for skill in *.skill; do
    unzip -o "$skill" -d ~/.claude/skills/
    rm "$skill"
done
```

---

## Part 6: Git and GitHub Setup

### 6.1 Configure Git

```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
git config --global init.defaultBranch main
```

### 6.2 Generate SSH Key for GitHub

```bash
ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/github
```

### 6.3 Add Key to SSH Agent

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/github
```

### 6.4 Configure SSH for GitHub

```bash
cat >> ~/.ssh/config << 'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github
EOF
```

### 6.5 Add Key to GitHub

Display your public key:

```bash
cat ~/.ssh/github.pub
```

1. Go to [GitHub Settings → SSH Keys](https://github.com/settings/keys)
2. Click **New SSH Key**
3. Paste the key
4. Save

### 6.6 Test Connection

```bash
ssh -T git@github.com
```

Should see: "Hi username! You've successfully authenticated..."

### 6.7 Clone Your Repository

```bash
mkdir -p ~/projects
cd ~/projects
git clone git@github.com:YOUR_USERNAME/vps-setup.git
cd vps-setup
```

---

## Part 7: VS Code Remote Setup

### 7.1 Install Remote-SSH Extension

In VS Code on your local machine:

1. Open Extensions (Cmd/Ctrl + Shift + X)
2. Search for "Remote - SSH"
3. Install the Microsoft extension

### 7.2 Configure SSH Host

On your local machine, edit `~/.ssh/config`:

```
Host vps
    HostName YOUR_SERVER_IP
    User app
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes
```

### 7.3 Connect to VPS

1. Press `Cmd/Ctrl + Shift + P`
2. Type "Remote-SSH: Connect to Host"
3. Select "vps"
4. VS Code connects and installs server components

### 7.4 Open Project

Once connected:
1. File → Open Folder
2. Navigate to `/home/app/projects/vps-setup`
3. Open

---

## Part 8: Install Docker (Optional)

For running containers on the VPS:

### 8.1 Install Docker

```bash
# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add repository
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or:
newgrp docker
```

### 8.2 Verify Docker

```bash
docker run hello-world
```

---

## Part 9: Firewall Setup (UFW)

### 9.1 Install and Configure UFW

```bash
sudo apt install -y ufw

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (important - do this first!)
sudo ufw allow ssh

# Allow HTTP/HTTPS (for web services)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable

# Verify
sudo ufw status
```

---

## Part 10: Working with Claude Code

### 10.1 Basic Usage

```bash
cd ~/projects/vps-setup

# Start Claude Code
claude

# Or with a specific task
claude "help me set up Docker Compose for Caddy"
```

### 10.2 Useful Commands

```bash
# Check health
claude doctor

# Clear conversation
claude --clear

# Use specific model
claude --model opus
```

### 10.3 Working with Skills

Your installed skills will be available automatically. Test:

```bash
claude "I need help setting up Caddy reverse proxy"
```

---

## Quick Reference

### SSH Commands

```bash
# Connect to VPS
ssh app@YOUR_SERVER_IP
# or
ssh vps

# Copy file to VPS
scp local-file.txt app@YOUR_SERVER_IP:~/

# Copy from VPS
scp app@YOUR_SERVER_IP:~/remote-file.txt ./
```

### Service Management

```bash
# View running services
systemctl list-units --type=service --state=running

# View logs
journalctl -u SERVICE_NAME -f

# Docker logs
docker compose logs -f
```

### System Monitoring

```bash
# Disk usage
df -h

# Memory usage
free -h

# CPU/processes
htop  # (install with: sudo apt install htop)

# Docker resources
docker stats
```

---

## Troubleshooting

### SSH Connection Refused

```bash
# Check SSH service on VPS (via SCP console)
sudo systemctl status ssh
sudo systemctl start ssh
```

### Claude Code Authentication Issues

```bash
# Clear auth and re-authenticate
rm -rf ~/.claude/auth
claude
```

### Permission Denied

```bash
# Ensure user owns home directory
sudo chown -R $USER:$USER ~

# Fix SSH key permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/*
```

### Bun Not Found After Install

```bash
source ~/.bashrc
# or restart shell
exec $SHELL
```

---

## Next Steps

1. **Set up SOPS/age** for secrets management
2. **Configure Caddy** as reverse proxy
3. **Deploy services** with Docker Compose
4. **Set up monitoring** and backups

---

## Sources

- [Netcup Server Access](https://helpcenter.netcup.com/en/wiki/server/accessing-server)
- [Claude Code Setup](https://code.claude.com/docs/en/setup)
- [Bun Installation](https://bun.sh/docs/installation)
- [Docker Installation](https://docs.docker.com/engine/install/ubuntu/)
