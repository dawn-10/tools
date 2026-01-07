#!/usr/bin/env bash
# Universal SSH port change script
# Change SSH port from 22 to 324
# Works on: Ubuntu / Debian / CentOS / Rocky / Alma / RHEL

set -e

NEW_PORT=324
SSHD_CONFIG="/etc/ssh/sshd_config"

echo "======================================"
echo " Universal SSH Port Change Script"
echo " 22  -->  ${NEW_PORT}"
echo "======================================"

# 必须 root
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请使用 root 用户执行"
  exit 1
fi

# 检查 sshd_config 是否存在
if [ ! -f "$SSHD_CONFIG" ]; then
  echo "❌ 未找到 $SSHD_CONFIG"
  exit 1
fi

# 备份配置
BACKUP="${SSHD_CONFIG}.bak.$(date +%F_%H-%M-%S)"
echo "[1/5] 备份 sshd_config -> $BACKUP"
cp "$SSHD_CONFIG" "$BACKUP"

# 删除旧 Port 配置
echo "[2/5] 清理旧 Port 配置"
sed -i '/^[[:space:]]*Port[[:space:]]\+/d' "$SSHD_CONFIG"

# 写入新端口
echo "[3/5] 设置新端口 Port ${NEW_PORT}"
echo "Port ${NEW_PORT}" >> "$SSHD_CONFIG"

# 判断 SSH 服务名（兼容不同发行版）
echo "[4/5] 重启 SSH 服务"
if systemctl list-unit-files | grep -q '^sshd\.service'; then
  systemctl restart sshd
elif systemctl list-unit-files | grep -q '^ssh\.service'; then
  systemctl restart ssh
else
  echo "❌ 未找到 ssh/sshd 服务"
  exit 1
fi

# 输出最终生效端口
echo "[5/5] 当前 SSH 生效端口："
sshd -T 2>/dev/null | grep '^port '

echo "--------------------------------------"
echo "✔ 完成"
echo "请使用新端口登录："
echo "ssh -p ${NEW_PORT} root@服务器IP"
echo "======================================"
