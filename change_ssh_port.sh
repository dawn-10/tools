#!/usr/bin/env bash

NEW_PORT=324
OLD_PORT=22
TIME=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="/etc/ssh/backup_$TIME"

set -e

clear
echo "=================================================="
echo "        SSH 服务端口修改脚本V1.0"
echo "--------------------------------------------------"
echo "        修改内容 : $OLD_PORT  →  $NEW_PORT"
echo "        执行时间 : $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================="
echo

# ---------- 基础检查 ----------
echo "[ 信息 ] 正在检查是否为 root 用户"
if [ "$EUID" -ne 0 ]; then
  echo "[ 失败 ] 请使用 root 用户执行脚本"
  exit 1
fi

# ---------- 识别 SSH 服务名 ----------
SSH_SERVICE=""
if systemctl list-unit-files | grep -q "^ssh.service"; then
  SSH_SERVICE="ssh"
elif systemctl list-unit-files | grep -q "^sshd.service"; then
  SSH_SERVICE="sshd"
else
  echo "[ 失败 ] 未找到 SSH 服务"
  exit 1
fi
echo "[ 成功 ] SSH 服务名称：$SSH_SERVICE"

# ---------- 备份 ----------
echo "[ 信息 ] 正在备份 SSH 配置文件"
mkdir -p "$BACKUP_DIR"
cp -a /etc/ssh/* "$BACKUP_DIR/"
echo "[ 成功 ] 配置已备份至：$BACKUP_DIR"

# ---------- 修改 sshd_config ----------
SSHD_CONFIG="/etc/ssh/sshd_config"

echo "[ 信息 ] 正在清理旧的 Port 配置"
sed -i '/^Port[[:space:]]\+/d' "$SSHD_CONFIG"
echo "[ 成功 ] 旧 Port 配置已清理"

echo "[ 信息 ] 正在设置新的 SSH 端口：$NEW_PORT"
echo "Port $NEW_PORT" >> "$SSHD_CONFIG"
echo "[ 成功 ] 新端口已写入配置文件"

# ---------- Ubuntu / 云镜像关键修复 ----------
DEFAULT_SSH="/etc/default/ssh"
if [ -f "$DEFAULT_SSH" ]; then
  echo "[ 信息 ] 正在处理 /etc/default/ssh"
  sed -i 's/^SSHD_OPTS=.*/SSHD_OPTS=""/' "$DEFAULT_SSH"
  grep -q "^SSHD_OPTS=" "$DEFAULT_SSH" || echo 'SSHD_OPTS=""' >> "$DEFAULT_SSH"
  echo "[ 成功 ] SSHD_OPTS 已清空"
fi

# ---------- systemd override ----------
OVERRIDE_DIR="/etc/systemd/system/${SSH_SERVICE}.service.d"
OVERRIDE_FILE="$OVERRIDE_DIR/override.conf"

echo "[ 信息 ] 正在检查 systemd 覆盖配置"
mkdir -p "$OVERRIDE_DIR"
cat > "$OVERRIDE_FILE" <<EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/sshd -D
EOF
echo "[ 成功 ] systemd 启动参数已修复"

# ---------- 校验配置 ----------
echo "[ 信息 ] 正在校验 SSH 配置有效性"
if ! sshd -t; then
  echo "[ 失败 ] SSH 配置校验失败，正在回滚"
  cp -a "$BACKUP_DIR"/* /etc/ssh/
  systemctl restart "$SSH_SERVICE"
  exit 1
fi
echo "[ 成功 ] SSH 配置校验通过"

# ---------- 重载并重启 ----------
echo "[ 信息 ] 正在重载 systemd"
systemctl daemon-reexec

echo "[ 信息 ] 正在重启 SSH 服务"
systemctl restart "$SSH_SERVICE"
echo "[ 成功 ] SSH 服务已重启"

# ---------- 防火墙处理 ----------
echo "[ 信息 ] 正在检查防火墙规则"

if command -v firewall-cmd &>/dev/null && firewall-cmd --state &>/dev/null; then
  firewall-cmd --add-port=${NEW_PORT}/tcp --permanent
  firewall-cmd --reload
  echo "[ 成功 ] firewalld 已放行端口 $NEW_PORT"
elif command -v ufw &>/dev/null; then
  ufw allow ${NEW_PORT}/tcp
  echo "[ 成功 ] ufw 已放行端口 $NEW_PORT"
else
  echo "[ 提示 ] 未检测到防火墙或需手动放行端口"
fi

# ---------- 最终验证 ----------
echo
echo "=================================================="
echo "✔ SSH 端口已成功修改为 $NEW_PORT"
echo "ℹ 新连接方式： ssh -p $NEW_PORT 用户名@服务器IP"
echo "⚠ 请在新端口连接成功前不要关闭当前 SSH"
echo "=================================================="
