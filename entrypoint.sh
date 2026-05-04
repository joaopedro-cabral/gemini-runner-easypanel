#!/usr/bin/env bash
set -euo pipefail

if [ -z "${SSH_PASSWORD:-}" ]; then
  echo "ERRO: defina a variável SSH_PASSWORD no EasyPanel."
  exit 1
fi

echo "gemini:${SSH_PASSWORD}" | chpasswd

mkdir -p /run/sshd
mkdir -p /home/gemini/.gemini
chown -R gemini:gemini /home/gemini

sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config

echo "Gemini Runner iniciado. SSH habilitado para usuário gemini."
exec /usr/sbin/sshd -D -e
