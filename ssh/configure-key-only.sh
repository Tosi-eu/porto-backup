#!/bin/bash
# =============================================================================
# Configura o SSH para aceitar somente autenticação por chave pública.
# Execute como root ou com sudo: sudo ./configure-key-only.sh
#
# ANTES: garanta que sua chave pública está em ~/.ssh/authorized_keys e que
# você consegue entrar com: ssh -i ~/.ssh/sua_chave usuario@servidor
# =============================================================================
set -e

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP="${SSHD_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$SSHD_CONFIG" ]; then
  echo "[SSH] Arquivo não encontrado: $SSHD_CONFIG"
  exit 1
fi

echo "[SSH] Backup em: $BACKUP"
cp "$SSHD_CONFIG" "$BACKUP"

apply_option() {
  local key="$1"
  local value="$2"
  if grep -qE "^[[:space:]]*#?[[:space:]]*${key}[[:space:]]" "$SSHD_CONFIG"; then
    sed -i "s/^[[:space:]]*#?[[:space:]]*${key}[[:space:]].*/${key} ${value}/" "$SSHD_CONFIG"
  else
    echo "${key} ${value}" >> "$SSHD_CONFIG"
  fi
}

echo "[SSH] Aplicando opções para autenticação somente por chave..."
apply_option "PubkeyAuthentication" "yes"
apply_option "PasswordAuthentication" "no"
apply_option "PermitEmptyPasswords" "no"
apply_option "ChallengeResponseAuthentication" "no"
apply_option "KbdInteractiveAuthentication" "no"
apply_option "PermitRootLogin" "prohibit-password"

# Teste da configuração
echo "[SSH] Testando sshd_config..."
if sshd -t 2>/dev/null; then
  echo "[SSH] Configuração OK. Reiniciando sshd..."
  systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
  echo "[SSH] Pronto. Mantenha esta sessão aberta e teste em OUTRO terminal: ssh usuario@servidor"
else
  echo "[SSH] Erro na configuração. Restaurando backup."
  cp "$BACKUP" "$SSHD_CONFIG"
  exit 1
fi
