# SOPS CLI Reference

## Installation

```bash
# macOS
brew install sops age

# Ubuntu/Debian
apt install age
# Download sops from https://github.com/getsops/sops/releases

# From source (requires Go 1.19+)
go install github.com/getsops/sops/v3/cmd/sops@latest
```

## Core Commands

### Encrypt

```bash
# To stdout (recommended)
sops encrypt file.yaml > file.enc.yaml

# In-place
sops encrypt -i file.yaml

# With explicit age recipient
sops encrypt --age age1abc123... file.yaml > file.enc.yaml

# Multiple recipients
sops encrypt --age age1first...,age1second... file.yaml

# Selective encryption
sops encrypt --encrypted-regex '^(password|secret)$' file.yaml
```

### Decrypt

```bash
# To stdout
sops decrypt file.enc.yaml

# In-place
sops decrypt -i file.enc.yaml

# To specific file
sops decrypt file.enc.yaml > file.yaml

# Extract specific value
sops decrypt --extract '["database"]["password"]' file.enc.yaml
```

### Edit

```bash
# Opens in $EDITOR with decrypted content
sops edit file.enc.yaml

# Show master keys section
sops edit -s file.enc.yaml
```

### Set Values

```bash
# Set nested value
sops set file.enc.yaml '["database"]["password"]' '"newpassword"'

# Set from file content
sops set file.enc.yaml '["certificate"]' "$(cat cert.pem | jq -Rs)"
```

### Key Management

```bash
# Update keys per .sops.yaml
sops updatekeys file.enc.yaml
sops updatekeys -y file.enc.yaml  # non-interactive

# Rotate data key (re-encrypts all values)
sops rotate file.enc.yaml
sops rotate -i file.enc.yaml  # in-place

# Add recipient during rotation
sops rotate -i --add-age age1newkey... file.enc.yaml

# Remove recipient during rotation
sops rotate -i --rm-age age1oldkey... file.enc.yaml
```

### File Info

```bash
# Show file metadata
sops filestatus file.enc.yaml

# Show keys used
sops keys file.enc.yaml
```

## Environment Execution

### exec-env (secrets as environment variables)

```bash
# Run command with secrets in environment
sops exec-env secrets.enc.yaml 'echo $DATABASE_PASSWORD'

# Run script
sops exec-env secrets.enc.yaml './deploy.sh'

# Run as different user
sops exec-env --user deploy secrets.enc.yaml 'deploy.sh'
```

### exec-file (secrets as temporary file)

```bash
# {} replaced with temp file path
sops exec-file secrets.enc.yaml 'cat {}'

# Use named pipe (default, more secure)
sops exec-file secrets.enc.yaml 'source {}'

# Use actual temp file (for tools that need seekable file)
sops exec-file --no-fifo secrets.enc.yaml 'tool --config {}'
```

## Input/Output Options

```bash
# Specify input format
sops decrypt --input-type yaml file

# Specify output format
sops decrypt --output-type json file.enc.yaml

# From stdin
cat plaintext.yaml | sops encrypt --filename-override config.yaml /dev/stdin

# Binary files
sops encrypt --input-type binary file.bin > file.bin.enc
sops decrypt --output-type binary file.bin.enc > file.bin
```

## Common Flags

| Flag | Description |
|------|-------------|
| `-i, --in-place` | Write output back to input file |
| `-e, --encrypt` | Encrypt file |
| `-d, --decrypt` | Decrypt file |
| `--age` | age recipients (comma-separated) |
| `--input-type` | Input format: yaml, json, dotenv, ini, binary |
| `--output-type` | Output format: yaml, json, dotenv, ini, binary |
| `--encrypted-regex` | Only encrypt keys matching regex |
| `--unencrypted-regex` | Don't encrypt keys matching regex |
| `-v, --verbose` | Show verbose output |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `SOPS_AGE_KEY_FILE` | Path to age key file |
| `SOPS_AGE_KEY` | Age private key value |
| `SOPS_AGE_RECIPIENTS` | Default age recipients |
| `EDITOR` | Editor for `sops edit` |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Decryption failed (wrong key) |
| 128 | File not encrypted by SOPS |

## age CLI Reference

```bash
# Generate key
age-keygen -o keys.txt

# Extract public key
age-keygen -y keys.txt

# Encrypt file
age -r age1recipient... -o file.age file.txt

# Encrypt to multiple recipients
age -r age1first... -r age1second... file.txt

# Encrypt with passphrase
age -p -o file.age file.txt

# Decrypt
age -d -i keys.txt file.age

# ASCII armor output
age -a -r age1... file.txt
```
