# Mox Administration

## Installation

### Download Binary

```bash
# Create mox user
sudo useradd -m -d /home/mox -s /bin/bash mox

# Download binary
cd /home/mox
sudo -u mox curl -L -o mox "https://beta.gobuilds.org/github.com/mjl-/mox@latest/linux-amd64-latest/dl"
sudo -u mox chmod +x mox

# Verify binary
file /home/mox/mox  # Should show "ELF 64-bit"
```

### Quickstart

Run as mox user with admin email:

```bash
sudo -u mox bash -c 'cd /home/mox && ./mox quickstart admin@example.com'
```

Quickstart will:
1. Generate configuration files
2. Create admin account with random password
3. Generate DKIM keys
4. Output required DNS records
5. Create initial directory structure

**Save the generated passwords immediately!**

### Systemd Service

Create `/etc/systemd/system/mox.service`:

```ini
[Unit]
Description=Mox mail server
Documentation=https://github.com/mjl-/mox
After=network.target

[Service]
Type=notify
User=mox
Group=mox
WorkingDirectory=/home/mox
ExecStart=/home/mox/mox serve
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now mox
```

## Account Management

### Via Admin Web Interface

Access: `https://mail.example.com/admin/`

Navigate to Accounts section to:
- Create new accounts
- Reset passwords
- Manage aliases
- View account settings

### Via CLI

List accounts:
```bash
sudo -u mox /home/mox/mox config account list
```

Add account:
```bash
sudo -u mox /home/mox/mox config account add username@example.com
```

Set password:
```bash
sudo -u mox /home/mox/mox setaccountpassword username@example.com
```

Remove account:
```bash
sudo -u mox /home/mox/mox config account rm username@example.com
```

### Common Service Accounts

Create accounts for automated services:

| Account | Purpose |
|---------|---------|
| `system@example.com` | System notifications |
| `no-reply@example.com` | Automated emails |
| `postmaster@example.com` | Required by RFC |

## Domain Management

### Add Domain

Via CLI:
```bash
sudo -u mox /home/mox/mox config domain add newdomain.com admin@newdomain.com
```

This generates new DKIM keys and updates `domains.conf`.

### List Domains

```bash
sudo -u mox /home/mox/mox config domain list
```

### DKIM Key Rotation

Generate new DKIM key:
```bash
sudo -u mox /home/mox/mox dkim getselector example.com newselector
```

Add the new DKIM record to DNS, then update `domains.conf` to use the new selector.

## Password Management

### Reset Admin Password

```bash
sudo -u mox /home/mox/mox setadminpassword
```

### Reset Account Password

```bash
sudo -u mox /home/mox/mox setaccountpassword user@example.com
```

## Service Integration

### SMTP Settings for Applications

For Docker services using `host.docker.internal`:

```
Host: host.docker.internal
Port: 587
Security: STARTTLS
Username: service@example.com
Password: <account password>
```

For host services:

```
Host: localhost
Port: 587
Security: STARTTLS
Username: service@example.com
Password: <account password>
```

## Backup

### Data Directory

```bash
# Stop Mox
sudo systemctl stop mox

# Backup
sudo tar -czf mox-backup-$(date +%Y%m%d).tar.gz -C /home/mox data config

# Start Mox
sudo systemctl start mox
```

### Restore

```bash
sudo systemctl stop mox
sudo tar -xzf mox-backup-YYYYMMDD.tar.gz -C /home/mox
sudo chown -R mox:mox /home/mox
sudo systemctl start mox
```

## Maintenance

### View Logs

```bash
# Real-time
journalctl -u mox -f

# Last hour
journalctl -u mox --since "1 hour ago"

# Errors only
journalctl -u mox -p err
```

### Reload Configuration

```bash
sudo systemctl reload mox
```

### Full Restart

```bash
sudo systemctl restart mox
```

### Test Configuration

```bash
sudo -u mox /home/mox/mox config test
```
