# Validate Configuration

Validate all configuration files before deployment.

## Instructions

Check each configuration file for errors:

### 1. Docker Compose
```bash
docker compose config --quiet && echo "docker-compose.yml: OK" || echo "docker-compose.yml: INVALID"
```

### 2. Caddyfile
```bash
docker exec caddy caddy validate --config /etc/caddy/Caddyfile 2>&1
# Or if Caddy not running:
docker run --rm -v $(pwd)/caddy/Caddyfile:/etc/caddy/Caddyfile caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile
```

### 3. YAML Syntax (all .yaml files)
```bash
for f in $(find . -name "*.yaml" -o -name "*.yml"); do
  python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>/dev/null && echo "$f: OK" || echo "$f: INVALID"
done
```

### 4. Environment File
```bash
# Check .env exists and has required vars
[ -f .env ] && echo ".env: exists" || echo ".env: MISSING"
```

### 5. SOPS Encrypted Files
```bash
for f in $(find . -name "*.enc.yaml"); do
  sops --decrypt "$f" > /dev/null 2>&1 && echo "$f: decryptable" || echo "$f: cannot decrypt"
done
```

## Output

Report all validation results with clear pass/fail status.

$ARGUMENTS
