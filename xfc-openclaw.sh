#!/usr/bin/env bash

# 权限检查
[[ "$(id -u)" -ne 0 ]] && { printf "Error: Please run as root\n"; exit 1; }

# 深度优化
xfc_system_check() {
    clear
    printf ">>> 正在执行低配机生存优化...\n"
    local mem_total=$(free -m | grep Mem | awk '{print $2}')
    if [ "$mem_total" -lt 1500 ] && [ ! -f /xfc_swap ]; then
        fallocate -l 2G /xfc_swap && chmod 600 /xfc_swap && mkswap /xfc_swap && swapon /xfc_swap
        grep -q "/xfc_swap" /etc/fstab || echo '/xfc_swap none swap sw 0 0' >> /etc/fstab
    fi
    export NODE_OPTIONS="--max-old-space-size=512"
}

# 环境部署
xfc_install_env() {
    local node_ver="v22.16.0"
    local node_path="/opt/xfc_node"
    if [ ! -d "$node_path" ]; then
        apt update -y && apt install -y xz-utils wget lsof python3 git
        local arch=$(uname -m); local node_bin="node-$node_ver-linux-x64.tar.xz"
        [ "$arch" == "aarch64" ] && node_bin="node-$node_ver-linux-arm64.tar.xz"
        wget -c "https://nodejs.org/dist/$node_ver/$node_bin" -O /tmp/node.tar.xz
        mkdir -p "$node_path"; tar -xJf /tmp/node.tar.xz -C "$node_path" --strip-components=1
        ln -sf "$node_path/bin/node" /usr/local/bin/node; ln -sf "$node_path/bin/npm" /usr/local/bin/npm
        rm -f /tmp/node.tar.xz
    fi
    command -v openclaw &>/dev/null || npm install -g openclaw@latest --family=ipv4 --engine-strict=false
    if [ ! -f "/usr/local/bin/cli-proxy-api" ]; then
        local p_arch="amd64"; [[ "$(uname -m)" == "aarch64" ]] && p_arch="arm64"
        wget -qO /usr/local/bin/cli-proxy-api "https://github.com/Joye-at-GitHub/cli-proxy-api/releases/latest/download/cli-proxy-api-linux-$p_arch"
        chmod +x /usr/local/bin/cli-proxy-api
    fi
    ln -sf "$(readlink -f "$0")" /usr/local/bin/xfc; chmod +x /usr/local/bin/xfc
}

# OAuth 授权
xfc_auth_google() {
    clear
    printf ">>> 授权后直接复制报错页面的 URL 粘贴到下方：\n"
    cli-proxy-api auth
    local config_file="${HOME}/.openclaw/openclaw.json"
    python3 -c "
import json, os
path = '$config_file'
os.makedirs(os.path.dirname(path), exist_ok=True)
data = json.load(open(path)) if os.path.exists(path) else {}
data.setdefault('gateway', {})['mode'] = 'local'
data.setdefault('agents', {}).setdefault('defaults', {})['model'] = {'primary': 'google/gemini-1.5-flash-latest'}
json.dump(data, open(path, 'w'), indent=2)
"
    openclaw models remove google 2>/dev/null
    openclaw models add google --base-url http://127.0.0.1:8085/v1 --api-key "free"
    openclaw models set "google/gemini-1.5-flash-latest"
    printf "✅ OAuth 绑定成功！\n"
}

# --- 菜单重绘 (完全取消左右分栏，直接竖排，100% 对齐) ---
xfc_main_menu() {
    clear
    printf "================================================\n"
    printf "   小帆船 (cnxiaofanchuan) 航海员专用脚本 v1.2.6 \n"
    printf "================================================\n"
    printf "  [1] 安装部署环境 (低配优化模式)\n"
    printf "  [2] Google OAuth 授权 (零隧道白嫖)\n"
    printf "  [3] 启动 OpenClaw 服务\n"
    printf "  [4] 停止 OpenClaw 服务\n"
    printf "  [5] 机器人 Pairing 授权\n"
    printf "  [6] 彻底卸载清理\n"
    printf "  [0] 退出脚本\n"
    printf "================================================\n"
    printf "\n"
    read -p "  请输入数字选择: " xfc_choice
    case "$xfc_choice" in
        1) xfc_system_check; xfc_install_env; read -p "完成，回车继续..."; xfc_main_menu ;;
        2) xfc_auth_google; read -p "完成，回车继续..."; xfc_main_menu ;;
        3) export NODE_OPTIONS="--max-old-space-size=512"; openclaw gateway start; read -p "已启动，回车继续..."; xfc_main_menu ;;
        4) openclaw gateway stop; read -p "已停止..."; xfc_main_menu ;;
        5) read -p "连接码: " xfc_pcode; [[ -n "$xfc_pcode" ]] && openclaw pairing approve telegram "$xfc_pcode"; xfc_main_menu ;;
        6) npm uninstall -g openclaw; rm -rf ~/.openclaw /opt/xfc_node /usr/local/bin/xfc /usr/local/bin/cli-proxy-api; exit 0 ;;
        0) exit 0 ;;
        *) xfc_main_menu ;;
    esac
}
xfc_main_menu
