# Firewall (UFW)

Firewall configuration for the Abrigo stack on a Linux VPS (Ubuntu/Debian).

## Quick setup

```bash
sudo ./ufw-setup.sh
```

## Rules applied

| Port | Service | Note |
|------|---------|------|
| 22   | SSH     | Required for admin access; restrict by IP in production if possible |
| 80   | HTTP    | Nginx reverse proxy |
| 443  | HTTPS   | Nginx (enable after SSL certs are in place) |

PostgreSQL (5432) and Redis (6379) are **not** opened on the host in the default compose; they are bound to `127.0.0.1` or only exposed on the Docker network. The proxy is the single public entry point.

## Restrict SSH by IP (optional)

Edit `ufw-setup.sh` and replace the SSH rule with:

```bash
ufw allow from YOUR_OFFICE_OR_VPN_IP to any port 22 proto tcp comment 'SSH'
```

Then run the script again.

## Check status

```bash
sudo ufw status numbered
```

## Disable (emergency)

```bash
sudo ufw disable
```
