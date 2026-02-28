# SSH – autenticação somente por chave pública

Configuração para que o SSH aceite **apenas** login por chave pública (sem senha).

## Atenção

**Antes de desativar login por senha:**

1. Adicione sua chave pública no servidor (no usuário que você usa para SSH):
   ```bash
   # No seu PC (não no VPS)
   cat ~/.ssh/id_rsa.pub
   # ou
   cat ~/.ssh/id_ed25519.pub
   ```
2. No VPS, no usuário que você usa para SSH:
   ```bash
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   echo "SUA_CHAVE_PUBLICA_AQUI" >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```
3. **Teste o login com chave** em outra aba/terminal antes de desativar senha:
   ```bash
   ssh -i ~/.ssh/sua_chave_privada usuario@ip-do-vps
   ```
   Se funcionar, prossiga. Se não, não desative a senha.

## Aplicar configuração (chave somente)

No VPS, com usuário que tenha sudo:

```bash
cd /caminho/do/repo/infrastructure/ssh
sudo ./configure-key-only.sh
```

Ou aplique manualmente as opções em `/etc/ssh/sshd_config` (veja `sshd-config-snippet.conf`) e reinicie o SSH:

```bash
sudo systemctl restart sshd
# ou
sudo systemctl restart ssh
```

**Importante:** Mantenha uma sessão SSH aberta enquanto testa uma nova sessão. Só feche a primeira depois de confirmar que o login por chave funciona.

## O que a configuração altera

| Opção | Valor | Significado |
|-------|--------|-------------|
| `PubkeyAuthentication` | `yes` | Permite login por chave pública |
| `PasswordAuthentication` | `no` | Desativa login por senha |
| `PermitRootLogin` | `prohibit-password` | Root só por chave (ou use `no` se não usar root) |
| `ChallengeResponseAuthentication` | `no` | Desativa outros métodos de senha |

## Reverter (se trancar fora)

Se você desativou a senha e perdeu o acesso por chave, use o console do provedor do VPS (painel web, “Serial console”, “Recovery”, etc.) para fazer login como root e:

1. Reverter as alterações em `/etc/ssh/sshd_config`
2. `systemctl restart sshd`
3. Configurar de novo a chave em `~/.ssh/authorized_keys` e testar antes de desativar senha outra vez.
