#!/usr/bin/env bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║                                                                  ║
# ║             小帆船 (cnxiaofanchuan) - 航海员专用脚本               ║
# ║                                                                  ║
# ╠══════════════════════════════════════════════════════════════════╣
# ║  版本：v1.2.6 | 核心OAuth 零隧道白嫖版 | 适配：1G 内存低配机        ║
# ║  YouTube : @cnxiaofanchuan  |  Telegram: t.me/vipxiaofanchuan    ║
# ╚══════════════════════════════════════════════════════════════════╝

# 0. Root 检查
if [ "$(id -u)" -ne 0 ]; then 
    echo "请使用 root 用户运行 (sudo bash $0)"; exit 1
fi

# --- 1. 颜色与基础变量 ---
: "${xfc_hong:='\033[31m'}"    
: "${xfc_lv:='\033[32m'}"      
: "${xfc_huang:='\033[33m'}"    
: "${xfc_lan:='\033[96m'}"     
: "${xfc_bai:='\033[0m'}"       

# --- 2. 系统深度优化 (针对 1G 内存) ---
xfc_system_check() {
    clear
    echo -e "${xfc_lan}>>> 正在执行低配机生存优化...${xfc_bai}"

    # [内存] Swap 强开逻辑
    local mem_total=$(free -m | grep Mem | awk '{print $2}')
    if [ "$mem_total" -lt 1500 ] && [ ! -f /xfc_swap ]; then
        echo -e "${xfc_huang}内存吃紧！正在划拨 2G 虚拟内存保障稳定...${xfc_bai}"
        fallocate -l 2G /xfc_swap && chmod 600 /xfc_swap && mkswap /xfc_swap && swapon /xfc_swap
        grep -q "/xfc_swap" /etc/fstab || echo '/xfc_swap none swap sw 0 0' >> /etc/fstab
        echo -e "状态: ${xfc_lv}2G 虚拟内存已就绪${xfc_bai}"
    fi

    # [性能压制变量]
    export NODE_OPTIONS="--max-old-space-size=512"
    export NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache
    mkdir -p /var/tmp/openclaw-compile-cache
}

# --- 3. 环境与白嫖组件部署 ---
xfc_install_env() {
    local node_ver="v22.16.0"
    local node_path="/opt/xfc_node"
    
    if [ ! -d "$node_path" ]; then
        echo -e "${xfc_lan}正在部署 Node.js 环境 ($node_ver)...${xfc_bai}"
        apt update -y && apt install -y xz-utils wget lsof python3 git
        local arch=$(uname -m); local node_bin="node-$node_ver-linux-x64.tar.xz"
        [ "$arch" == "aarch64" ] && node_bin="node-$node_ver-linux-arm64.tar.xz"
        wget -c "https://nodejs.org/dist/$node_ver/$node_bin" -O /tmp/node.tar.xz
        mkdir -p "$node_path"; tar -xJf /tmp/node.tar.xz -C "$node_path" --strip-components=1
        ln -sf "$node_path/bin/node" /usr/local/bin/node; ln -sf "$node_path/bin/npm" /usr/local/bin/npm
        rm -f /tmp/node.tar.xz
    fi

    # 安装 OpenClaw 核心
    if ! command -v openclaw &>/dev/null; then
        echo -e "${xfc_lan}正在安装 OpenClaw (核心大脑)...${xfc_bai}"
        npm install -g openclaw@latest --family=ipv4 --no-fund --no-audit --engine-strict=false
    fi

    # 安装 cli-proxy-api (白嫖中转站)
    if [ ! -f "/usr/local/bin/cli-proxy-api" ]; then
        echo -e "${xfc_lan}正在获取 Google OAuth 代理组件...${xfc_bai}"
        local p_arch="amd64"; [ "$(uname -m)" == "aarch64" ] && p_arch="arm64"
        wget -qO /usr/local/bin/cli-proxy-api "https://github.com/Joye-at-GitHub/cli-proxy-api/releases/latest/download/cli-proxy-api-linux-$p_arch"
        chmod +x /usr/local/bin/cli-proxy-api
    fi

    # 快捷键注册
    local script_path=$(readlink -f "$0")
    ln -sf "$script_path" /usr/local/bin/xfc; chmod +x /usr/local/bin/xfc
}

