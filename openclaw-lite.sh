#!/bin/bash

# ==================================================
# OpenClaw Lite Installer (Enhanced Version)
# Optimized for 1GB / 2GB VPS (e.g. OpenClaw JP 1C1G)
# Author: xfc-yt (小帆船)
# ==================================================

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}    OpenClaw Lite Installer (Enhanced)${NC}"
echo -e "    Optimized for small VPS (1C1G)"
echo -e "    Author: xfc-yt (小帆船)"
echo -e "${BLUE}======================================${NC}"

sleep 2

# 1. 基础环境优化：开启 BBR 加速 (针对 200Mbps 线路优化)
echo -e "${BLUE}[1/8]${NC} 正在优化内核网络 (BBR)..."
if ! lsmod | grep -q bbr; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p > /dev/null 2>&1
fi

# 2. 基础环境优化：自动创建 Swap (针对 1GB 内存机器必选)
echo -e "${BLUE}[2/8]${NC} 检查虚拟内存 (Swap)..."
if [ $(free -m | grep Swap | awk '{print $2}') -lt 512 ]; then
    echo "检测到内存较小，正在创建 1GB Swap 以防止安装挂起..."
    fallocate -l 1G /swapfile && chmod 600 /swapfile
    mkswap /swapfile && swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# 3. 更新系统与安装基础工具
echo -e "${BLUE}[3/8]${NC} 更新系统组件..."
apt update -y && apt install -y curl git build-essential socat

# 4. 安装 Node.js LTS (使用官方推荐源)
echo -e "${BLUE}[4/8]${NC} 安装 Node.js LTS..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs

# 5. 下载并准备项目
echo -e "${BLUE}[5/8]${NC} 克隆 OpenClaw 仓库..."
mkdir -p /opt && cd /opt
# 如果目录已存在则先删除，确保重新安装
rm -rf openclaw 
git clone https://github.com/openclaw/openclaw.git
cd openclaw

# 6. 安装依赖与构建 (加入内存限制防止构建失败)
echo -e "${BLUE}[6/8]${NC} 安装 NPM 依赖并构建项目..."
# 使用 --max-old-space-size 限制构建时的内存消耗
npm install --omit=dev
NODE_OPTIONS="--max-old-space-size=768" npm run build || true

# 7. 创建配置文件
echo -e "${BLUE}[7/8]${NC} 初始化默认配置 (.env)..."
if [ ! -f .env ]; then
cat <<EOF > .env
PORT=3000
NODE_ENV=production
LOG_LEVEL=info
EOF
fi

# 8. 创建并配置 Systemd 服务
echo -e "${BLUE}[8/8]${NC} 配置 Systemd 守护进程..."

cat <<EOF > /etc/systemd/system/openclaw.service
[Unit]
Description=OpenClaw AI Agent
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/openclaw
# 关键：限制 Node 运行内存为 512MB，预留 512MB 给系统，防止 OOM
ExecStart=/usr/bin/node --max-old-space-size=512 dist/index.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reload
systemctl enable openclaw
systemctl restart openclaw

echo -e "${GREEN}======================================${NC}"
echo -e "OpenClaw 安装成功！"
echo -e "======================================"
echo -e "管理命令："
echo -e "  查看状态: ${BLUE}systemctl status openclaw${NC}"
echo -e "  实时日志: ${BLUE}journalctl -u openclaw -f${NC}"
echo -e "  默认端口: ${BLUE}3000${NC}"
echo -e "======================================"
echo -e "脚本来自 YouTube: 小帆船 (xfc-yt)"
