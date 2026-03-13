#!/usr/bin/env bash

# ==================================================
# OpenClaw Nautical Pro Installer (5.1 - 终极防卡版)
# --------------------------------------------------
# 适用场景: 1G/2G RAM VPS
# 核心特性: 自动 Swap、BBR 加速、网络防卡优化、IPv6 安全禁用
# 频道主页: https://www.youtube.com/@cnxiaofanchuan
# Author: xfc-yt (小帆船) + Gemini/Perplexity 调优
# ==================================================

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[🚢]${NC} $1"; }
warn() { echo -e "${YELLOW}[⚠️]${NC} $1"; }
err()  { echo -e "${RED}[❌]${NC} $1"; exit 1; }
ok()   { echo -e "${GREEN}[✅]${NC} $1"; }

# 1. 环境检查
check_env() {
  log "检查运行环境..."
  if [[ "$EUID" -ne 0 ]]; then
    err "请使用 root 运行本脚本。"
  fi
  if ! ping -c 1 registry.npmmirror.com >/dev/null 2>&1; then
    warn "无法连通 registry.npmmirror.com，使用官方 npm 源，安装可能较慢。"
  fi
}

# 2. 虚拟内存 Swap
setup_swap() {
  log "配置 2GB 虚拟内存 (Swap)..."
  if swapon --show | grep -q "/swapfile"; then
    ok "Swap 已存在。"
    return
  fi
  if ! fallocate -l 2G /swapfile 2>/dev/null; then
    warn "fallocate 失败，改用 dd 创建 swapfile..."
    dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
  fi
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  if ! grep -q "/swapfile" /etc/fstab; then
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi
  ok "Swap 开启成功。"
}

# 3. BBR 加速
setup_bbr() {
  log "开启 BBR 加速..."
  if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q "bbr"; then
    ok "BBR 已在运行。"
    return
  fi
  if ! grep -q "tcp_congestion_control" /etc/sysctl.conf 2>/dev/null; then
    cat >> /etc/sysctl.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
  fi
  sysctl -p >/dev/null 2>&1 || true
  ok "BBR 已启用。"
}

# 4. IPv6 安全禁用（临时 + GRUB 一次性）
disable_ipv6_safe() {
  log "安全禁用 IPv6 (防止 pnpm ECONNRESET)..."
  sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1 || true
  sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1 || true
  sysctl -w net.ipv6.conf.lo.disable_ipv6=1 >/dev/null 2>&1 || true

  if [[ -f /etc/default/grub ]] && ! grep -q "ipv6.disable=1" /etc/default/grub 2>/dev/null; then
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1 /' /etc/default/grub || true
    update-grub >/dev/null 2>&1 || warn "GRUB 更新失败，重启后 IPv6 可能恢复。"
  fi
  ok "IPv6 已在当前会话禁用。"
}

# 5. npm/pnpm 镜像 + 防卡配置
setup_npm_mirror() {
  log "配置 npm/pnpm 镜像与防卡参数..."
  # 使用 npmjs 或 npmmirror，优先淘宝
  if ping -c 1 registry.npmmirror.com >/dev/null 2>&1; then
    npm_registry="https://registry.npmmirror.com/"
  else
    npm_registry="https://registry.npmjs.org/"
  fi

  npm config set registry "${npm_registry}" >/dev/null 2>&1 || true
  npm config set fetch-timeout 120000 >/dev/null 2>&1 || true

  # Corepack 自带 pnpm，优先使用
  if command -v corepack >/dev/null 2>&1; then
    corepack enable pnpm >/dev/null 2>&1 || true
  fi

  if command -v pnpm >/dev/null 2>&1; then
    pnpm config set registry "${npm_registry}" >/dev/null 2>&1 || true
    pnpm config set network-concurrency 1 >/dev/null 2>&1 || true
    pnpm config set fetch-timeout 120000 >/dev/null 2>&1 || true
  fi

  ok "npm/pnpm 镜像与并发已配置：${npm_registry}"
}
# 6. 系统依赖与 Node.js
install_deps() {
  log "安装 Node.js 24 与系统依赖..."
  curl -fsSL https://deb.nodesource.com/setup_24.x | bash - >/dev/null 2>&1
  apt-get update -y >/dev/null 2>&1
  apt-get install -y -qq \
    build-essential python3 jq git procps curl wget cmake libatomic1 \
    ca-certificates iproute2 dnsutils >/dev/null 2>&1 || err "依赖安装失败。"
  ok "依赖安装完成。"
}

