#!/usr/bin/env bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║                                                                  ║
# ║             小帆船 (cnxiaofanchuan) - 航海员专用脚本               ║
# ║                                                                  ║
# ╠══════════════════════════════════════════════════════════════════╣
# ║  版本：v1.2.6 | 核心：OAuth 零隧道白嫖版 | 适配：1G 内存低配机       ║
# ║  GitHub: qiao4830/openclaw-vps-installer                         ║
# ╚══════════════════════════════════════════════════════════════════╝

if [ "$(id -u)" -ne 0 ]; then 
    echo "Error: Must run as root"; exit 1
fi

# --- 颜色定义 ---
: "${xfc_hong:='\033[31m'}"    
: "${xfc_lv:='\033[32m'}"      
: "${xfc_huang:='\033[33m'}"    
: "${xfc_lan:='\033[96m'}"     
: "${xfc_bai:='\033[0m'}"       

# --- 系统优化 (针对低配机) ---
xfc_system_check() {
    clear
    echo -e "${xfc_lan}>>> 正在执行系统环境优化...${xfc_bai}"
    local mem_total=$(free -m | grep Mem | awk '{print $2}')
    if [ "$mem_total" -lt 1500 ] && [ ! -f /xfc_swap ]; then
        echo -e "${xfc_huang}检测到内存不足，正在划拨 2G 虚拟内存...${xfc_bai}"
        fallocate -l 2G /xfc_swap && chmod 600 /xfc_swap && mkswap /xfc_swap && swapon /xfc_swap
        grep -q "/xfc_swap" /etc/fstab || echo '/xfc_swap none swap sw 0 0' >> /etc/fstab
    fi
    export NODE_OPTIONS="--max-old-space-size=512"
    export NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache
    mkdir -p /var/tmp/openclaw-compile-cache
}

# --- 环境部署 ---
xfc_install_env() {
    local node_ver="v22.16.0"
    local node_path="/opt/xfc_node"
    if [ ! -d "$node_path" ]; then
        echo -e "${xfc_lan}正在部署 Node.js 环境...${xfc_bai}"
        apt update -y && apt install -y xz-utils wget lsof python3 git
        local arch=$(uname -m); local node_bin="node-$node_ver-linux-x64.tar.xz"
        [ "$arch" == "aarch64" ] && node_bin="node-$node_ver-linux-arm64.tar.xz"
        wget -c "https://nodejs.org/dist/$node_ver/$node_bin" -O /tmp/node.tar.xz
        mkdir -p "$node_path"; tar -xJf /tmp/node.tar.xz -C "$node_path" --strip-components=1
        ln -sf "$node_path/bin/node" /usr/local/bin/node; ln -sf "$node_path/bin/npm" /usr/local/bin/npm
        rm -f /tmp/node.tar.xz
    fi
    if ! command -v openclaw &>/dev/null; then
        echo -e "${xfc_lan}正在安装 OpenClaw 核心...${xfc_bai}"
        npm install -g openclaw@latest --family=ipv4 --no-fund --no-audit --engine-strict=false
    fi
    if [ ! -f "/usr/local/bin/cli-proxy-api" ]; then
        echo -e "${xfc_lan}正在部署 Google OAuth 代理组件...${xfc_bai}"
        local p_arch="amd64"; [ "$(uname -m)" == "aarch64" ] && p_arch="arm64"
        wget -qO /usr/local/bin/cli-proxy-api "https://github.com/Joye-at-GitHub/cli-proxy-api/releases/latest/download/cli-proxy-api-linux-$p_arch"
        chmod +x /usr/local/bin/cli-proxy-api
    fi
    ln -sf "$(readlink -f "$0")" /usr/local/bin/xfc; chmod +x /usr/local/bin/xfc
}

# --- OAuth 核心逻辑 ---
xfc_auth_google() {
    clear
    echo -e "${xfc_lan}>>> 准备进入 Google OAuth 授权中心 (零隧道模式)...${xfc_bai}"
    echo -e "  1. 浏览器打开随后出现的链接完成授权。"
    echo -e "  2. 授权后页面报错属于正常，请直接复制地址栏完整 URL 粘贴回这里。"
    sleep 2
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
    openclaw models add google --base-url http://127.0.0.1:8085/v1 --api-key "xfc-free-token"
    openclaw models set "google/gemini-1.5-flash-latest"
    echo -e "${xfc_lv}✅ OAuth 授权完成，白嫖通道已开启！${xfc_bai}"
}

# --- 主菜单 ---
xfc_main_menu() {
    clear
    echo -e "${xfc_lan}    小帆船 (cnxiaofanchuan) - 航海员专用脚本 v1.2.6${xfc_bai}"
    echo -e "  [1] 安装环境 | [2] OAuth 授权 | [3] 启动 OpenClaw"
    echo -e "  [4] 停止 OpenClaw | [5] 机器人授权 | [6] 卸载 | [0] 退出"
    echo
    read -p "  请选择: " xfc_choice
    case "$xfc_choice" in
        1) xfc_system_check; xfc_install_env; read -p "环境就绪，回车返回菜单..."; xfc_main_menu ;;
        2) xfc_auth_google; read -p "授权完成，回车返回菜单..."; xfc_main_menu ;;
        3) export NODE_OPTIONS="--max-old-space-size=512"; openclaw gateway start; read -p "启动成功，回车返回..."; xfc_main_menu ;;
        4) openclaw gateway stop; read -p "已停止..."; xfc_main_menu ;;
        5) read -p "请输入连接码: " xfc_pcode; [ -n "$xfc_pcode" ] && openclaw pairing approve telegram "$xfc_pcode"; xfc_main_menu ;;
        6) npm uninstall -g openclaw; rm -rf ~/.openclaw /opt/xfc_node /usr/local/bin/xfc /usr/local/bin/cli-proxy-api /xfc_swap; exit 0 ;;
        0) exit 0 ;;
        *) xfc_main_menu ;;
    esac
}
xfc_main_menu