# --- 4. 零隧道 OAuth 授权逻辑 ---
xfc_auth_google() {
    clear
    echo -e "${xfc_lan}>>> 准备进入 Google OAuth 授权中心 (零隧道模式)...${xfc_bai}"
    echo -e "  1. 浏览器打开随后出现的链接进行授权。"
    echo -e "  2. 授权后页面报错属于【正常现象】，请勿关闭。"
    echo -e "  3. ${xfc_lv}直接复制浏览器地址栏的完整 URL${xfc_bai}，粘贴到下方即可。"
    sleep 2
    
    # 唤起 Joye 的核心授权握手
    cli-proxy-api auth
    
    # 静默修正配置文件，将 OpenClaw 指向本地代理
    local config_file="${HOME}/.openclaw/openclaw.json"
    python3 -c "
import json, os
path = '$config_file'
os.makedirs(os.path.dirname(path), exist_ok=True)
data = json.load(open(path)) if os.path.exists(path) else {}
data.setdefault('gateway', {})['mode'] = 'local'
agents = data.setdefault('agents', {})
defaults = agents.setdefault('defaults', {})
defaults['model'] = {'primary': 'google/gemini-1.5-flash-latest'}
json.dump(data, open(path, 'w'), indent=2)
"
    openclaw models remove google 2>/dev/null
    openclaw models add google --base-url http://127.0.0.1:8085/v1 --api-key "xfc-free-token"
    openclaw models set "google/gemini-1.5-flash-latest"
    echo -e "${xfc_lv}✅ OAuth 握手成功！白嫖通道已建立。${xfc_bai}"
}

# --- 5. 主菜单 ---
xfc_main_menu() {
    clear
    echo -e "${xfc_lan}    ╚══════════════════════════════════════════════════════════╝${xfc_bai}"
    echo -e "  [1] ${xfc_lv}一键安装环境${xfc_bai} (针对 1G 内存/白嫖优化)"
    echo -e "  [2] ${xfc_huang}Google OAuth 授权${xfc_bai} (报错页面 URL 粘贴回这里)"
    echo -e "  [3] 启动 OpenClaw"
    echo -e "  [4] 停止 OpenClaw"
    echo -e "  [5] 机器人 Pairing 授权"
    echo -e "  [6] 彻底卸载"
    echo -e "  [0] 退出脚本"
    echo
    read -p "  请选择 [0-6]: " xfc_choice
    case "$xfc_choice" in
        1) xfc_system_check; xfc_install_env; read -p "环境准备就绪，回车继续..."; xfc_main_menu ;;
        2) xfc_auth_google; read -p "授权完成，回车返回..."; xfc_main_menu ;;
        3) 
            export NODE_OPTIONS="--max-old-space-size=512"
            openclaw gateway start
            read -p "启动成功，回车返回..."; xfc_main_menu ;;
        4) openclaw gateway stop; read -p "已停止，回车返回..."; xfc_main_menu ;;
        5)
            read -p "请输入 Telegram 机器人给你的 8 位连接码: " xfc_pcode
            [ ! -z "$xfc_pcode" ] && openclaw pairing approve telegram "$xfc_pcode"
            read -p "按回车返回菜单..."; xfc_main_menu ;;
        6) npm uninstall -g openclaw; rm -rf ~/.openclaw /opt/xfc_node /usr/local/bin/xfc /usr/local/bin/cli-proxy-api /xfc_swap; echo "已清理"; exit 0 ;;
        0) exit 0 ;;
        *) xfc_main_menu ;;
    esac
}
xfc_main_menu
