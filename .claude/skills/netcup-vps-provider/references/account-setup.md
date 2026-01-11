# Netcup Account and API Setup

## Getting API Credentials

### Step 1: Access Customer Control Panel

1. Go to https://customercontrolpanel.de
2. Login with your Netcup customer account

### Step 2: Generate API Key

1. Navigate to: **Stammdaten** (Master Data) → **API**
2. Click **"API-Schlüssel generieren"** (Generate API Key)
3. **Save immediately** - password shown only once:
   - **API Key**: `abc123...` (long alphanumeric string)
   - **API Password**: `xyz789...` (shown once, cannot be retrieved later)

### Step 3: Note Customer Number

Your customer number is displayed:
- In CCP header after login
- In order confirmation emails
- Format: 5-7 digit number (e.g., `12345`)

## Required Credentials

For DNS API automation:

```yaml
# Store in secrets file (encrypted with SOPS)
dns:
  customer_number: "12345"        # Netcup customer ID
  api_key: "abc123..."            # Generated in CCP
  api_password: "xyz789..."       # Shown once when generating
```

## Adding DNS Zones

The API cannot create new zones. Zones must be added manually in CCP first.

### For Netcup-Registered Domains

Zones are created automatically when you register or transfer a domain to Netcup.

### For External Domains

1. Login to CCP: https://customercontrolpanel.de
2. Navigate to: **Products** → **Domain** → **DNS**
3. Click **"Add DNS Zone"** (or "DNS Zone hinzufügen")
4. Enter domain name (e.g., `newproduct.io`)
5. Click **Save**

### Configure Nameservers at Registrar

After adding the zone in Netcup, update nameservers at your registrar:

```
root-dns.netcup.net
second-dns.netcup.net
third-dns.netcup.net
```

**Wait 24-48 hours** for NS propagation before expecting DNS queries to work.

## Verify Zone Setup

```bash
# Check nameservers are propagated
dig NS example.com +short
# Should show: root-dns.netcup.net, second-dns.netcup.net, third-dns.netcup.net

# Check zone is resolvable via Netcup
dig @root-dns.netcup.net A example.com
```

## API Access URLs

| Service | URL |
|---------|-----|
| DNS API | `https://ccp.netcup.net/run/webservice/servers/endpoint.php?JSON` |
| Customer Control Panel (CCP) | https://customercontrolpanel.de |
| Server Control Panel (SCP) | https://servercontrolpanel.de |
| Help Center | https://helpcenter.netcup.com |
| Community Forum | https://forum.netcup.de |

## Testing API Access

### Using curl

```bash
curl -X POST 'https://ccp.netcup.net/run/webservice/servers/endpoint.php?JSON' \
  -H 'Content-Type: application/json' \
  -d '{
    "action": "login",
    "param": {
      "customernumber": "YOUR_CUSTOMER_NUMBER",
      "apikey": "YOUR_API_KEY",
      "apipassword": "YOUR_API_PASSWORD"
    }
  }'
```

**Expected success response:**

```json
{
  "serverrequestid": "...",
  "action": "login",
  "status": "success",
  "statuscode": 2000,
  "shortmessage": "Login successful",
  "longmessage": "Session has been created successful.",
  "responsedata": {
    "apisessionid": "session-id-here"
  }
}
```

**Error response (wrong credentials):**

```json
{
  "status": "error",
  "statuscode": 5002,
  "shortmessage": "Unauthorized",
  "longmessage": "Invalid credentials"
}
```

### Using TypeScript/Bun

```typescript
const response = await fetch(
  'https://ccp.netcup.net/run/webservice/servers/endpoint.php?JSON',
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      action: 'login',
      param: {
        customernumber: process.env.NETCUP_CUSTOMER_NUMBER,
        apikey: process.env.NETCUP_API_KEY,
        apipassword: process.env.NETCUP_API_PASSWORD,
      },
    }),
  }
);

const result = await response.json();
if (result.status === 'success') {
  console.log('API access working! Session:', result.responsedata.apisessionid);
} else {
  console.error('API error:', result.longmessage);
}
```

## Security Best Practices

1. **Store credentials encrypted**: Use SOPS/age, never plaintext
2. **Never commit secrets**: Add secrets files to `.gitignore`
3. **Rotate periodically**: Regenerate API key yearly or after suspected compromise
4. **No granular permissions**: API key has full DNS access (Netcup limitation)

## Regenerating API Key

If credentials are compromised or lost:

1. Login to CCP
2. Go to **Stammdaten** → **API**
3. Click **"API-Schlüssel generieren"** again
4. **Old key becomes invalid immediately**
5. Update all systems using the old key

## VPS Order Process

For reference, when ordering a new VPS:

1. Login to CCP
2. Navigate to **Products** → **Order**
3. Select VPS type (e.g., VPS 4000 ARM G11)
4. Choose location (Nuremberg, Vienna, Amsterdam, Manassas)
5. Select OS (Ubuntu 22.04 LTS recommended)
6. Complete payment
7. Receive confirmation email with:
   - Server IP address
   - Root password
   - SCP access details
