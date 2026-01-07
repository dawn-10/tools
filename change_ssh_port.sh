#!/usr/bin/env bash
set -euo pipefail

### ===== 基础参数 =====
NEW_PORT=324
SSH_CONF="/etc/ssh/sshd_config"
TIME_NOW=$(date '+%F %T')
BACKUP="/etc/ssh/sshd_config.bak.$(date +%F_%H-%M-%S)"

### ===== 样式 =====
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

ok()    { echo -e "${GREEN}[  OK  ]${RESET} $1"; }
info()  { echo -e "${BLUE}[ INFO ]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[ WARN ]${RESET} $1"; }
fail()  { echo -e "${RED}[ FAIL ]${RESET} $1"; exit 1; }

clear

echo -e "${BLUE}"
echo "=================================================="
echo "   Universal SSH Port Change Script"
echo "--------------------------------------------------"
echo "   Change SSH Port : 22  →  ${NEW_PORT}"
echo "   Start Time      : ${TIME_NOW}"
echo "=================================================="
echo -e "${RESET}"

### ===== 权限检查 =====
info "Checking root privileges"
[[ $EUID -eq 0 ]] || fail "Please run this script as root"

### ===== 备份配置 =====
info "Backing up sshd_config"
cp -a "$SSH_CONF" "$BACKUP"
ok "Backup created: $BACKUP"

### ===== 修改配置 =====
info "Removing existing Port directives"
sed -i '/^[[:space:]]*Port[[:space:]]\+/d' "$SSH_CONF"
ok "Old Port entries removed"

info "Setting new SSH port: ${NEW_PORT}"
echo "Port ${NEW_PORT}" >> "$SSH_CONF"
ok "New Port configured"

### ===== 配置校验 =====
info "Validating sshd configuration"
sshd -t || fail "sshd config validation failed"
ok "sshd configuration is valid"

### ===== 重启服务 =====
info "Restarting SSH service"
if systemctl list-unit-files | grep -q '^sshd.service'; then
  systemctl restart sshd
  ok "Service restarted: sshd"
elif systemctl list-unit-files | grep -q '^ssh.service'; then
  systemctl restart ssh
  ok "Service restarted: ssh"
else
  fail "SSH service not found"
fi

### ===== 完成 =====
echo
echo -e "${GREEN}✔ SSH port successfully changed to ${NEW_PORT}${RESET}"
echo -e "${YELLOW}⚠ Please ensure port ${NEW_PORT} is allowed in your firewall${RESET}"
echo -e "${BLUE}ℹ Test command:${RESET} ssh -p ${NEW_PORT} user@server_ip"
echo
