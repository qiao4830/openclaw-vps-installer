#!/usr/bin/env bash

# ==================================================
# OpenClaw Nautical Pro Installer (4.0)
# --------------------------------------------------
# 适用场景: 1G/2G RAM VPS 
# 核心特性: 自动 Swap、BBR 加速、官方静默安装
# 频道主页: https://www.youtube.com/@cnxiaofanchuan
# Author: xfc-yt (小帆船)
# ==================================================

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SWAPFILE="/swapfile"
SWAP_SIZE="1G"
SYSCTL_FILE="/etc/sysctl.d/99-openclaw-tuning.conf"

OPENCLAW_INSTALL_METHOD="${OPENCLAW_INSTALL_METHOD:-git}"
OPENCLAW_VERSION="${OPENCLAW_VERSION:-latest}"
OPENCLAW_GIT_DIR="${OPENCLAW_GIT_DIR:-/opt/openclaw}"

log()  { echo -e "\033[1;34m[$SCRIPT_NAME]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[$SCRIPT_NAME]\033[0m $*"; }
warn() { echo -e "\033[1;33m[$SCRIPT_NAME]\033[0m $*" >&2; }
err()  { echo -e "\033[1;31m[$SCRIPT_NAME]\033[0m $*" >&2; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "请用 root 运行：sudo bash $SCRIPT_NAME"
    exit 1
  fi
}

check_os() {
  if [[ ! -r /etc/os-release ]]; then
    err "无法识别系统版本，缺少 /etc/os-release"
    exit 1
  fi

  . /etc/os-release

  case "${ID:-}" in
    ubuntu|debian) ;;
    *)
      warn "当前系统是 ${PRETTY_NAME:-unknown}，脚本主要针对 Ubuntu / Debian 测试。"
      ;;
  esac
}

check_network() {
  log "检查基础网络连通性..."
  if ! ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
    err "无法连通外网 IP，先检查 VPS 网络。"
    exit 1
  fi

  if ! getent hosts openclaw.ai >/dev/null 2>&1; then
    err "DNS 解析 openclaw.ai 失败，请先修复 DNS。"
    exit 1
  fi

  ok "网络检查通过。"
}

setup_swap() {
  log "检查 Swap..."

  if swapon --show | grep -q "^${SWAPFILE}"; then
    ok "Swap 已启用：${SWAPFILE}"
    return
  fi

  if [[ -f "${SWAPFILE}" ]]; then
    log "检测到已有 swapfile，尝试启用..."
    chmod 600 "${SWAPFILE}"
    mkswap "${SWAPFILE}" >/dev/null 2>&1 || true
    swapon "${SWAPFILE}"
  else
    log "创建 ${SWAP_SIZE} Swap..."
    fallocate -l "${SWAP_SIZE}" "${SWAPFILE}" || dd if=/dev/zero of="${SWAPFILE}" bs=1M count=1024 status=progress
    chmod 600 "${SWAPFILE}"
    mkswap "${SWAPFILE}"
    swapon "${SWAPFILE}"
  fi

  if ! grep -q "^${SWAPFILE} " /etc/fstab; then
    echo "${SWAPFILE} none swap sw 0 0" >> /etc/fstab
  fi

  ok "Swap 已配置完成。"
}

setup_bbr() {
  log "配置 BBR..."

  cat > "${SYSCTL_FILE}" <<'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

  sysctl --system >/dev/null 2>&1 || warn "sysctl 应用失败，可能当前内核不支持 BBR。"

  if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q "bbr"; then
    ok "BBR 已启用。"
  else
    warn "BBR 未确认启用，脚本继续执行。"
  fi
}

install_base_packages() {
  log "安装基础依赖..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y curl ca-certificates git wget procps iproute2 dnsutils
  ok "基础依赖已安装。"
}

run_openclaw_installer() {
  log "开始执行官方 OpenClaw Installer..."

  export OPENCLAW_NO_PROMPT=1
  export OPENCLAW_NO_ONBOARD=1
  export OPENCLAW_INSTALL_METHOD
  export OPENCLAW_VERSION
  export OPENCLAW_GIT_DIR

  curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash -s -- --no-onboard

  ok "官方安装流程执行完成。"
}

post_check() {
  log "执行安装后检查..."

  if command -v openclaw >/dev/null 2>&1; then
    ok "检测到 openclaw 命令：$(command -v openclaw)"
  else
    warn "未在当前 shell 检测到 openclaw 命令，重新登录 SSH 后再试。"
  fi

  if command -v node >/dev/null 2>&1; then
    ok "Node 版本：$(node -v)"
  fi

  echo
  echo "======================================"
  echo "OpenClaw 部署完成"
  echo "======================================"
  echo "下一步提示："
  echo "1) 重新登录 SSH (或输入 source ~/.bashrc) 刷新环境变量"
  echo "2) 运行: openclaw --help"
  echo "3) 如需初始化守护进程: openclaw onboard --install-daemon"
  echo "======================================"
}

main() {
  require_root
  check_os
  check_network
  setup_swap
  setup_bbr
  install_base_packages
  run_openclaw_installer
  post_check
}

main "$@"