# 7. 安装 & 构建 OpenClaw
install_openclaw() {
  log "克隆 OpenClaw 源码..."
  rm -rf /opt/openclaw
  git clone --depth 1 https://github.com/openclaw/openclaw /opt/openclaw >/dev/null 2>&1 || err "克隆仓库失败。"

  cd /opt/openclaw

  log "清理历史安装残留..."
  rm -rf node_modules pnpm-lock.yaml ~/.local/share/pnpm/store 2>/dev/null || true

  # 7.1 优先使用 pnpm（10 分钟超时），失败再 npm ci
  if command -v pnpm >/dev/null 2>&1; then
    log "使用 pnpm 安装依赖 (最长 10 分钟)..."
    if timeout 600 pnpm install; then
      ok "pnpm 依赖安装成功。"
    else
      warn "pnpm 安装超时或失败，回退到 npm ci..."
      npm ci || err "npm ci 依赖安装失败。"
    fi
  else
    warn "未检测到 pnpm，直接使用 npm ci..."
    npm ci || err "npm ci 依赖安装失败。"
  fi

  # 7.2 构建：UI 失败也不影响 CLI
  log "开始构建 OpenClaw (UI + CLI)..."
  if command -v pnpm >/dev/null 2>&1; then
    if ! pnpm build; then
      warn "UI 构建失败，CLI 仍可正常使用。"
    fi
  else
    warn "pnpm 不可用，跳过 pnpm build。"
  fi

  # 7.3 创建 CLI 链接 + 全局安装（双通道）
  log "配置 openclaw 命令..."
  if [[ -x /opt/openclaw/bin/openclaw ]]; then
    ln -sf /opt/openclaw/bin/openclaw /usr/local/bin/openclaw
    chmod +x /usr/local/bin/openclaw
  fi

  if command -v npm >/dev/null 2>&1; then
    npm install -g openclaw@latest >/dev/null 2>&1 || true
  fi

  # 7.4 安装并启动网关守护进程
  if command -v openclaw >/dev/null 2>&1; then
    openclaw gateway install >/dev/null 2>&1 || true
  fi

  ok "OpenClaw 核心安装完成。"
}

# 8. 检查 CLI 是否可用
check_openclaw_cli() {
  if command -v openclaw >/dev/null 2>&1; then
    log "检测到 openclaw CLI：$(openclaw --version 2>/dev/null || echo '版本未知')"
    openclaw doctor || warn "openclaw doctor 返回非 0，可稍后手动排查。"
  else
    warn "当前会话未找到 openclaw 命令，重登 SSH 后再试。"
  fi
}
# 9. 部署完成后的交互菜单（保留原味）
show_menu() {
  local OPENCLAW_BIN
  OPENCLAW_BIN="$(command -v openclaw || echo '/opt/openclaw/bin/openclaw')"

  echo
  echo -e "${GREEN}======================================${NC}"
  echo -e "${GREEN}   OpenClaw Nautical Pro 5.1 就绪    ${NC}"
  echo -e "${GREEN}======================================${NC}"
  echo "1) ⚡ 启动完整初始化向导 (onboard)"
  echo "2) 🤖 仅配置 AI 模型 / API (models auth add)"
  echo "3) 💬 仅对接 Telegram (channels add)"
  echo "4) 退出"
  echo "======================================"

  read -rp "请输入序号 [1-4]: " choice

  if [[ ! -x "$OPENCLAW_BIN" && "$choice" != "4" ]]; then
    warn "当前会话找不到 openclaw，可重登 SSH 再执行 openclaw onboard。"
    return 0
  fi

  case "$choice" in
    1) "$OPENCLAW_BIN" onboard ;;
    2) "$OPENCLAW_BIN" models auth add ;;
    3) "$OPENCLAW_BIN" channels add ;;
    4) ok "安装结束，如要彻底禁用 IPv6 建议重启：sudo reboot" ;;
    *) warn "无效选择。" ;;
  esac
}

# 10. 主流程
main() {
  check_env
  setup_swap
  setup_bbr
  disable_ipv6_safe
  setup_npm_mirror
  install_deps
  install_openclaw
  check_openclaw_cli
  show_menu
  ok "🚢 Nautical Pro 5.1 部署完成！"
}

main "$@"
