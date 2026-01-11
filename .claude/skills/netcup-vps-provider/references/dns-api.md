# Netcup DNS API Reference

## Endpoint

```
POST https://ccp.netcup.net/run/webservice/servers/endpoint.php?JSON
Content-Type: application/json
```

## Authentication

### Login

```json
{
  "action": "login",
  "param": {
    "customernumber": "12345",
    "apikey": "your-api-key",
    "apipassword": "your-api-password"
  }
}
```

**Response:**

```json
{
  "serverrequestid": "xxx",
  "clientrequestid": "",
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

### Logout

```json
{
  "action": "logout",
  "param": {
    "customernumber": "12345",
    "apikey": "your-api-key",
    "apisessionid": "session-id"
  }
}
```

## Zone Operations

### Info DNS Zone

Get zone metadata (TTL, serial, DNSSEC status).

```json
{
  "action": "infoDnsZone",
  "param": {
    "customernumber": "12345",
    "apikey": "your-api-key",
    "apisessionid": "session-id",
    "domainname": "example.com"
  }
}
```

**Response:**

```json
{
  "responsedata": {
    "name": "example.com",
    "ttl": "86400",
    "serial": "2025010901",
    "refresh": "28800",
    "retry": "7200",
    "expire": "1209600",
    "dnssecstatus": false
  }
}
```

### Info DNS Records

Get all records in a zone.

```json
{
  "action": "infoDnsRecords",
  "param": {
    "customernumber": "12345",
    "apikey": "your-api-key",
    "apisessionid": "session-id",
    "domainname": "example.com"
  }
}
```

**Response:**

```json
{
  "responsedata": {
    "dnsrecords": [
      {
        "id": "12345",
        "hostname": "@",
        "type": "A",
        "priority": "0",
        "destination": "203.0.113.50",
        "deleterecord": false,
        "state": "yes"
      },
      {
        "id": "12346",
        "hostname": "@",
        "type": "MX",
        "priority": "10",
        "destination": "mail.example.com",
        "deleterecord": false,
        "state": "yes"
      }
    ]
  }
}
```

### Update DNS Records

**IMPORTANT**: This replaces ALL records in the zone. Always include existing records you want to keep.

```json
{
  "action": "updateDnsRecords",
  "param": {
    "customernumber": "12345",
    "apikey": "your-api-key",
    "apisessionid": "session-id",
    "domainname": "example.com",
    "dnsrecordset": {
      "dnsrecords": [
        {
          "hostname": "@",
          "type": "A",
          "destination": "203.0.113.50"
        },
        {
          "hostname": "mail",
          "type": "A",
          "destination": "203.0.113.50"
        },
        {
          "hostname": "@",
          "type": "MX",
          "priority": "10",
          "destination": "mail.example.com"
        },
        {
          "hostname": "@",
          "type": "TXT",
          "destination": "v=spf1 mx ~all"
        }
      ]
    }
  }
}
```

## Record Types

| Type | hostname | priority | destination |
|------|----------|----------|-------------|
| A | @ or subdomain | - | IPv4 address |
| AAAA | @ or subdomain | - | IPv6 address |
| CNAME | subdomain (not @) | - | Target FQDN |
| MX | @ or subdomain | Required | Mail server FQDN |
| TXT | @ or subdomain | - | Text value |
| SRV | _service._proto | Required | weight port target |
| CAA | @ or subdomain | - | flag tag value |

## Long TXT Records (DKIM)

For DKIM records exceeding 255 characters, split into quoted segments:

```json
{
  "hostname": "selector._domainkey",
  "type": "TXT",
  "destination": "\"v=DKIM1; k=rsa; p=MIIBIjANBgkqhki...\" \"...rest of key...\""
}
```

## Error Codes

| Code | Meaning |
|------|---------|
| 2000 | Success |
| 4001 | Validation error |
| 4002 | Missing parameter |
| 4013 | Invalid or expired session |
| 5000 | Server error |
| 5001 | Domain/resource not found |
| 5002 | Unauthorized |

## TypeScript Client

```typescript
const NETCUP_API = 'https://ccp.netcup.net/run/webservice/servers/endpoint.php?JSON';

interface NetcupApiParams {
  customernumber: string;
  apikey: string;
  apipassword?: string;
  apisessionid?: string;
  domainname?: string;
  dnsrecordset?: {
    dnsrecords: NetcupDnsRecord[];
  };
}

interface NetcupDnsRecord {
  id?: string;
  hostname: string;
  type: string;
  priority?: string;
  destination: string;
  deleterecord?: boolean;
  state?: string;
}

interface NetcupApiResponse<T = unknown> {
  serverrequestid: string;
  clientrequestid: string;
  action: string;
  status: 'success' | 'error';
  statuscode: number;
  shortmessage: string;
  longmessage: string;
  responsedata: T;
}

async function netcupApi<T>(
  action: string,
  params: NetcupApiParams
): Promise<NetcupApiResponse<T>> {
  const response = await fetch(NETCUP_API, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ action, param: params }),
  });

  const result = await response.json();

  if (result.status !== 'success') {
    throw new Error(`Netcup API error [${result.statuscode}]: ${result.longmessage}`);
  }

  return result;
}

// Example: Full workflow
async function syncDnsRecords(
  credentials: { customernumber: string; apikey: string; apipassword: string },
  domain: string,
  records: NetcupDnsRecord[]
): Promise<void> {
  // Login
  const login = await netcupApi<{ apisessionid: string }>('login', credentials);
  const sessionId = login.responsedata.apisessionid;

  try {
    // Get current records
    const current = await netcupApi<{ dnsrecords: NetcupDnsRecord[] }>(
      'infoDnsRecords',
      { ...credentials, apisessionid: sessionId, domainname: domain }
    );

    // Merge with new records (implement your merge logic)
    const merged = mergeRecords(current.responsedata.dnsrecords, records);

    // Update
    await netcupApi('updateDnsRecords', {
      ...credentials,
      apisessionid: sessionId,
      domainname: domain,
      dnsrecordset: { dnsrecords: merged },
    });
  } finally {
    // Always logout
    await netcupApi('logout', { ...credentials, apisessionid: sessionId });
  }
}
```

## Rate Limits

Netcup does not publish specific rate limits, but:
- Sessions expire after ~15 minutes of inactivity
- Batch operations recommended over individual record changes
- Add delay between rapid successive calls if issues occur
