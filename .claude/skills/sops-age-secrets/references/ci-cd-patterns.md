# CI/CD Integration Patterns

## GitHub Actions

### Basic Decryption

```yaml
# .github/workflows/deploy.yml
name: Deploy
on: [push]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install SOPS
        run: |
          curl -LO https://github.com/getsops/sops/releases/download/v3.9.0/sops-v3.9.0.linux.amd64
          chmod +x sops-v3.9.0.linux.amd64
          sudo mv sops-v3.9.0.linux.amd64 /usr/local/bin/sops

      - name: Decrypt secrets
        env:
          SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}
        run: |
          sops decrypt config/secrets.enc.yaml > config/secrets.yaml

      - name: Deploy
        run: ./deploy.sh
```

### Store Key in GitHub Secrets

1. Go to repository **Settings > Secrets and variables > Actions**
2. Add secret `SOPS_AGE_KEY` with content of private key:
   ```
   AGE-SECRET-KEY-1XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
   ```

### Multi-Environment

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [staging, production]
    environment: ${{ matrix.environment }}
    steps:
      - uses: actions/checkout@v4

      - name: Decrypt secrets
        env:
          SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}
        run: |
          sops decrypt config/secrets/${{ matrix.environment }}.enc.yaml > secrets.yaml
```

## GitLab CI

```yaml
# .gitlab-ci.yml
variables:
  SOPS_VERSION: "3.9.0"

.decrypt_secrets:
  before_script:
    - curl -LO "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64"
    - chmod +x sops-v${SOPS_VERSION}.linux.amd64
    - mv sops-v${SOPS_VERSION}.linux.amd64 /usr/local/bin/sops

deploy:
  extends: .decrypt_secrets
  script:
    - export SOPS_AGE_KEY="$SOPS_AGE_KEY"
    - sops decrypt secrets.enc.yaml > secrets.yaml
    - ./deploy.sh
  variables:
    SOPS_AGE_KEY: $SOPS_AGE_KEY  # From CI/CD variables
```

## Docker Build

### Build-time Secrets

```dockerfile
# Dockerfile
FROM node:20-alpine

# Install sops
RUN apk add --no-cache curl && \
    curl -LO https://github.com/getsops/sops/releases/download/v3.9.0/sops-v3.9.0.linux.amd64 && \
    chmod +x sops-v3.9.0.linux.amd64 && \
    mv sops-v3.9.0.linux.amd64 /usr/local/bin/sops

COPY . /app
WORKDIR /app

# Decrypt at build time (key passed via --build-arg)
ARG SOPS_AGE_KEY
RUN sops decrypt config.enc.yaml > config.yaml && \
    rm config.enc.yaml

CMD ["node", "app.js"]
```

Build:
```bash
docker build --build-arg SOPS_AGE_KEY="$(cat ~/.config/sops/age/keys.txt)" .
```

### Runtime Decryption (More Secure)

```dockerfile
FROM node:20-alpine

RUN apk add --no-cache curl && \
    curl -LO https://github.com/getsops/sops/releases/download/v3.9.0/sops-v3.9.0.linux.amd64 && \
    chmod +x sops-v3.9.0.linux.amd64 && \
    mv sops-v3.9.0.linux.amd64 /usr/local/bin/sops

COPY . /app
WORKDIR /app

# Decrypt at runtime via entrypoint
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["node", "app.js"]
```

```bash
#!/bin/sh
# entrypoint.sh
sops decrypt /app/config.enc.yaml > /app/config.yaml
exec "$@"
```

Run:
```bash
docker run -e SOPS_AGE_KEY="$SOPS_AGE_KEY" myapp
```

## exec-env Pattern

Use `sops exec-env` to avoid writing decrypted files:

```bash
# CI script
sops exec-env secrets.enc.yaml './deploy.sh'
```

Inside deploy.sh, secrets are available as environment variables.

## Pre-commit Hook

Prevent committing plaintext secrets:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: check-sops
        name: Check for unencrypted secrets
        entry: bash -c 'for f in $(git diff --cached --name-only | grep -E "secrets.*\.yaml$"); do if ! grep -q "sops:" "$f" 2>/dev/null; then echo "ERROR: $f not encrypted"; exit 1; fi; done'
        language: system
        pass_filenames: false
```

## Key Rotation in CI

```yaml
# Rotate keys monthly via scheduled workflow
name: Rotate SOPS Keys
on:
  schedule:
    - cron: '0 0 1 * *'  # First of each month

jobs:
  rotate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Rotate data keys
        env:
          SOPS_AGE_KEY: ${{ secrets.SOPS_AGE_KEY }}
        run: |
          find . -name "*.enc.yaml" -exec sops rotate -i {} \;

      - name: Commit changes
        run: |
          git config user.name "github-actions"
          git config user.email "github-actions@github.com"
          git add -A
          git commit -m "chore: rotate SOPS data keys" || exit 0
          git push
```

## Security Best Practices

1. **Use dedicated CI/CD key** - Separate from admin keys, easier to rotate
2. **Limit key scope** - CI key should only decrypt what it needs
3. **Don't log secrets** - Use `set +x` or mask output
4. **Clean up decrypted files** - Remove after use or use exec-env
5. **Audit access** - Track who has access to CI/CD secrets
6. **Rotate regularly** - Schedule key rotation for data keys

## FluxCD / GitOps

For Kubernetes GitOps with FluxCD:

```yaml
# Create secret with age key
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=/path/to/keys.txt

# Configure Flux Kustomization to use SOPS
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
spec:
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```
