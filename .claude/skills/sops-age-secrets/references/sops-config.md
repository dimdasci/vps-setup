# SOPS Configuration (.sops.yaml)

## File Location

Place `.sops.yaml` at repository root. Must be named exactly `.sops.yaml` (not `.sops.yml`).

## Basic Structure

```yaml
creation_rules:
  - path_regex: <pattern>
    age: <recipients>
    # additional options...
```

Rules are evaluated top-to-bottom; first match wins.

## Age-Only Configuration

### Single Recipient
```yaml
creation_rules:
  - age: age1abc123def456...
```

### Multiple Recipients
```yaml
creation_rules:
  - age: >-
      age1admin123...,
      age1cicd456...,
      age1dev789...
```

## Path-Based Rules

### Per-Environment
```yaml
creation_rules:
  # Production - admin + CI only
  - path_regex: secrets/prod\..*
    age: >-
      age1admin...,
      age1cicd...

  # Staging - broader access
  - path_regex: secrets/staging\..*
    age: >-
      age1admin...,
      age1cicd...,
      age1dev...

  # Development - all developers
  - path_regex: secrets/dev\..*
    age: age1dev...

  # Catch-all (required)
  - age: age1admin...
```

### Per-Directory
```yaml
creation_rules:
  - path_regex: ^config/secrets/.*\.yaml$
    age: age1...

  - path_regex: ^deploy/.*\.enc\.yaml$
    age: age1...
```

## Selective Encryption

### encrypted_regex (encrypt matching keys only)
```yaml
creation_rules:
  - path_regex: .*
    age: age1...
    encrypted_regex: ^(password|secret|key|token|api_key)$
```

### unencrypted_suffix (default behavior)
Keys ending with `_unencrypted` stay plaintext:
```yaml
data:
  password: ENC[AES256_GCM,...]
  config_unencrypted: plaintext value
```

### encrypted_suffix
Only encrypt keys with specific suffix:
```yaml
creation_rules:
  - encrypted_suffix: _secret
    age: age1...
```

### unencrypted_regex
Leave matching keys unencrypted:
```yaml
creation_rules:
  - unencrypted_regex: ^(description|metadata|version)$
    age: age1...
```

**Note**: These options are mutually exclusive.

## Key Groups (Shamir Secret Sharing)

Require multiple key holders to decrypt:

```yaml
creation_rules:
  - path_regex: secrets/critical\..*
    shamir_threshold: 2  # Need 2 of 3 groups
    key_groups:
      - age:
          - age1admin1...
          - age1admin2...
      - age:
          - age1security1...
      - age:
          - age1cicd...
```

## Mixed Key Types

Combine age with KMS for backup/recovery:
```yaml
creation_rules:
  - path_regex: secrets/prod\..*
    age: age1admin...
    kms: arn:aws:kms:us-east-1:123456:key/abc-123
```

## YAML/JSON Formatting

```yaml
stores:
  yaml:
    indent: 2
  json:
    indent: 2
```

## MAC Configuration

```yaml
creation_rules:
  - age: age1...
    mac_only_encrypted: true  # MAC only encrypted values (faster)
```

## Complete Example

```yaml
# .sops.yaml - VPS secrets configuration
creation_rules:
  # Profile-specific encrypted secrets
  - path_regex: ^config/secrets/.*\.enc\.yaml$
    age: >-
      age1adminkey...,
      age1deploykey...
    encrypted_regex: ^(password|secret|token|key|api_key|private)$

  # Environment files
  - path_regex: \.env\.enc$
    age: age1adminkey...

  # Catch-all for any other encrypted files
  - age: age1adminkey...

stores:
  yaml:
    indent: 2
```

## Updating Keys

After modifying `.sops.yaml`, update existing files:
```bash
# Interactive
sops updatekeys secrets.enc.yaml

# Non-interactive (CI/CD)
sops updatekeys -y secrets.enc.yaml

# All files matching pattern
find . -name "*.enc.yaml" -exec sops updatekeys -y {} \;
```

## Validation

Check if file matches expected rules:
```bash
# Encrypt with verbose output to see which rule matched
sops encrypt -v file.yaml
```
