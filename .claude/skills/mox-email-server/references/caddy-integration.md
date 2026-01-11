# Caddy Integration with Mox

## Architecture

- **Caddy**: Runs in Docker, handles ports 80/443, TLS certificates
- **Mox**: Runs on host, handles SMTP/IMAP ports, web interfaces on 8080

Caddy reverse proxies web interfaces (admin, webmail, autoconfig, MTA-STS) to Mox.

## Caddyfile Configuration

```caddyfile
# Main mail interface
mail.example.com {
    encode gzip

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options nosniff
        X-Frame-Options SAMEORIGIN
        Referrer-Policy strict-origin-when-cross-origin
    }

    # Admin interface - MUST rewrite Host to localhost
    handle /admin/* {
        reverse_proxy host.docker.internal:8080 {
            header_up Host localhost
            header_up X-Real-IP {remote_host}
        }
    }

    # All other paths (webmail, account, webapi)
    handle {
        reverse_proxy host.docker.internal:8080 {
            header_up Host {host}
            header_up X-Real-IP {remote_host}
        }
    }
}

# MTA-STS
mta-sts.example.com {
    encode gzip
    reverse_proxy host.docker.internal:8080 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
    }
}

# Autoconfig for email clients
autoconfig.example.com {
    encode gzip
    reverse_proxy host.docker.internal:8080 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
    }
}
```

**Critical**: The `/admin/*` block requires `header_up Host localhost` because Mox admin only accepts requests with Host header set to `localhost`.

## Docker Compose for Caddy

```yaml
services:
  caddy:
    image: caddy:2.8-alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy-data:/data
      - caddy-config:/config
    extra_hosts:
      - "host.docker.internal:host-gateway"

volumes:
  caddy-data:
  caddy-config:
```

The `extra_hosts` directive enables `host.docker.internal` to resolve to the Docker host.

## UFW Firewall Rules

Allow Docker containers to reach Mox web interface:

```bash
sudo ufw allow from 172.16.0.0/12 to any port 8080 comment 'Docker to mox'
```

Standard email ports:
```bash
sudo ufw allow 25/tcp comment 'SMTP'
sudo ufw allow 465/tcp comment 'SMTPS'
sudo ufw allow 587/tcp comment 'SMTP Submission'
sudo ufw allow 993/tcp comment 'IMAPS'
```

## Certificate Sync

Caddy obtains certificates automatically. Mox needs these certificates for SMTP/IMAP TLS.

### Certificate Locations

**Caddy (source)**:
```
/var/lib/docker/volumes/docker_caddy-data/_data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/mail.example.com/
├── mail.example.com.crt
└── mail.example.com.key
```

**Mox (target)**:
```
/home/mox/certs/
├── mail.example.com.crt
└── mail.example.com.key
```

### Sync Script

Create `/usr/local/bin/sync-caddy-to-mox.sh`:

```bash
#!/bin/bash
set -e

DOMAIN="mail.example.com"
CADDY_DIR="/var/lib/docker/volumes/docker_caddy-data/_data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/$DOMAIN"
MOX_CERT_DIR="/home/mox/certs"

mkdir -p "$MOX_CERT_DIR"
install -m 640 -o mox -g mox "$CADDY_DIR/$DOMAIN.crt" "$MOX_CERT_DIR/$DOMAIN.crt"
install -m 640 -o mox -g mox "$CADDY_DIR/$DOMAIN.key" "$MOX_CERT_DIR/$DOMAIN.key"

# Reload Mox to pick up new certificates
systemctl reload mox 2>/dev/null || true
```

Make executable:
```bash
sudo chmod +x /usr/local/bin/sync-caddy-to-mox.sh
```

### Systemd Timer

Create `/etc/systemd/system/sync-caddy-to-mox.service`:

```ini
[Unit]
Description=Sync Caddy certificates into Mox

[Service]
Type=oneshot
ExecStart=/usr/local/bin/sync-caddy-to-mox.sh
```

Create `/etc/systemd/system/sync-caddy-to-mox.timer`:

```ini
[Unit]
Description=Periodic sync of Caddy certificates into Mox

[Timer]
OnBootSec=1h
OnUnitActiveSec=12h
Unit=sync-caddy-to-mox.service

[Install]
WantedBy=timers.target
```

Enable:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now sync-caddy-to-mox.timer
```

Manual sync:
```bash
sudo systemctl start sync-caddy-to-mox.service
```

### Verify Certificate

```bash
openssl s_client -connect mail.example.com:465 -quiet 2>/dev/null | head -5
openssl s_client -connect mail.example.com:993 -quiet 2>/dev/null | head -5
```

Should show `CN=mail.example.com` with valid certificate.
