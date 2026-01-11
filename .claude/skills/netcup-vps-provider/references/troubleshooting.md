# Netcup Troubleshooting

## DNS Propagation Issues

### Problem: Records not visible after update

**Cause**: Netcup DNS propagation is slow (~15 minutes typical, up to 24 hours).

**Solutions**:

1. **Wait at least 15 minutes** before checking
2. **Check with multiple DNS resolvers**:
   ```bash
   dig A example.com @8.8.8.8 +short    # Google
   dig A example.com @1.1.1.1 +short    # Cloudflare
   dig A example.com @9.9.9.9 +short    # Quad9
   ```
3. **Check directly on Netcup nameservers**:
   ```bash
   dig A example.com @root-dns.netcup.net +short
   ```
4. **Use global propagation checker**: https://dnschecker.org

### Problem: Records correct at Netcup but not globally

**Cause**: DNS caching at resolver level.

**Solutions**:

1. Wait for TTL to expire
2. Lower TTL before making changes (requires waiting for old TTL first)
3. Flush local DNS cache:
   ```bash
   # macOS
   sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

   # Linux (systemd-resolved)
   sudo systemd-resolve --flush-caches

   # Linux (nscd)
   sudo systemctl restart nscd
   ```

## API Errors

### Error: "Invalid API credentials" (5002)

**Causes**:
- Wrong customer number
- API key or password typo
- API key was regenerated (old one invalid)

**Solutions**:

1. Verify customer number in CCP header
2. Regenerate API key in CCP → Stammdaten → API
3. Update all systems with new credentials
4. Check for extra whitespace in stored credentials

### Error: "Domain not found" (5001)

**Cause**: Zone doesn't exist in Netcup DNS.

**Solutions**:

1. **For Netcup-registered domains**: Should exist automatically. Contact support if missing.
2. **For external domains**: Add zone manually in CCP → Products → Domain → DNS

### Error: "Session expired" (4013)

**Cause**: API session timed out (~15 minutes inactivity).

**Solution**: Login again before each operation batch.

```typescript
// Always login fresh before operations
const session = await netcupApi('login', credentials);
try {
  // Do operations
} finally {
  await netcupApi('logout', { ...credentials, apisessionid: session.apisessionid });
}
```

### Error: Records disappear after update

**Cause**: `updateDnsRecords` replaces ALL records in the zone.

**Solution**: Always merge with existing records:

```typescript
// Get current records first
const current = await netcupApi('infoDnsRecords', { ...params, domainname: domain });
const existingRecords = current.responsedata.dnsrecords;

// Merge with new records
const allRecords = mergeRecords(existingRecords, newRecords);

// Update with complete set
await netcupApi('updateDnsRecords', {
  ...params,
  domainname: domain,
  dnsrecordset: { dnsrecords: allRecords },
});
```

## Email Delivery Issues

### Problem: Emails rejected by recipients

**Checklist**:

1. **PTR record matches mail hostname**:
   ```bash
   dig -x YOUR_IP +short
   # Must return: mail.example.com.
   ```

2. **SPF record present**:
   ```bash
   dig TXT example.com +short | grep spf
   # Should show: v=spf1 mx ~all
   ```

3. **DKIM record present**:
   ```bash
   dig TXT selector._domainkey.example.com +short
   # Should show DKIM public key
   ```

4. **DMARC record present**:
   ```bash
   dig TXT _dmarc.example.com +short
   # Should show: v=DMARC1; p=...
   ```

5. **Port 25 not blocked**:
   ```bash
   telnet smtp.gmail.com 25
   # Should connect (then Ctrl+] and quit)
   ```

### Problem: DKIM verification fails

**Causes**:
- DKIM record not propagated yet
- Record truncated (>255 chars not split correctly)
- Wrong selector

**Solutions**:

1. Verify selector matches Mox config:
   ```bash
   sudo -u mox /home/mox/mox config domain keyget example.com
   # Note the selector value
   ```

2. For long keys, ensure proper quoting in TXT record:
   ```
   "v=DKIM1; k=rsa; p=MIIBIjANBgkqh..." "...kiG9w0BAQEFAAO..."
   ```

3. Check record is correctly stored:
   ```bash
   dig TXT selector._domainkey.example.com +short
   ```

### Problem: Port 25 blocked

**Cause**: Netcup blocks outgoing SMTP by default on new VPS.

**Solution**:

1. Login to SCP (https://servercontrolpanel.de)
2. Select your server
3. Go to Firewall tab
4. Remove "netcup Mail block" policy
5. Save changes

Verify:
```bash
telnet smtp.gmail.com 25
# Should connect
```

## Certificate Issues

### Problem: ACME DNS challenge fails

**Cause**: DNS record not propagated before challenge verification.

**Solutions**:

1. Set `propagation_timeout: 900` (15 min) in Caddy config
2. Add `--wait` flag to dns sync before cert acquisition
3. Use HTTP challenge instead when possible

### Problem: Caddy not getting certificates

**Check**:

```bash
# Verify A record points to correct IP
dig A example.com +short
# Should show your VPS IP

# Check Caddy logs
docker logs caddy 2>&1 | grep -i "error\|challenge\|certificate"
```

## VPS Access Issues

### Problem: Can't SSH to server

**Checklist**:

1. **Server running**: Check SCP status page
2. **Correct IP**: Verify IP address
3. **SSH port open**:
   ```bash
   nc -zv YOUR_IP 22
   ```
4. **Firewall not blocking**:
   - Check Netcup cloud firewall in SCP
   - Check UFW on server (use VNC console)

**Emergency access**: Use VNC console in SCP → Control → Console

### Problem: Locked out after SSH config change

**Solution**:

1. Access via VNC console in SCP
2. Login as root
3. Fix `/etc/ssh/sshd_config`
4. Restart SSH: `systemctl restart sshd`

### Problem: VNC console not responding

**Solution**: Hard reboot via SCP → Control → Restart

## Performance Issues

### Problem: DNS queries slow

**Cause**: Netcup DNS servers have variable latency.

**Solutions**:

1. Accept as limitation (not much can be done)
2. Lower TTL to reduce caching issues
3. For critical production: Consider premium DNS provider with Netcup as secondary

## Useful Diagnostic Commands

```bash
# Check DNS from server
dig @localhost A mail.example.com

# Check configured resolvers
cat /etc/resolv.conf

# Test SMTP
openssl s_client -connect mail.example.com:465 -quiet

# Test IMAP
openssl s_client -connect mail.example.com:993 -quiet

# Check certificate
openssl s_client -connect mail.example.com:443 -servername mail.example.com < /dev/null 2>/dev/null | openssl x509 -noout -dates

# Trace DNS resolution
dig +trace A mail.example.com

# Check MX delivery path
dig MX example.com +short

# Test email deliverability
# Use: https://www.mail-tester.com/
```

## Common Mistakes

1. **Forgetting to add zone before using API**: API can't create zones
2. **Not waiting for propagation**: 15 minutes minimum
3. **Partial record updates**: Always send complete zone
4. **Wrong PTR format**: Must match mail hostname exactly
5. **Forgetting IPv6 PTR**: If using IPv6 for email
6. **Not removing mail block**: Port 25 blocked by default
