# Age Key Management

## Key Generation

Generate a new age keypair:
```bash
age-keygen -o keys.txt
```

Output:
```
# created: 2024-01-15T10:30:00Z
# public key: age1abc123...
AGE-SECRET-KEY-1XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

Extract public key from existing private key:
```bash
age-keygen -y keys.txt
```

## Post-Quantum Keys (age 1.2+)

Generate hybrid post-quantum keys (~2000 char public key):
```bash
age-keygen -pq -o keys-pq.txt
```

Public keys start with `age1pq1...` instead of `age1...`

## Key Storage Locations

SOPS looks for age keys in these locations (in order):

| Platform | Default Location |
|----------|-----------------|
| Linux | `$XDG_CONFIG_HOME/sops/age/keys.txt` or `~/.config/sops/age/keys.txt` |
| macOS | `~/Library/Application Support/sops/age/keys.txt` |
| Windows | `%AppData%\sops\age\keys.txt` |

## Environment Variables

Override default key location:
```bash
# Point to specific key file
export SOPS_AGE_KEY_FILE=/path/to/keys.txt

# Provide key directly (for CI/CD)
export SOPS_AGE_KEY="AGE-SECRET-KEY-1XXXXXXX..."

# Get key from command
export SOPS_AGE_KEY_CMD="op read 'op://vault/sops/key'"
```

## Multiple Keys in One File

Store multiple identities in keys.txt:
```
# Admin key
AGE-SECRET-KEY-1ADMIN...

# CI/CD key
AGE-SECRET-KEY-1CICD...

# Developer key
AGE-SECRET-KEY-1DEV...
```

SOPS tries each key until one successfully decrypts.

## Passphrase-Protected Keys

age supports passphrase encryption for key files:
```bash
# Encrypt existing key
age -p -o protected-key.age keys.txt

# Decrypt when needed
age -d protected-key.age > keys.txt
```

## Key Distribution Patterns

### Team Setup
```
keys/
├── admin.pub          # Admin public key
├── ci-cd.pub          # CI/CD public key
└── developers.pub     # Shared dev key (or individual keys)
```

### Per-Environment Keys
```
keys/
├── production.pub     # Prod only - limited access
├── staging.pub        # Staging - dev team access
└── development.pub    # Dev - broad access
```

## Security Best Practices

1. **Never commit private keys** - Add to `.gitignore`:
   ```
   keys.txt
   *.agekey
   ```

2. **Use dedicated keys per purpose** - age keys are cheap, generate many

3. **Rotate keys periodically** - Use `sops updatekeys` after adding/removing recipients

4. **Back up keys securely** - Use password manager or encrypted backup

5. **Limit key access** - Production keys only on prod systems and admin workstations

## SSH Key Compatibility

age can encrypt to SSH keys (not recommended for SOPS):
```bash
age -R ~/.ssh/id_ed25519.pub file.txt
```

For SOPS, prefer native age keys for:
- Simpler key management
- No metadata leakage
- Clearer separation of concerns
