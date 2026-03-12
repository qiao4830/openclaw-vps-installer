#!/bin/bash

# ==================================================
# OpenClaw Lite Installer
# Optimized for 1GB / 2GB VPS
# Author: xfc-yt
# ==================================================

set -e

echo "======================================"
echo " OpenClaw Lite Installer"
echo " Optimized for small VPS"
echo " Author: xfc-yt"
echo "======================================"

sleep 2

# 更新系统
echo "Updating system..."
apt update -y && apt upgrade -y

# 安装基础工具
echo "Installing dependencies..."
apt install -y curl git build-essential

# 安装 Node.js LTS
echo "Installing Node.js LTS..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs

# 创建安装目录
echo "Preparing install directory..."
mkdir -p /opt
cd /opt

# 下载 OpenClaw
echo "Cloning OpenClaw..."
git clone https://github.com/openclaw/openclaw.git
cd openclaw

# 安装依赖
echo "Installing npm dependencies..."
npm install --omit=dev

# 构建项目
echo "Building OpenClaw..."
npm run build || true

# 创建配置文件（示例）
echo "Creating default config..."
cat <<EOF > .env
PORT=3000
NODE_ENV=production
LOG_LEVEL=info
EOF

# 创建 systemd 服务
echo "Creating systemd service..."

cat <<EOF > /etc/systemd/system/openclaw.service
[Unit]
Description=OpenClaw AI Agent
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/openclaw
ExecStart=/usr/bin/node dist/index.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production
Environment=NODE_OPTIONS=--max-old-space-size=512

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd
systemctl daemon-reexec
systemctl daemon-reload

# 启动服务
systemctl enable openclaw
systemctl start openclaw

echo "======================================"
echo "OpenClaw installed successfully!"
echo ""
echo "Service status:"
echo "systemctl status openclaw"
echo ""
echo "View logs:"
echo "journalctl -u openclaw -f"
echo ""
echo "Default port:"
echo "3000"
echo "======================================"
echo "Script by xfc-yt"
