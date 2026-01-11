# Mox Troubleshooting

## Common Issues

### 403 Forbidden on Admin Interface

**Symptom**: Accessing `https://mail.example.com/admin/` returns "403 - forbidden"

**Cause**: Mox admin interface only accepts requests with Host header set to `localhost`

**Solution**: Ensure Caddyfile has Host header rewrite for admin path:

```caddyfile
handle /admin/* {
    reverse_proxy host.docker.internal:8080 {
        header_up Host localhost
    }
}
```

### Connection Timeout from Docker to Mox

**Symptom**: Caddy cannot connect to Mox on port 8080

**Cause**: UFW firewall blocking Docker-to-host communication

**Solution**: Add UFW rule:
```bash
sudo ufw allow from 172.16.0.0/12 to any port 8080 comment 'Docker to mox'
```

Verify:
```bash
sudo ufw status numbered | grep 8080
```

### Mox Not Listening on Docker Bridge IPs

**Symptom**: `ss -tlnp | grep 8080` shows Mox only on 127.0.0.1

**Cause**: Docker bridge IPs not in mox.conf internal listener

**Solution**: Add Docker bridge IPs to internal listener in `/home/mox/config/mox.conf`:

```sconf
internal:
    IPs:
        - 127.0.0.1
        - ::1
        - 172.17.0.1
        - 172.18.0.1
        - 172.19.0.1
        - 172.20.0.1
        - 172.21.0.1
        - 172.22.0.1
```

Restart Mox after changes.

### Certificate Not Found for SMTP/IMAP

**Symptom**: TLS connection fails on ports 465/993

**Cause**: Certificate sync from Caddy not completed

**Solution**:
1. Check Caddy has certificate:
```bash
ls -la /var/lib/docker/volumes/docker_caddy-data/_data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/mail.example.com/
```

2. Run certificate sync:
```bash
sudo /usr/local/bin/sync-caddy-to-mox.sh
```

3. Check Mox certificate directory:
```bash
ls -la /home/mox/certs/
```

4. Verify certificate in TLS connection:
```bash
openssl s_client -connect mail.example.com:993 -quiet 2>/dev/null | head -5
```

### Mox Service Fails to Start

**Symptom**: `systemctl status mox` shows failed state

**Diagnosis**:
```bash
journalctl -u mox -n 50 --no-pager
```

**Common causes**:

1. **Configuration error**: Test config
   ```bash
   sudo -u mox /home/mox/mox config test
   ```

2. **Permission issues**: Fix ownership
   ```bash
   sudo chown -R mox:mox /home/mox
   ```

3. **Port already in use**: Check for conflicts
   ```bash
   sudo ss -tlnp | grep -E ":(25|465|587|993|8080)"
   ```

### Email Not Delivered (Outbound)

**Diagnosis steps**:

1. Check queue:
   ```bash
   sudo -u mox /home/mox/mox queue list
   ```

2. Check DNS records:
   ```bash
   dig MX example.com +short
   dig TXT example.com +short | grep spf
   dig TXT _dmarc.example.com +short
   ```

3. Check logs for delivery attempts:
   ```bash
   journalctl -u mox --since "1 hour ago" | grep -i deliver
   ```

### Email Not Received (Inbound)

**Diagnosis steps**:

1. Check port 25 is accessible:
   ```bash
   nc -zv mail.example.com 25
   ```

2. Check MX record points to correct server:
   ```bash
   dig MX example.com +short
   ```

3. Check Mox logs:
   ```bash
   journalctl -u mox -f
   ```

4. Send test email and watch logs.

## Verification Commands

### Service Status

```bash
systemctl status mox
systemctl is-active mox
```

### Port Connectivity

```bash
# Web interface
nc -zv localhost 8080

# SMTP
nc -zv mail.example.com 25

# SMTPS
nc -zv mail.example.com 465

# Submission
nc -zv mail.example.com 587

# IMAPS
nc -zv mail.example.com 993
```

### TLS Certificate

```bash
# SMTPS
openssl s_client -connect mail.example.com:465 -quiet 2>/dev/null | openssl x509 -noout -subject -dates

# IMAPS
openssl s_client -connect mail.example.com:993 -quiet 2>/dev/null | openssl x509 -noout -subject -dates
```

### Configuration Test

```bash
sudo -u mox /home/mox/mox config test
```

### Docker Connectivity Test

```bash
docker exec caddy wget -qO- http://host.docker.internal:8080 | head -20
```

### Listening Ports

```bash
sudo ss -tlnp | grep mox
```

## Log Analysis

### View Recent Errors

```bash
journalctl -u mox --since "1 hour ago" -p err
```

### Follow Logs in Real-Time

```bash
journalctl -u mox -f
```

### Search for Specific Email

```bash
journalctl -u mox | grep "user@example.com"
```

### Check Delivery Status

```bash
journalctl -u mox | grep -i "delivered\|failed\|deferred"
```
