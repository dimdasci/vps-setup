# SOPS + age Troubleshooting

## Common Errors

### "could not decrypt data key"

**Symptom:**
```
Failed to get the data key required to decrypt the SOPS file.
could not decrypt data key with any of the provided keys
```

**Causes:**
1. Wrong private key
2. Key file not found
3. Key not in expected location

**Solutions:**
```bash
# Check which key SOPS is using
echo $SOPS_AGE_KEY_FILE
echo $SOPS_AGE_KEY

# Verify key file exists and has content
cat ~/.config/sops/age/keys.txt

# Test with explicit key
SOPS_AGE_KEY_FILE=/path/to/keys.txt sops decrypt file.enc.yaml

# Check which recipients file was encrypted for
grep -A 10 "^sops:" file.enc.yaml | grep age
```

### "no matching keys found in key groups"

**Symptom:** Decryption fails even with valid key

**Cause:** File uses key groups (Shamir) and you don't have enough keys

**Solution:** Need keys from multiple groups. Check file header:
```yaml
sops:
  shamir_threshold: 2
  key_groups:
    - age: [...]
    - age: [...]
```

### "error encrypting file: no keys found"

**Symptom:** Encryption fails

**Causes:**
1. No `.sops.yaml` file
2. No matching creation rule
3. Invalid recipient format

**Solutions:**
```bash
# Create .sops.yaml at repo root
cat > .sops.yaml << 'EOF'
creation_rules:
  - age: age1yourpublickey...
EOF

# Or specify recipient explicitly
sops encrypt --age age1yourpublickey... file.yaml
```

### "file has not been modified"

**Symptom:** `sops edit` closes without saving

**Cause:** No changes made, or editor exited without saving

**Solution:** Ensure your editor saves the file before closing

### ".sops.yaml not found"

**Symptom:** Encryption uses wrong keys or fails

**Cause:** SOPS searches from CWD upward, not from file location

**Solution:**
```bash
# Run from repo root where .sops.yaml lives
cd /path/to/repo
sops encrypt config/secrets.yaml

# Or ensure .sops.yaml is at/above your working directory
```

## Key Issues

### Wrong Key Format

**Valid age public key:**
```
age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p
```

**Invalid formats:**
```
# Missing 'age1' prefix
ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p

# Truncated
age1ql3z7hjy54pw3hyww5...

# SSH key (not supported in .sops.yaml)
ssh-ed25519 AAAA...
```

### Key File Permissions

```bash
# Key file should be readable only by owner
chmod 600 ~/.config/sops/age/keys.txt
```

### Multiple Keys in File

Keys.txt format (one key per line, comments allowed):
```
# Admin key
AGE-SECRET-KEY-1ADMIN...

# CI key
AGE-SECRET-KEY-1CICD...
```

## Configuration Issues

### path_regex Not Matching

```bash
# Debug which rule matches
sops encrypt -v file.yaml 2>&1 | grep -i "using"

# Common regex issues:
# Wrong: path_regex: secrets/*.yaml      # Shell glob, not regex
# Right: path_regex: secrets/.*\.yaml$   # Proper regex

# Path is relative to .sops.yaml location
# File: /repo/config/secrets/prod.yaml
# .sops.yaml at /repo/
# path_regex: ^config/secrets/.*\.yaml$  # Correct
```

### encrypted_regex Not Working

```bash
# Regex matches KEY names, not paths
# Wrong: encrypted_regex: password      # Matches "password" anywhere
# Right: encrypted_regex: ^password$    # Matches exactly "password"

# Multiple patterns
encrypted_regex: ^(password|secret|token|key)$
```

## Verification Commands

### Check File Status

```bash
# See if file is encrypted
head -20 file.enc.yaml | grep -E "^sops:|ENC\["

# Show encryption metadata
grep -A 50 "^sops:" file.enc.yaml

# List all recipients
grep "recipient:" file.enc.yaml
```

### Test Encryption/Decryption

```bash
# Dry-run encryption
sops encrypt --output /dev/null file.yaml && echo "OK"

# Test decryption
sops decrypt --output /dev/null file.enc.yaml && echo "OK"
```

### Validate .sops.yaml

```bash
# YAML syntax check
python3 -c "import yaml; yaml.safe_load(open('.sops.yaml'))"

# Test rule matching
echo "test: value" > /tmp/test.yaml
sops encrypt -v /tmp/test.yaml
```

## Recovery Procedures

### Lost Private Key

If you lose your private key and file was encrypted to multiple recipients:

1. Find someone else with access (another recipient)
2. Have them decrypt and re-encrypt with new key:
   ```bash
   sops decrypt file.enc.yaml > file.yaml
   # Update .sops.yaml with new key
   sops encrypt file.yaml > file.enc.yaml
   ```

### Corrupted Encrypted File

If sops metadata is corrupted:

1. Try extracting what you can:
   ```bash
   sops decrypt --ignore-mac file.enc.yaml
   ```

2. Check git history for uncorrupted version:
   ```bash
   git log --oneline file.enc.yaml
   git show HEAD~1:file.enc.yaml | sops decrypt /dev/stdin
   ```

### Re-encrypt All Files After Key Change

```bash
# Update .sops.yaml with new recipients first
# Then update all files:
find . -name "*.enc.yaml" -exec sops updatekeys -y {} \;

# Commit changes
git add -A
git commit -m "chore: update SOPS recipients"
```

## Performance Issues

### Slow Decryption

```bash
# Check number of recipients (more = slower)
grep -c "recipient:" file.enc.yaml

# Consider reducing recipients or using key groups
```

### Large Files

SOPS is designed for config files, not large data:
- Keep encrypted files under 1MB
- For large secrets, encrypt a reference/URL instead
