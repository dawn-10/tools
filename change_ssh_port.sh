#!/bin/bash
# 一键修改 SSH 端口：22 -> 324
# 适用于 Ubuntu / Debian
# 不涉及密钥 / 登录方式 / 防火墙

set -e

NEW_PORT=324
SSHD_CONFIG="/etc/ssh/sshd_config"

echo "======================================"
echo " SSH 端口修改脚本"
echo " 22  -->  ${NEW_PORT}"
echo "======================================"

if [ "$EUID" -ne 0 ]; then
  echo "❌ 请使用 root 用户运行"
  exit 1
fi

echo "[1/4] 备份 sshd_config"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%F_%H-%M-%S)"

echo "[2/4] 清除旧 Port 配置"
sed -i '/^Port /d' "$SSHD_CONFIG"

echo "[3/4] 写入新端口 Port ${NEW_PORT}"
echo "Port ${NEW_PORT}" >> "$SSHD_CONFIG"

echo "[4/4] 重启 SSH 服务"
systemctl restart ssh

echo "--------------------------------------"
echo "当前 SSH 监听端口："
sshd -T | grep '^port '
echo "--------------------------------------"
echo "✔ 完成"
echo "请使用以下方式登录："
echo "ssh -p ${NEW_PORT} root@服务器IP"
echo "======================================"
