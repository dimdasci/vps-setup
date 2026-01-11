# Custom Windmill Worker

Build a custom worker with PDF and image processing tools for LLM workflows.

## Dockerfile

```dockerfile
# Custom Windmill Worker with PDF and image processing tools
FROM ghcr.io/windmill-labs/windmill:main

ARG PDFCPU_VERSION=0.11.1

USER root

# Install PDF and image processing tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    poppler-utils \
    libvips-tools \
    libvips42 \
    && curl -fsSL "https://github.com/pdfcpu/pdfcpu/releases/download/v${PDFCPU_VERSION}/pdfcpu_${PDFCPU_VERSION}_Linux_x86_64.tar.xz" \
    | tar -xJf - -C /usr/local/bin --strip-components=1 pdfcpu_${PDFCPU_VERSION}_Linux_x86_64/pdfcpu \
    && chmod +x /usr/local/bin/pdfcpu \
    && apt-get purge -y curl \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Verify installations
RUN pdfcpu version && pdfinfo -v && vips --version
```

**Total overhead**: ~150MB added to base image

## Included Tools

### pdfcpu (Go-based PDF manipulation)
- Extract/embed images and attachments
- Split, merge, rotate pages
- Add watermarks and encryption
- Form field manipulation
- PDF optimization

### Poppler (8 PDF utilities)
| Command | Purpose |
|---------|---------|
| `pdftotext` | Extract text from PDFs |
| `pdfimages` | Extract embedded images |
| `pdftohtml` | Convert PDF to HTML |
| `pdftoppm` | Convert pages to raster images |
| `pdftocairo` | High-quality PDF conversion |
| `pdfinfo` | Extract PDF metadata |
| `pdfseparate` | Split PDF into pages |
| `pdfunite` | Merge multiple PDFs |

### libvips (High-performance image processing)
- **4-8x faster** than ImageMagick
- **90% less memory** (~200MB vs ~3GB for large images)
- Streaming architecture (processes in chunks)
- Multi-threaded (uses all CPU cores)

Commands: `vips`, `vipsthumbnail`

## Building the Image

```bash
# Build locally
cd windmill-worker
docker build -t windmill-worker-custom:latest .

# Verify tools
docker run --rm windmill-worker-custom:latest pdfcpu version
docker run --rm windmill-worker-custom:latest vips --version
```

## Docker Compose Integration

```yaml
windmill-worker:
  build:
    context: ./windmill-worker
    dockerfile: Dockerfile
  image: windmill-worker-custom:latest
  restart: unless-stopped
  environment:
    - DATABASE_URL=${DATABASE_URL}
    - MODE=worker
    - WORKER_GROUP=default
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - worker-cache:/tmp/windmill/cache
  networks:
    - windmill-internal
  mem_limit: 1.5g
  cpus: 1.0
  deploy:
    replicas: 2
```

Deploy:
```bash
docker compose build windmill-worker
docker compose up -d windmill-worker
```

## Why Workers Run as Root

Workers require root for Docker socket access (`/var/run/docker.sock`) to spawn isolated job containers. This is standard for Docker-based job runners.

**Security layers**:
1. Network isolation (windmill-internal network)
2. Resource limits (memory, CPU)
3. Volume restrictions (only cache and logs)
4. Job containers are ephemeral
5. User scripts run in separate containers

## Verification

```bash
# Check pdfcpu
docker compose exec windmill-worker pdfcpu version

# Check Poppler
docker compose exec windmill-worker pdfinfo -v

# Check libvips
docker compose exec windmill-worker vips --version
```

## Optional: LibreOffice for Office Documents

Add to Dockerfile for DOC/DOCX/XLS/PPT conversion:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    libreoffice-core \
    libreoffice-writer \
    libreoffice-calc \
    ttf-mscorefonts-installer \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```

**Additional size**: ~400MB

Usage:
```bash
libreoffice --headless --convert-to pdf document.docx --outdir /tmp/
```
