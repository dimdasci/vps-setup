# Sync Certificates to Mox

Sync TLS certificates from Caddy to Mox email server.

## Instructions

1. Find certificates in Caddy data volume
2. Copy to Mox certificate directory
3. Set correct permissions
4. Reload Mox to pick up new certificates

## Script

```bash
#!/bin/bash
set -e

DOMAIN="${1:-mail.example.com}"
CADDY_CERTS="/var/lib/docker/volumes/docker_caddy-data/_data/caddy/certificates/acme-v02.api.letsencrypt.org-directory"
MOX_CERTS="/home/mox/config/certs"

# Create Mox certs directory if needed
sudo mkdir -p "$MOX_CERTS"

# Copy certificates
sudo cp "$CADDY_CERTS/$DOMAIN/$DOMAIN.crt" "$MOX_CERTS/"
sudo cp "$CADDY_CERTS/$DOMAIN/$DOMAIN.key" "$MOX_CERTS/"

# Set permissions
sudo chown -R mox:mox "$MOX_CERTS"
sudo chmod 600 "$MOX_CERTS"/*.key
sudo chmod 644 "$MOX_CERTS"/*.crt

# Reload Mox
sudo systemctl reload mox

echo "Certificates synced for $DOMAIN"
```

## Usage

Specify domain if different from default:
```
/sync-certs mail.mydomain.com
```

$ARGUMENTS
