#!/usr/bin/env bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║                                                                  ║
# ║             小帆船 (cnxiaofanchuan) - 航海员专用脚本             ║
# ║                                                                  ║
# ╠══════════════════════════════════════════════════════════════════╣
# ║  版本：v1.3.8 | 核心：全自动级联部署 | 状态：纯净/避坑/极速      ║
# ║  YouTube : @cnxiaofanchuan  |  Telegram: t.me/vipxiaofanchuan    ║
# ╚══════════════════════════════════════════════════════════════════╝

# 0. 权限检查
[[ "$(id -u)" -ne 0 ]] && { echo "请使用 root 用户运行"; exit 1; }

# 颜色定义
xfc_lv='\033[32m'; xfc_lan='\033[96m'; xfc_huang='\033[33m'; xfc_bai='\033[0m'

# --- 核心流程：小帆船级联自动化流水线 ---
xfc_full_install() {
    clear
    # 1. 地基安装 (Node.js & OpenClaw)
    printf "${xfc_lan}>>> [1/7] 正在部署 Node.js 与 OpenClaw 环境...${xfc_bai}\n"
    xfc_install_env
    export PATH="/opt/xfc_node/bin:$PATH"
    hash -r

    # 2. OpenClaw 初始化 (Onboard)
    printf "${xfc_huang}>>> [2/7] 准备进入 OpenClaw 官方配置向导...${xfc_bai}\n"
    printf "提示：请在随后的蓝框中完成 Telegram API ID/Hash 等核心设置。\n"
    sleep 2
    openclaw onboard

    # 3. 网关安装与启动
    printf "${xfc_lan}>>> [3/7] 正在启动 OpenClaw 网关服务...${xfc_bai}\n"
    export NODE_OPTIONS="--max-old-space-size=512"
    openclaw gateway start
    sleep 2

    # 4. OAuth 授权环节 (核心白嫖组件)
    if [ ! -f "/usr/local/bin/cli-proxy-api" ]; then
        printf "${xfc_lan}>>> [4/7] 正在获取 Google OAuth 授权组件...${xfc_bai}\n"
        local p_arch="amd64"; [[ "$(uname -m)" == "aarch64" ]] && p_arch="arm64"
        wget -qO /usr/local/bin/cli-proxy-api "https://github.com/Joye-at-GitHub/cli-proxy-api/releases/latest/download/cli-proxy-api-linux-$p_arch"
        chmod +x /usr/local/bin/cli-proxy-api
    fi
    printf "${xfc_huang}>>> [5/7] 正在通过白嫖通道进行 OAuth 授权...${xfc_bai}\n"
    /usr/local/bin/cli-proxy-api auth

    # 5. 启动 API 代理并选择默认模型
    printf "${xfc_lan}>>> [6/7] 正在启动代理并对接 Google 免费模型...${xfc_bai}\n"
    nohup /usr/local/bin/cli-proxy-api run >/dev/null 2>&1 &
    sleep 2
    openclaw models remove google 2>/dev/null
    openclaw models add google --base-url http://127.0.0.1:8085/v1 --api-key "xfc-free"
    openclaw models set "google/gemini-1.5-flash-latest"

    # 6. 机器人对接 (Pairing)
    printf "${xfc_huang}>>> [7/7] 最后的对接：机器人授权...${xfc_bai}\n"
    printf "请在 Telegram 机器人对话框输入 /start 获取 8 位连接码。\n"
    read -p "请输入连接码: " xfc_pcode
    if [[ -n "$xfc_pcode" ]]; then
        openclaw pairing approve telegram "$xfc_pcode"
        printf "${xfc_lv}✅ 恭喜博主！全流程已通，白嫖航线正式开启！${xfc_bai}\n"
    else
        printf "${xfc_huang}提示：未输入连接码，后续可手动在菜单 [4] 进行对接。${xfc_bai}\n"
    fi
}

# --- 基础环境函数 ---
xfc_install_env() {
    apt update -y && apt install -y wget curl lsof python3 ca-certificates xz-utils git
    local mem_total=$(free -m | grep Mem | awk $'{print $2}')
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
    npm install -g openclaw@latest --family=ipv4 --engine-strict=false
    ln -sf "$node_path/bin/openclaw" /usr/local/bin/openclaw
    ln -sf "$(readlink -f "$0")" /usr/local/bin/xfc; chmod +x /usr/local/bin/xfc
}

# --- 主菜单 ---
xfc_main_menu() {
    clear
    export PATH="/opt/xfc_node/bin:$PATH"
    printf "${xfc_lan}             小帆船 (cnxiaofanchuan) - 航海员               ${xfc_bai}\n"
    printf "     ╚════════════════════════════════════════════════════╝\n"
    printf "  [1] ${xfc_lv}一键安装部署 (全自动流水线)${xfc_bai}\n"
    printf "  [2] 启动服务 (网关+白嫖代理)\n"
    printf "  [3] 停止服务 (强制关闭进程)\n"
    printf "  [4] 手动机器人授权 (Pairing)\n"
    printf "  [5] 彻底卸载清理 (不留痕迹)\n"
    printf "  [0] 退出脚本\n\n"
    read -p "  请选择 [0-5]: " xfc_choice
    case "$xfc_choice" in
        1) xfc_full_install; read -p "回车返回菜单..."; xfc_main_menu ;;
        2) 
            lsof -i:8085 >/dev/null 2>&1 || nohup /usr/local/bin/cli-proxy-api run >/dev/null 2>&1 &
            export NODE_OPTIONS="--max-old-space-size=512"
            openclaw gateway start; xfc_main_menu ;;
        3) 
            openclaw gateway stop; pkill -9 cli-proxy-api; xfc_main_menu ;;
        4) read -p "连接码: " xfc_pcode; [[ -n "$xfc_pcode" ]] && openclaw pairing approve telegram "$xfc_pcode"; xfc_main_menu ;;
        5) 
            read -p "确认彻底清理服务器并卸载吗? (y/N): " u_sure
            [[ "$u_sure" =~ ^[Yy]$ ]] && { npm uninstall -g openclaw; rm -rf ~/.openclaw /opt/xfc_node /usr/local/bin/xfc /usr/local/bin/cli-proxy-api /xfc_swap; exit 0; }
            xfc_main_menu ;;
        *) exit 0 ;;
    esac
}
xfc_main_menu
