#!/bin/bash
# Mox Email Server Health Check Script
# Usage: sudo mox-health-check.sh [PUBLIC_IP]

set -e

PUBLIC_IP="${1:-$(hostname -I | awk '{print $1}')}"
MOX_HOME="/home/mox"
DOMAIN="${MOX_DOMAIN:-example.com}"

echo "=== Mox Health Check ==="
echo "Date: $(date)"
echo "Public IP: $PUBLIC_IP"
echo

# Service status
echo "Service Status:"
if systemctl is-active --quiet mox; then
    echo "  [OK] Mox service is running"
else
    echo "  [FAIL] Mox service is not running"
    echo "  Run: journalctl -u mox -n 50"
fi
echo

# Port connectivity
echo "Port Connectivity:"

# Web interface (localhost)
if timeout 2 bash -c "</dev/tcp/localhost/8080" 2>/dev/null; then
    echo "  [OK] Port 8080 (web) - localhost"
else
    echo "  [FAIL] Port 8080 (web) - localhost"
fi

# SMTP
if timeout 2 bash -c "</dev/tcp/$PUBLIC_IP/25" 2>/dev/null; then
    echo "  [OK] Port 25 (SMTP)"
else
    echo "  [FAIL] Port 25 (SMTP)"
fi

# SMTPS
if timeout 2 bash -c "</dev/tcp/$PUBLIC_IP/465" 2>/dev/null; then
    echo "  [OK] Port 465 (SMTPS)"
else
    echo "  [FAIL] Port 465 (SMTPS)"
fi

# Submission
if timeout 2 bash -c "</dev/tcp/$PUBLIC_IP/587" 2>/dev/null; then
    echo "  [OK] Port 587 (Submission)"
else
    echo "  [FAIL] Port 587 (Submission)"
fi

# IMAPS
if timeout 2 bash -c "</dev/tcp/$PUBLIC_IP/993" 2>/dev/null; then
    echo "  [OK] Port 993 (IMAPS)"
else
    echo "  [FAIL] Port 993 (IMAPS)"
fi
echo

# Certificate check
echo "Certificate Status:"
if [ -f "$MOX_HOME/certs/mail.$DOMAIN.crt" ]; then
    EXPIRY=$(openssl x509 -enddate -noout -in "$MOX_HOME/certs/mail.$DOMAIN.crt" 2>/dev/null | cut -d= -f2)
    echo "  [OK] Certificate exists"
    echo "       Expires: $EXPIRY"
else
    echo "  [FAIL] Certificate not found at $MOX_HOME/certs/mail.$DOMAIN.crt"
fi
echo

# Configuration test
echo "Configuration:"
if sudo -u mox "$MOX_HOME/mox" config test >/dev/null 2>&1; then
    echo "  [OK] Configuration is valid"
else
    echo "  [FAIL] Configuration has errors"
    echo "  Run: sudo -u mox $MOX_HOME/mox config test"
fi
echo

# Disk usage
echo "Disk Usage:"
if [ -d "$MOX_HOME/data" ]; then
    du -sh "$MOX_HOME/data" 2>/dev/null || echo "  Unable to check"
else
    echo "  Data directory not found"
fi
echo

# Recent errors
echo "Recent Errors (last hour):"
ERROR_COUNT=$(journalctl -u mox --since "1 hour ago" -p err --no-pager 2>/dev/null | grep -v "^--" | wc -l)
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "  Found $ERROR_COUNT error(s):"
    journalctl -u mox --since "1 hour ago" -p err --no-pager -n 5 2>/dev/null | tail -5
else
    echo "  No errors in the last hour"
fi
echo

echo "=== Health Check Complete ==="
