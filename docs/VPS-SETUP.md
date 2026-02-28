# VPS setup guide

Step-by-step guide to deploy Abrigo on a single VPS using the infrastructure in this repo.

## 2. SSH somente com chave pública (recomendado)

No seu PC, gere uma chave se ainda não tiver: `ssh-keygen -t ed25519 -C "seu@email"`. Depois, no VPS:

```bash
# No VPS, no usuário que você usa para SSH
mkdir -p ~/.ssh
chmod 700 ~/.ssh
# Cole sua chave pública (id_ed25519.pub ou id_rsa.pub) na linha abaixo:
echo "sua-chave-publica-aqui" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Teste em **outro terminal** do seu PC: `ssh usuario@ip-do-vps`. Se entrar sem pedir senha, aplique no VPS:

```bash
cd /opt/abrigo/infrastructure/ssh
sudo chmod +x configure-key-only.sh
sudo ./configure-key-only.sh
```

Mantenha uma sessão SSH aberta até confirmar que o login por chave funciona. Veja `infrastructure/ssh/README.md` para detalhes e como reverter.

## 3. Install Docker

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER
# Log out and back in (or newgrp docker) so the group takes effect
```

## 4. Clone the repository

```bash
cd /opt  # or your preferred path
sudo git clone https://github.com/your-org/abrigo.git
cd abrigo
```

## 5. Environment file

```bash
cp .env.sample .env
nano .env   # or vim
```

Set at least:

- `DB_NAME`, `DB_USER`, `DB_PASSWORD` (PostgreSQL)
- `JWT_SECRET` (long random string for production)
- `ALLOWED_ORIGINS` (e.g. `https://seu-dominio.com`)
- `VITE_API_BASE_URL` (e.g. `https://seu-dominio.com/api/v1`) if the frontend is built with this env

## 6. Firewall

```bash
cd infrastructure/firewall
sudo chmod +x ufw-setup.sh
sudo ./ufw-setup.sh
```

Confirm SSH (22) is allowed before closing your session.

## 7. Start the stack

```bash
cd /opt/abrigo
docker compose -f infrastructure/docker-compose.yml up -d --build
```

Check:

```bash
docker compose -f infrastructure/docker-compose.yml ps
curl -I http://localhost
```

## 8. (Optional) HTTPS with Let’s Encrypt

On the VPS, install Certbot and obtain certificates:

```bash
sudo apt install -y certbot
sudo certbot certonly --standalone -d seu-dominio.com
```

Copy certs into the repo (adjust paths if Certbot uses different ones):

```bash
sudo cp /etc/letsencrypt/live/seu-dominio.com/fullchain.pem infrastructure/proxy/nginx/ssl/
sudo cp /etc/letsencrypt/live/seu-dominio.com/privkey.pem infrastructure/proxy/nginx/ssl/
sudo chown -R $USER:$USER infrastructure/proxy/nginx/ssl
```

Edit `infrastructure/proxy/nginx/conf.d/default.conf`: uncomment the HTTPS `server { ... }` block and set `server_name` to `seu-dominio.com`. Restart the proxy:

```bash
docker compose -f infrastructure/docker-compose.yml restart proxy
```

Point your domain’s DNS A record to the VPS IP. In `.env`, set `ALLOWED_ORIGINS=https://seu-dominio.com` and rebuild/restart the frontend if needed.

## 9. Backups off-server

Backups are in the Docker volume `backups`. To copy the latest backup to the host and then off the server:

```bash
docker run --rm -v abrigo_backups:/backups -v $(pwd):/out alpine sh -c "cp \$(ls -t /backups/backup_*.sql.gz | head -1) /out"
# Then rsync/scp the file from /opt/abrigo/ to another host or storage
```

Automate this with a cron job or a separate backup job that pushes to S3/another server.
