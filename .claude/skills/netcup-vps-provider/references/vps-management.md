# Netcup VPS Management

## Server Control Panel (SCP)

URL: https://servercontrolpanel.de

### Access

1. Login with credentials from order confirmation email
2. Select server from dropdown menu
3. VNC console available for emergency access

### Common Operations

| Task | Location |
|------|----------|
| Reboot server | Control → Restart |
| Reinstall OS | Media → Images |
| VNC console | Control → Console |
| Resource usage | Status tab |
| Network settings | Network tab |
| Firewall rules | Firewall tab |

## Reverse DNS (PTR Record)

**Critical for email servers** - PTR record must match mail hostname.

### Set via SCP

1. Navigate to **Network** tab
2. Click on IPv4 address
3. Enter reverse DNS hostname (e.g., `mail.example.com`)
4. Save

### For IPv6

Same process, but select IPv6 address. Both IPv4 and IPv6 PTR records should match if using dual-stack.

### Verify PTR

```bash
# Check IPv4 PTR
dig -x YOUR_IPV4 +short
# Should return: mail.example.com.

# Check IPv6 PTR
dig -x YOUR_IPV6 +short
```

## Firewall Configuration

### Netcup Cloud Firewall (G12+)

Available for Generation 12 servers. Managed via SCP → Firewall.

**Default policies:**
- Outgoing port 25 (SMTP) blocked by default
- Remove "netcup Mail block" policy for email servers

### Removing Port 25 Block

1. SCP → Firewall
2. Find "netcup Mail block" policy
3. Click trash icon to remove
4. Click Save

### Server-Level Firewall (UFW)

Always configure UFW on the server itself:

```bash
# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Required ports for VPS stack
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS

# Email ports (for Mox)
sudo ufw allow 25/tcp    # SMTP
sudo ufw allow 465/tcp   # SMTPS
sudo ufw allow 587/tcp   # Submission
sudo ufw allow 993/tcp   # IMAPS

# Optional: PostgreSQL (for admin access)
sudo ufw allow 5432/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status verbose
```

## SSH Access

### Initial Connection

```bash
ssh root@YOUR_SERVER_IP
```

Password from order email or OS reinstall confirmation.

### Set Up Key Authentication

```bash
# From local machine
ssh-copy-id root@YOUR_SERVER_IP

# Or manually
cat ~/.ssh/id_ed25519.pub | ssh root@YOUR_SERVER_IP \
  "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

### Disable Password Authentication

After confirming key auth works:

```bash
# On server
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### SSH Hardening

```bash
# /etc/ssh/sshd_config additions
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
```

## Resource Monitoring

### Via SCP

Status tab shows:
- CPU usage (graph)
- Memory usage (graph)
- Disk usage
- Network traffic

### Via SSH

```bash
# Real-time monitoring
htop

# Disk usage
df -h

# Memory
free -h

# Network interfaces
ip addr

# Network traffic
iftop

# Docker resource usage
docker stats
```

## ARM G11 Specific

### Architecture

- CPU: Ampere Altra (ARM64/aarch64)
- Ensure all Docker images support `linux/arm64`

### Check Architecture

```bash
uname -m
# Output: aarch64
```

### Docker Multi-Platform

When pulling images, Docker will automatically select ARM64 variant if available:

```bash
docker pull --platform linux/arm64 postgres:16
```

## Backup

### Netcup Backups (if available)

1. SCP → Backup tab
2. Enable backups
3. Select schedule

### Manual Backups

```bash
# Database backup
docker exec postgres pg_dump -U postgres -F c dbname > backup.dump

# Full Docker volume backup
tar -czf docker-volumes.tar.gz /var/lib/docker/volumes/

# Configuration backup
tar -czf config-backup.tar.gz /home/app/docker/
```

## OS Reinstall

If needed to start fresh:

1. SCP → Media → Images
2. Select Ubuntu 22.04 LTS (or later)
3. Set root password
4. Click Install
5. Wait for completion (~5 minutes)
6. SSH with new root password

**Note**: This destroys all data on the server.

## Network Configuration

### Static IP

Netcup VPS comes with static IPv4 and IPv6 by default. No DHCP configuration needed.

### IPv6

Usually auto-configured. To verify:

```bash
ip -6 addr show
```

### DNS Resolvers

Default `/etc/resolv.conf`:

```
nameserver 8.8.8.8
nameserver 8.8.4.4
```

Or use Cloudflare:

```
nameserver 1.1.1.1
nameserver 1.0.0.1
```
