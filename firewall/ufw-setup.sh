#!/bin/bash
# =============================================================================
# UFW firewall setup for Abrigo VPS
# Run as root or with sudo: sudo ./ufw-setup.sh
# Review and adjust rules before applying on production.
# =============================================================================
set -e

echo "[UFW] Configuring firewall..."

# Defaults
ufw default deny incoming
ufw default allow outgoing

# SSH - keep this open or you may lock yourself out
ufw allow 22/tcp comment 'SSH'

# HTTP and HTTPS (for nginx proxy)
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

# Optional: allow only from specific IP (e.g. office VPN)
# ufw delete allow 22/tcp
# ufw allow from 1.2.3.4 to any port 22 proto tcp comment 'SSH from office'

# Enable UFW (will prompt if not already enabled)
ufw --force enable

ufw status verbose

echo "[UFW] Done. Ensure SSH (22) is allowed before disconnecting."
