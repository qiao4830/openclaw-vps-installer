#!/usr/bin/env bash

# 1. 强制使用 Bash 环境运行
if [ -z "$BASH_VERSION" ]; then
    printf "\033[31m错误：请使用 bash 运行此脚本 (bash xfc-openclaw.sh)\033[0m\n"
    exit 1
fi

[[ "$(id -u)" -ne 0 ]] && { printf "\033[31mError: 请使用 root 用户运行\033[0m\n"; exit 1; }

# 2. 系统深度优化
xfc_system_check() {
    clear
    printf "\033[96m>>> 正在执行低配机生存优化...\033[0m\n"
    local mem_total=$(free -m | grep Mem | awk '{print $2}')
    if [ "$mem_total" -lt 1500 ] && [ ! -f /xfc_swap ]; then
        fallocate -l 2G /xfc_swap && chmod 600 /xfc_swap && mkswap /xfc_swap && swapon /xfc_swap
        grep -q "/xfc_swap" /etc/fstab || echo '/xfc_swap none swap sw 0 0' >> /etc/fstab
    fi
    export NODE_OPTIONS="--max-old-space-size=512"
    export NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache
    mkdir -p /var/tmp/openclaw-compile-cache
}

# 3. 环境部署
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

# 4. OAuth 逻辑
xfc_auth_google() {
    clear
    printf "\033[96m>>> 授权后直接复制报错页面的 URL 粘贴到下方：\033[0m\n"
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
    openclaw models add google --base-url http://127.0.0.1:8085/v1 --api-key "xfc-free"
    openclaw models set "google/gemini-1.5-flash-latest"
    printf "\033[32m✅ OAuth 绑定成功！\033[0m\n"
}

# 5. 菜单重绘 (采用 printf 逐行精准控制)
xfc_main_menu() {
    clear
    printf "\033[96m+------------------------------------------------------------+\033[0m\n"
    printf "\033[96m|         小帆船 (cnxiaofanchuan) - 航海员专用脚本 v1.2.6    |\033[0m\n"
    printf "\033[96m+------------------------------------------------------------+\033[0m\n"
    printf "  [1] \033[32m安装环境\033[0m  |  [2] \033[33mOAuth 授权\033[0m  |  [3] 启动 OpenClaw\n"
    printf "  [4] 停止 OpenClaw  |  [5] 机器人授权   |  [6] \033[31m卸载清理\033[0m\n"
    printf "  [0] 退出脚本\n"
    printf "\033[96m+------------------------------------------------------------+\033[0m\n"
    printf "\n"
    read -p "  请选择: " xfc_choice
    case "$xfc_choice" in
        1) xfc_system_check; xfc_install_env; read -p "完成，回车继续..."; xfc_main_menu ;;
        2) xfc_auth_google; read -p "完成，回车继续..."; xfc_main_menu ;;
        3) export NODE_OPTIONS="--max-old-space-size=512"; openclaw gateway start; read -p "已启动，回车继续..."; xfc_main_menu ;;
        4) openclaw gateway stop; read -p "已停止..."; xfc_main_menu ;;
        5) read -p "Pairing code: " xfc_pcode; [[ -n "$xfc_pcode" ]] && openclaw pairing approve telegram "$xfc_pcode"; xfc_main_menu ;;
        6) npm uninstall -g openclaw; rm -rf ~/.openclaw /opt/xfc_node /usr/local/bin/xfc /usr/local/bin/cli-proxy-api /xfc_swap; exit 0 ;;
        0) exit 0 ;;
        *) xfc_main_menu ;;
    esac
}
xfc_main_menu
