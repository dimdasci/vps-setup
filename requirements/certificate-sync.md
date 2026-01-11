# Certificate Synchronization: Caddy to Mox

## Problem Statement

Caddy automatically obtains and renews SSL/TLS certificates via ACME (Let's Encrypt). Mox email server runs on the host (not in Docker) and needs these certificates for:
- IMAPS (port 993)
- SMTPS (port 465)
- SMTP Submission with STARTTLS (port 587)

Mox cannot obtain its own certificates because:
1. Ports 80/443 are used by Caddy for ACME HTTP-01 challenges
2. Running two ACME clients creates complexity and potential conflicts

**Solution**: Sync certificates from Caddy to Mox automatically.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CERTIFICATE FLOW                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Let's Encrypt                                                       │
│       │                                                              │
│       │ ACME HTTP-01 Challenge                                       │
│       ▼                                                              │
│  ┌─────────┐                                                         │
│  │  Caddy  │ ◄──── Handles all certificate management               │
│  └────┬────┘                                                         │
│       │                                                              │
│       │ Stores certificates                                          │
│       ▼                                                              │
│  ┌─────────────────────────────────────┐                            │
│  │ Docker Volume: caddy-data           │                            │
│  │                                      │                            │
│  │ /data/caddy/certificates/           │                            │
│  │   acme-v02.api.letsencrypt.org-    │                            │
│  │     directory/                       │                            │
│  │       mail.fidudoc.eu/              │                            │
│  │         mail.fidudoc.eu.crt         │                            │
│  │         mail.fidudoc.eu.key         │                            │
│  └────────────────┬────────────────────┘                            │
│                   │                                                  │
│                   │ Sync Service (cron)                              │
│                   ▼                                                  │
│  ┌─────────────────────────────────────┐                            │
│  │ Host Filesystem                      │                            │
│  │                                      │                            │
│  │ /home/mox/certs/                    │                            │
│  │   mail.fidudoc.eu.crt               │                            │
│  │   mail.fidudoc.eu.key               │                            │
│  └────────────────┬────────────────────┘                            │
│                   │                                                  │
│                   │ Reads certificates                               │
│                   ▼                                                  │
│  ┌─────────┐                                                         │
│  │   Mox   │ ◄──── Uses for TLS on 465, 587, 993                    │
│  └─────────┘                                                         │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Certificate Locations

### Caddy Storage

Caddy stores certificates in the `caddy-data` Docker volume:

```
/var/lib/docker/volumes/docker_caddy-data/_data/
└── caddy/
    └── certificates/
        └── acme-v02.api.letsencrypt.org-directory/
            └── mail.fidudoc.eu/
                ├── mail.fidudoc.eu.crt    # Certificate + chain
                └── mail.fidudoc.eu.key    # Private key
```

### Mox Storage

Mox reads certificates from the host filesystem:

```
/home/mox/certs/
├── mail.fidudoc.eu.crt    # Certificate (PEM)
└── mail.fidudoc.eu.key    # Private key (PEM)
```

Configured in mox.conf:
```yaml
Listeners:
  public:
    TLS:
      KeyCerts:
        - CertFile: /home/mox/certs/mail.fidudoc.eu.crt
          KeyFile: /home/mox/certs/mail.fidudoc.eu.key
```

## Sync Mechanism

### Sync Service Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SYNC WORKFLOW                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. TRIGGER                                                         │
│     │                                                                │
│     ├─ Cron job: Every 6 hours                                      │
│     │   0 */6 * * * /usr/local/bin/vps-cert-sync                   │
│     │                                                                │
│     └─ Manual: vps cert-sync --host <ip>                           │
│                                                                      │
│  2. EXTRACT FROM CADDY                                              │
│     │                                                                │
│     ├─ Read cert from Docker volume:                                │
│     │   docker exec caddy cat /data/caddy/certificates/\            │
│     │     acme-v02.api.letsencrypt.org-directory/\                 │
│     │     mail.fidudoc.eu/mail.fidudoc.eu.crt                      │
│     │                                                                │
│     └─ Read key from Docker volume:                                 │
│         docker exec caddy cat /data/caddy/certificates/\            │
│           acme-v02.api.letsencrypt.org-directory/\                 │
│           mail.fidudoc.eu/mail.fidudoc.eu.key                      │
│                                                                      │
│  3. VALIDATE CERTIFICATE                                            │
│     │                                                                │
│     ├─ Check certificate is valid (not expired):                    │
│     │   openssl x509 -in cert.pem -checkend 86400                  │
│     │                                                                │
│     ├─ Verify domain matches:                                       │
│     │   openssl x509 -in cert.pem -noout -subject | grep mail.     │
│     │                                                                │
│     └─ Verify key matches certificate:                              │
│         cert_mod=$(openssl x509 -noout -modulus -in cert.pem)       │
│         key_mod=$(openssl rsa -noout -modulus -in key.pem)          │
│         [ "$cert_mod" = "$key_mod" ]                                │
│                                                                      │
│  4. CHECK IF SYNC NEEDED                                            │
│     │                                                                │
│     ├─ Get hash of current Mox cert:                                │
│     │   current_hash=$(sha256sum /home/mox/certs/mail.*.crt)       │
│     │                                                                │
│     ├─ Get hash of Caddy cert:                                      │
│     │   new_hash=$(sha256sum <extracted_cert>)                      │
│     │                                                                │
│     └─ If hashes match → Skip sync                                  │
│                                                                      │
│  5. DEPLOY TO MOX                                                   │
│     │                                                                │
│     ├─ Backup current certificates:                                 │
│     │   mv /home/mox/certs/mail.fidudoc.eu.crt .bak                │
│     │   mv /home/mox/certs/mail.fidudoc.eu.key .bak                │
│     │                                                                │
│     ├─ Copy new certificates:                                       │
│     │   cp cert.pem /home/mox/certs/mail.fidudoc.eu.crt            │
│     │   cp key.pem /home/mox/certs/mail.fidudoc.eu.key             │
│     │                                                                │
│     └─ Set permissions:                                             │
│         chown mox:mox /home/mox/certs/*                             │
│         chmod 644 /home/mox/certs/*.crt                             │
│         chmod 600 /home/mox/certs/*.key                             │
│                                                                      │
│  6. RELOAD MOX                                                      │
│     │                                                                │
│     └─ systemctl reload mox                                         │
│        (Mox reloads TLS config without disconnecting clients)       │
│                                                                      │
│  7. VERIFY DEPLOYMENT                                               │
│     │                                                                │
│     ├─ Test TLS connection:                                         │
│     │   openssl s_client -connect mail.fidudoc.eu:993              │
│     │                                                                │
│     └─ Check Mox logs:                                              │
│         journalctl -u mox --since "5 minutes ago" | grep -i error  │
│                                                                      │
│  8. REPORT                                                          │
│     │                                                                │
│     ├─ On success: Log "Certificate synced successfully"            │
│     │                                                                │
│     └─ On failure:                                                  │
│         ├─ Restore backup                                           │
│         ├─ Send alert email                                         │
│         └─ Exit with error code                                     │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Implementation

### TypeScript Sync Service

```typescript
// src/sync/certificates/index.ts

import { SSHClient } from '../../core/ssh/client';
import { Logger } from '../../utils/logger';

interface CertificateInfo {
  domain: string;
  cert: string;
  key: string;
  hash: string;
  expiresAt: Date;
}

interface SyncResult {
  status: 'synced' | 'up-to-date' | 'failed';
  message: string;
  details?: {
    oldHash?: string;
    newHash?: string;
    expiresAt?: Date;
  };
}

export class CertificateSyncService {
  private logger = new Logger('cert-sync');

  constructor(
    private ssh: SSHClient,
    private config: {
      domain: string;
      caddyVolumePath: string;
      moxCertPath: string;
    }
  ) {}

  async sync(options?: { force?: boolean }): Promise<SyncResult> {
    this.logger.info(`Starting certificate sync for ${this.config.domain}`);

    // 1. Extract certificate from Caddy
    const caddyCert = await this.extractFromCaddy();
    if (!caddyCert) {
      return {
        status: 'failed',
        message: 'Could not extract certificate from Caddy',
      };
    }

    // 2. Validate certificate
    const validationError = await this.validateCertificate(caddyCert);
    if (validationError) {
      return {
        status: 'failed',
        message: `Certificate validation failed: ${validationError}`,
      };
    }

    // 3. Check if sync needed
    if (!options?.force) {
      const moxCert = await this.getCurrentMoxCert();
      if (moxCert && moxCert.hash === caddyCert.hash) {
        this.logger.info('Certificates already in sync');
        return {
          status: 'up-to-date',
          message: 'Certificates already in sync',
          details: { expiresAt: caddyCert.expiresAt },
        };
      }
    }

    // 4. Backup current certificates
    await this.backupMoxCerts();

    // 5. Deploy new certificates
    try {
      await this.deployToMox(caddyCert);
    } catch (error) {
      await this.restoreBackup();
      throw error;
    }

    // 6. Reload Mox
    await this.reloadMox();

    // 7. Verify deployment
    const verified = await this.verifyDeployment();
    if (!verified) {
      await this.restoreBackup();
      await this.reloadMox();
      return {
        status: 'failed',
        message: 'Certificate deployment verification failed',
      };
    }

    this.logger.info('Certificate sync completed successfully');
    return {
      status: 'synced',
      message: 'Certificate synced successfully',
      details: {
        newHash: caddyCert.hash,
        expiresAt: caddyCert.expiresAt,
      },
    };
  }

  private async extractFromCaddy(): Promise<CertificateInfo | null> {
    const certPath = `${this.config.caddyVolumePath}/${this.config.domain}/${this.config.domain}.crt`;
    const keyPath = `${this.config.caddyVolumePath}/${this.config.domain}/${this.config.domain}.key`;

    const cert = await this.ssh.exec(`docker exec caddy cat ${certPath}`);
    const key = await this.ssh.exec(`docker exec caddy cat ${keyPath}`);

    if (cert.exitCode !== 0 || key.exitCode !== 0) {
      this.logger.error('Failed to extract certificates from Caddy');
      return null;
    }

    const hash = await this.computeHash(cert.stdout);
    const expiresAt = await this.getCertExpiry(cert.stdout);

    return {
      domain: this.config.domain,
      cert: cert.stdout,
      key: key.stdout,
      hash,
      expiresAt,
    };
  }

  private async validateCertificate(cert: CertificateInfo): Promise<string | null> {
    // Check not expired (with 24h buffer)
    const checkExpiry = await this.ssh.exec(
      `echo '${cert.cert}' | openssl x509 -checkend 86400 -noout`
    );
    if (checkExpiry.exitCode !== 0) {
      return 'Certificate is expired or expires within 24 hours';
    }

    // Check domain matches
    const checkDomain = await this.ssh.exec(
      `echo '${cert.cert}' | openssl x509 -noout -subject | grep -i ${this.config.domain}`
    );
    if (checkDomain.exitCode !== 0) {
      return `Certificate domain does not match ${this.config.domain}`;
    }

    // Check key matches cert
    const certMod = await this.ssh.exec(
      `echo '${cert.cert}' | openssl x509 -noout -modulus | sha256sum`
    );
    const keyMod = await this.ssh.exec(
      `echo '${cert.key}' | openssl rsa -noout -modulus | sha256sum`
    );
    if (certMod.stdout !== keyMod.stdout) {
      return 'Certificate and key do not match';
    }

    return null;
  }

  private async deployToMox(cert: CertificateInfo): Promise<void> {
    const certFile = `${this.config.moxCertPath}/${this.config.domain}.crt`;
    const keyFile = `${this.config.moxCertPath}/${this.config.domain}.key`;

    // Write certificate
    await this.ssh.exec(`cat > ${certFile} << 'CERTEOF'
${cert.cert}
CERTEOF`);

    // Write key
    await this.ssh.exec(`cat > ${keyFile} << 'KEYEOF'
${cert.key}
KEYEOF`);

    // Set permissions
    await this.ssh.exec(`chown mox:mox ${certFile} ${keyFile}`);
    await this.ssh.exec(`chmod 644 ${certFile}`);
    await this.ssh.exec(`chmod 600 ${keyFile}`);
  }

  private async reloadMox(): Promise<void> {
    await this.ssh.exec('systemctl reload mox', { sudo: true });
    // Wait for reload to complete
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }

  private async verifyDeployment(): Promise<boolean> {
    // Test TLS connection
    const result = await this.ssh.exec(
      `echo | openssl s_client -connect ${this.config.domain}:993 -servername ${this.config.domain} 2>/dev/null | openssl x509 -noout -dates`
    );
    return result.exitCode === 0;
  }

  // Helper methods
  private async computeHash(content: string): Promise<string> {
    const result = await this.ssh.exec(`echo '${content}' | sha256sum | cut -d' ' -f1`);
    return result.stdout.trim();
  }

  private async getCertExpiry(cert: string): Promise<Date> {
    const result = await this.ssh.exec(
      `echo '${cert}' | openssl x509 -noout -enddate | cut -d= -f2`
    );
    return new Date(result.stdout.trim());
  }

  private async getCurrentMoxCert(): Promise<CertificateInfo | null> {
    const certFile = `${this.config.moxCertPath}/${this.config.domain}.crt`;
    const result = await this.ssh.exec(`cat ${certFile} 2>/dev/null`);
    if (result.exitCode !== 0) return null;

    const hash = await this.computeHash(result.stdout);
    const expiresAt = await this.getCertExpiry(result.stdout);

    return { domain: this.config.domain, cert: result.stdout, key: '', hash, expiresAt };
  }

  private async backupMoxCerts(): Promise<void> {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupDir = `${this.config.moxCertPath}/backup-${timestamp}`;

    await this.ssh.exec(`mkdir -p ${backupDir}`);
    await this.ssh.exec(`cp ${this.config.moxCertPath}/*.crt ${backupDir}/ 2>/dev/null || true`);
    await this.ssh.exec(`cp ${this.config.moxCertPath}/*.key ${backupDir}/ 2>/dev/null || true`);
  }

  private async restoreBackup(): Promise<void> {
    // Find most recent backup
    const result = await this.ssh.exec(
      `ls -td ${this.config.moxCertPath}/backup-* 2>/dev/null | head -1`
    );
    if (result.exitCode !== 0 || !result.stdout.trim()) {
      this.logger.warn('No backup found to restore');
      return;
    }

    const backupDir = result.stdout.trim();
    await this.ssh.exec(`cp ${backupDir}/*.crt ${this.config.moxCertPath}/`);
    await this.ssh.exec(`cp ${backupDir}/*.key ${this.config.moxCertPath}/`);
    await this.ssh.exec(`chown mox:mox ${this.config.moxCertPath}/*`);
  }
}
```

### Cron Job Setup

The provisioning workflow installs a cron job:

```bash
# /etc/cron.d/vps-cert-sync
0 */6 * * * root /usr/local/bin/vps-cert-sync >> /var/log/vps-cert-sync.log 2>&1
```

### Shell Script Wrapper (for cron)

```bash
#!/bin/bash
# /usr/local/bin/vps-cert-sync

set -e

DOMAIN="mail.fidudoc.eu"
CADDY_CERT_DIR="/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${DOMAIN}"
MOX_CERT_DIR="/home/mox/certs"

# Extract from Caddy
CADDY_CERT=$(docker exec caddy cat "${CADDY_CERT_DIR}/${DOMAIN}.crt" 2>/dev/null)
CADDY_KEY=$(docker exec caddy cat "${CADDY_CERT_DIR}/${DOMAIN}.key" 2>/dev/null)

if [ -z "$CADDY_CERT" ] || [ -z "$CADDY_KEY" ]; then
    echo "$(date): ERROR - Could not extract certificates from Caddy"
    exit 1
fi

# Check if sync needed
CADDY_HASH=$(echo "$CADDY_CERT" | sha256sum | cut -d' ' -f1)
MOX_HASH=$(sha256sum "${MOX_CERT_DIR}/${DOMAIN}.crt" 2>/dev/null | cut -d' ' -f1 || echo "")

if [ "$CADDY_HASH" = "$MOX_HASH" ]; then
    echo "$(date): Certificates already in sync"
    exit 0
fi

# Backup current certs
BACKUP_DIR="${MOX_CERT_DIR}/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp "${MOX_CERT_DIR}"/*.crt "${MOX_CERT_DIR}"/*.key "$BACKUP_DIR/" 2>/dev/null || true

# Deploy new certs
echo "$CADDY_CERT" > "${MOX_CERT_DIR}/${DOMAIN}.crt"
echo "$CADDY_KEY" > "${MOX_CERT_DIR}/${DOMAIN}.key"

chown mox:mox "${MOX_CERT_DIR}/${DOMAIN}".{crt,key}
chmod 644 "${MOX_CERT_DIR}/${DOMAIN}.crt"
chmod 600 "${MOX_CERT_DIR}/${DOMAIN}.key"

# Reload Mox
systemctl reload mox

# Verify
sleep 2
if ! echo | openssl s_client -connect "${DOMAIN}:993" -servername "$DOMAIN" 2>/dev/null | openssl x509 -noout; then
    echo "$(date): ERROR - TLS verification failed, restoring backup"
    cp "$BACKUP_DIR"/* "$MOX_CERT_DIR/"
    chown mox:mox "${MOX_CERT_DIR}"/*
    systemctl reload mox
    exit 1
fi

echo "$(date): Certificate sync completed successfully"
```

## CLI Command

```bash
# Manual sync
vps cert-sync --host 203.0.113.50

# Force sync even if unchanged
vps cert-sync --host 203.0.113.50 --force

# Check sync status (dry run)
vps cert-sync --host 203.0.113.50 --dry-run

# Sync specific domain
vps cert-sync --host 203.0.113.50 --domain mail.fidudoc.eu
```

## Monitoring Integration

The validation workflow checks certificate sync status:

```
Certificates (5 checks)
  [✓] Caddy certs valid          All domains have valid certs
  [✓] Caddy cert expiry          mail.fidudoc.eu expires in 67 days
  [✓] Mox cert exists            /home/mox/certs/mail.fidudoc.eu.crt
  [✓] Mox cert matches Caddy     Hashes match (synced)
  [✓] Mox TLS working            IMAPS on 993 responds with valid cert
```

## Troubleshooting

### Common Issues

**1. Certificate not found in Caddy:**
```bash
# Check if Caddy has the certificate
docker exec caddy ls -la /data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/

# Check Caddy logs for ACME issues
docker logs caddy 2>&1 | grep -i certificate
```

**2. Permission denied when copying:**
```bash
# Ensure mox user owns the directory
chown -R mox:mox /home/mox/certs
chmod 700 /home/mox/certs
```

**3. Mox doesn't reload:**
```bash
# Check Mox can read the new cert
sudo -u mox cat /home/mox/certs/mail.fidudoc.eu.crt

# Force restart instead of reload
systemctl restart mox
```

**4. TLS verification fails:**
```bash
# Test specific port
openssl s_client -connect mail.fidudoc.eu:993 -servername mail.fidudoc.eu

# Check Mox logs
journalctl -u mox --since "10 minutes ago"
```

### Log Locations

- Sync script log: `/var/log/vps-cert-sync.log`
- Mox logs: `journalctl -u mox`
- Caddy logs: `docker logs caddy`

## Security Considerations

1. **Private key handling**: Keys are transmitted over SSH and written directly to disk. Never log key contents.

2. **Backup retention**: Old backups are kept indefinitely. Implement cleanup:
   ```bash
   # Keep only last 5 backups
   ls -td /home/mox/certs/backup-* | tail -n +6 | xargs rm -rf
   ```

3. **File permissions**: Certificate files are world-readable (644), keys are owner-only (600).

4. **Mox user**: Certificates are owned by the mox user, which is a system user with no login shell.
