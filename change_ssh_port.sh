#!/usr/bin/env bash
set -euo pipefail

### ===== 基础参数 =====
NEW_PORT=324
SSH_CONF="/etc/ssh/sshd_config"
TIME_NOW=$(date '+%F %T')
BACKUP="/etc/ssh/sshd_config.bak.$(date +%F_%H-%M-%S)"

### ===== 颜色样式 =====
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

ok()    { echo -e "${GREEN}[ 成功 ]${RESET} $1"; }
info()  { echo -e "${BLUE}[ 信息 ]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[ 警告 ]${RESET} $1"; }
fail()  { echo -e "${RED}[ 失败 ]${RESET} $1"; exit 1; }

clear

echo -e "${BLUE}"
echo "=================================================="
echo "        SSH 服务端口修改脚本（通用版）"
echo "--------------------------------------------------"
echo "        修改内容 : 22  →  ${NEW_PORT}"
echo "        执行时间 : ${TIME_NOW}"
echo "=================================================="
echo -e "${RESET}"

### ===== 权限检查 =====
info "正在检查是否为 root 用户"
[[ $EUID -eq 0 ]] || fail "请使用 root 用户执行该脚本"

### ===== 备份配置 =====
info "正在备份 SSH 配置文件"
cp -a "$SSH_CONF" "$BACKUP"
ok "配置已备份至：$BACKUP"

### ===== 修改配置 =====
info "正在清理旧的 Port 配置"
sed -i '/^[[:space:]]*Port[[:space:]]\+/d' "$SSH_CONF"
ok "旧 Port 配置已清理"

info "正在设置新的 SSH 端口：${NEW_PORT}"
echo "Port ${NEW_PORT}" >> "$SSH_CONF"
ok "新端口已写入配置文件"

### ===== 配置校验 =====
info "正在校验 SSH 配置有效性"
sshd -t || fail "SSH 配置校验失败，请检查配置文件"
ok "SSH 配置校验通过"

### ===== 重启服务 =====
info "正在重启 SSH 服务"
if systemctl list-unit-files | grep -q '^sshd.service'; then
  systemctl restart sshd
  ok "SSH 服务（sshd）已重启"
elif systemctl list-unit-files | grep -q '^ssh.service'; then
  systemctl restart ssh
  ok "SSH 服务（ssh）已重启"
else
  fail "未找到 SSH 服务，无法重启"
fi

### ===== 完成提示 =====
echo
echo -e "${GREEN}✔ SSH 端口已成功修改为 ${NEW_PORT}${RESET}"
echo -e "${YELLOW}⚠ 请确认防火墙已放行端口 ${NEW_PORT}${RESET}"
echo -e "${BLUE}ℹ 新连接示例：${RESET} ssh -p ${NEW_PORT} 用户名@服务器IP"
echo
