#!/usr/bin/env bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║                                                                  ║
# ║             小帆船 (cnxiaofanchuan) - 航海员专用脚本             ║
# ║                                                                  ║
# ╠══════════════════════════════════════════════════════════════════╣
# ║  版本：v1.2.3 | 核心：Joye OAuth 深度融合 | 状态：纯净 URL 修正  ║
# ║  YouTube : @cnxiaofanchuan  |  Telegram: t.me/vipxiaofanchuan    ║
# ╚══════════════════════════════════════════════════════════════════╝

# 0. 权限检查
[[ "$(id -u)" -ne 0 ]] && { echo "请使用 root 用户运行"; exit 1; }

# 颜色定义
xfc_lv='\033[32m'; xfc_lan='\033[96m'; xfc_huang='\033[33m'; xfc_bai='\033[0m'

# --- 1. 核心：授权与配置衔接 (完全参考 Joye 逻辑) ---
xfc_auto_setup() {
    clear
    # 1. 基础依赖预装 (防止 cli-proxy-api 运行失败)
    apt update -y && apt install -y wget curl lsof python3 ca-certificates
    
    # 2. 预下载白嫖组件 (Joye 逻辑的核心前置)
    if [ ! -f "/usr/local/bin/cli-proxy-api" ]; then
        printf "${xfc_lan}>>> 正在获取 Google OAuth 授权组件...${xfc_bai}\n"
        local p_arch="amd64"; [[ "$(uname -m)" == "aarch64" ]] && p_arch="arm64"
        wget -qO /usr/local/bin/cli-proxy-api "https://github.com/Joye-at-GitHub/cli-proxy-api/releases/latest/download/cli-proxy-api-linux-$p_arch"
        chmod +x /usr/local/bin/cli-proxy-api
    fi

    # 3. 强制唤起授权 (这里是衔接的关键：不拿到 Token 不往后走)
    printf "${xfc_huang}>>> 正在启动 Google OAuth 授权程序...${xfc_bai}\n"
    printf "请在浏览器打开链接授权，并将报错页面的 URL 粘贴到下方：\n"
    sleep 1
    /usr/local/bin/cli-proxy-api auth

    # 4. 环境安装 (拿到 Token 后的常规操作)
    xfc_install_env

    # 5. 配置自动注入
    printf "${xfc_lan}>>> 正在自动注入 OpenClaw 核心配置...${xfc_bai}\n"
    mkdir -p "${HOME}/.openclaw"
    python3 -c "
import json, os
path = os.path.expanduser('~/.openclaw/openclaw.json')
data = {
    'gateway': {'mode': 'local', 'port': 18789},
    'agents': {'defaults': {}},
    'session': {'reset': {'mode': 'idle', 'idleMinutes': 720}}
}
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
"
    # 6. 对接模型接口 (修正 URL 格式)
    openclaw models remove google 2>/dev/null
    openclaw models add google --base-url http://127.0.0.1:8085/v1 --api-key "xfc-free-token"
    
    printf "${xfc_lv}✅ 部署与授权衔接完成！请选择 [2] 启动服务。${xfc_bai}\n"
}

# --- 2. 基础环境安装 ---
xfc_install_env() {
    printf "${xfc_lan}>>> 正在部署 Node.js 22 环境...${xfc_bai}\n"
    # 内存优化
    local mem_total=$(free -m | grep Mem | awk '{print $2}')
    if [ "$mem_total" -lt 1500 ] && [ ! -f /xfc_swap ]; then
        fallocate -l 2G /xfc_swap && chmod 600 /xfc_swap && mkswap /xfc_swap && swapon /xfc_swap
        grep -q "/xfc_swap" /etc/fstab || echo '/xfc_swap none swap sw 0 0' >> /etc/fstab
    fi

    local node_path="/opt/xfc_node"
    if [ ! -d "$node_path" ]; then
        local arch=$(uname -m); local node_bin="node-v22.16.0-linux-x64.tar.xz"
        [[ "$arch" == "aarch64" ]] && node_bin="node-v22.16.0-linux-arm64.tar.xz"
        wget -c "https://nodejs.org/dist/v22.16.0/$node_bin" -O /tmp/node.tar.xz
        mkdir -p "$node_path"; tar -xJf /tmp/node.tar.xz -C "$node_path" --strip-components=1
        ln -sf "$node_path/bin/node" /usr/local/bin/node
        ln -sf "$node_path/bin/npm" /usr/local/bin/npm
        rm -f /tmp/node.tar.xz
    fi
    # 安装大脑
    command -v openclaw &>/dev/null || npm install -g openclaw@latest --family=ipv4 --engine-strict=false
    ln -sf "$(readlink -f "$0")" /usr/local/bin/xfc; chmod +x /usr/local/bin/xfc
}

# --- 3. 主菜单 ---
xfc_main_menu() {
    clear
    printf "${xfc_lan}             小帆船 (cnxiaofanchuan) - 航海员               ${xfc_bai}\n"
    printf "     ╚════════════════════════════════════════════════════╝\n"
    printf "  [1] ${xfc_lv}一键安装部署 & 自动授权${xfc_bai} (针对 1G 内存优化)\n"
    printf "  [2] 启动 OpenClaw & 代理\n"
    printf "  [3] 停止 OpenClaw & 代理\n"
    printf "  [4] 机器人 Pairing 授权\n"
    printf "  [5] 彻底卸载清理\n"
    printf "  [0] 退出脚本\n\n"
    read -p "  请选择 [0-5]: " xfc_choice
    case "$xfc_choice" in
        1) xfc_auto_setup; read -p "全部完成，回车返回菜单..."; xfc_main_menu ;;
        2) 
            lsof -i:8085 >/dev/null 2>&1 || nohup cli-proxy-api run >/dev/null 2>&1 &
            export NODE_OPTIONS="--max-old-space-size=512"
            openclaw gateway start
            read -p "服务已开启，回车返回..."; xfc_main_menu ;;
        3) openclaw gateway stop; pkill -9 cli-proxy-api; xfc_main_menu ;;
        4) read -p "连接码: " xfc_pcode; [[ -n "$xfc_pcode" ]] && openclaw pairing approve telegram "$xfc_pcode"; xfc_main_menu ;;
        5) 
            read -p "确认卸载清理吗? (y/N): " u_sure
            if [[ "$u_sure" =~ ^[Yy]$ ]]; then
                npm uninstall -g openclaw; rm -rf ~/.openclaw /opt/xfc_node /usr/local/bin/xfc /usr/local/bin/cli-proxy-api /xfc_swap; exit 0
            fi; xfc_main_menu ;;
        *) exit 0 ;;
    esac
}
xfc_main_menu
