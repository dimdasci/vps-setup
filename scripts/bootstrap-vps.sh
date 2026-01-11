#!/bin/bash
# VPS Bootstrap Script for Claude Code Development
# Run as the 'app' user (not root)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/main/scripts/bootstrap-vps.sh | bash
#   or
#   bash bootstrap-vps.sh

set -e

echo "================================================"
echo "VPS Bootstrap for Claude Code Development"
echo "================================================"
echo ""

# Check we're not root
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root."
    echo "Create a user first: adduser app && usermod -aG sudo app"
    echo "Then run as that user."
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: System packages
log_step "Installing essential packages..."
sudo apt update
sudo apt install -y \
    git \
    curl \
    wget \
    unzip \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release \
    htop

# Step 2: Install Bun
log_step "Installing Bun..."
if command -v bun &> /dev/null; then
    log_info "Bun already installed: $(bun --version)"
else
    curl -fsSL https://bun.sh/install | bash

    # Add to PATH for current session
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"

    # Ensure it's in .bashrc
    if ! grep -q 'BUN_INSTALL' ~/.bashrc; then
        echo '' >> ~/.bashrc
        echo '# Bun' >> ~/.bashrc
        echo 'export BUN_INSTALL="$HOME/.bun"' >> ~/.bashrc
        echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.bashrc
    fi
fi

# Verify Bun
if command -v bun &> /dev/null; then
    log_info "Bun installed: $(bun --version)"
else
    log_error "Bun installation failed"
    exit 1
fi

# Step 3: Install Claude Code
log_step "Installing Claude Code..."
if command -v claude &> /dev/null; then
    log_info "Claude Code already installed: $(claude --version 2>/dev/null || echo 'version check failed')"
else
    curl -fsSL https://claude.ai/install.sh | bash

    # Source to get claude in path
    source ~/.bashrc 2>/dev/null || true
fi

# Step 4: Git configuration
log_step "Checking Git configuration..."
if [ -z "$(git config --global user.name)" ]; then
    log_info "Git user.name not set"
    read -p "Enter your Git name: " git_name
    git config --global user.name "$git_name"
fi

if [ -z "$(git config --global user.email)" ]; then
    log_info "Git user.email not set"
    read -p "Enter your Git email: " git_email
    git config --global user.email "$git_email"
fi

git config --global init.defaultBranch main
log_info "Git configured: $(git config --global user.name) <$(git config --global user.email)>"

# Step 5: SSH key for GitHub
log_step "Setting up GitHub SSH key..."
GITHUB_KEY="$HOME/.ssh/github"
if [ ! -f "$GITHUB_KEY" ]; then
    log_info "Generating SSH key for GitHub..."
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    ssh-keygen -t ed25519 -C "$(git config --global user.email)" -f "$GITHUB_KEY" -N ""

    # Configure SSH for GitHub
    if ! grep -q "Host github.com" ~/.ssh/config 2>/dev/null; then
        cat >> ~/.ssh/config << EOF

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github
EOF
        chmod 600 ~/.ssh/config
    fi

    echo ""
    echo "================================================"
    echo "ADD THIS KEY TO GITHUB:"
    echo "================================================"
    cat "${GITHUB_KEY}.pub"
    echo ""
    echo "Go to: https://github.com/settings/keys"
    echo "================================================"
    echo ""
    read -p "Press Enter after adding the key to GitHub..."

    # Test connection
    ssh -T git@github.com 2>&1 || true
else
    log_info "GitHub SSH key already exists"
fi

# Step 6: Create projects directory
log_step "Creating projects directory..."
mkdir -p ~/projects
mkdir -p ~/docker

# Step 7: Install Docker (optional)
echo ""
read -p "Install Docker? (y/n): " install_docker
if [ "$install_docker" = "y" ] || [ "$install_docker" = "Y" ]; then
    log_step "Installing Docker..."

    # Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Add Docker repository
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add user to docker group
    sudo usermod -aG docker $USER

    log_info "Docker installed. You may need to log out and back in for group changes."
fi

# Step 8: Setup UFW
echo ""
read -p "Configure UFW firewall? (y/n): " setup_ufw
if [ "$setup_ufw" = "y" ] || [ "$setup_ufw" = "Y" ]; then
    log_step "Configuring UFW..."

    sudo apt install -y ufw
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp

    echo ""
    log_info "UFW rules configured. Enable with: sudo ufw enable"
    read -p "Enable UFW now? (y/n): " enable_ufw
    if [ "$enable_ufw" = "y" ] || [ "$enable_ufw" = "Y" ]; then
        sudo ufw --force enable
        sudo ufw status
    fi
fi

# Step 9: Create skills directory
log_step "Creating Claude skills directory..."
mkdir -p ~/.claude/skills

# Summary
echo ""
echo "================================================"
echo "SETUP COMPLETE!"
echo "================================================"
echo ""
echo "Installed:"
echo "  - Essential packages (git, curl, etc.)"
echo "  - Bun: $(bun --version 2>/dev/null || echo 'restart shell to verify')"
echo "  - Claude Code: $(claude --version 2>/dev/null || echo 'restart shell to verify')"
echo "  - Git configured"
[ -f "$GITHUB_KEY" ] && echo "  - GitHub SSH key"
[ "$install_docker" = "y" ] && echo "  - Docker"
[ "$setup_ufw" = "y" ] && echo "  - UFW firewall"
echo ""
echo "Next steps:"
echo "  1. Restart your shell: exec \$SHELL"
echo "  2. Authenticate Claude Code: claude"
echo "  3. Clone your repo: cd ~/projects && git clone git@github.com:USER/REPO.git"
echo "  4. Transfer skills: scp *.skill $USER@host:~/.claude/skills/"
echo ""
echo "================================================"
