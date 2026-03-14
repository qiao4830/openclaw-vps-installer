#!/usr/bin/env bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║                                                                  ║
# ║             小帆船 (cnxiaofanchuan) - 航海员专用脚本             ║
# ║                                                                  ║
# ╠══════════════════════════════════════════════════════════════════╣
# ║  版本：v1.3.1 | 核心：OAuth 自动化衔接 | 状态：URL 语法修复      ║
# ║  优化：彻底移除 Markdown 链接污染 | 架构：1G 内存低配机          ║
# ╚══════════════════════════════════════════════════════════════════╝

if [ "$(id -u)" -ne 0 ]; then 
    echo "请使用 root 用户运行 (sudo bash $0)"; exit 1
fi

xfc_lv='\033[32m'; xfc_lan='\033[96m'; xfc_huang='\033[33m'; xfc_hong='\033[31m'; xfc_bai='\033[0m'

xfc_install_env() {
    clear
    printf "${xfc_lan}>>> 正在部署航海员专用环境与优化补丁...${xfc_bai}\n"
    local mem_total=$(free -m | grep Mem | awk '{print $2}')
    if [ "$mem_total" -lt 1500 ] && [ ! -f /xfc_swap ]; then
        fallocate -l 2G /xfc_swap && chmod 600 /xfc_swap && mkswap /xfc_swap && swapon /xfc_swap
        grep -q "/xfc_swap" /etc/fstab || echo '/xfc_swap none swap sw 0 0' >> /etc/fstab
    fi
    apt update -y && apt install -y xz-utils wget lsof python3 git curl
    local node_path="/opt/xfc_node"
    if [ ! -d "$node_path" ]; then
        local arch=$(uname -m); local node_bin="node-v22.16.0-linux-x64.tar.xz"
        [[ "$arch" == "aarch64" ]] && node_bin="node-v22.16.0-linux-arm64.tar.xz"
        wget -c "https://nodejs.org/dist/v22.16.0/$node_bin" -O /tmp/node.tar.xz
        mkdir -p "$node_path"; tar -xJf /tmp/node.tar.xz -C "$node_path" --strip-components=1
        ln -sf "$node_path/bin/node" /usr/local/bin/node
        ln -sf "$node_path/bin/npm" /usr/local/bin/npm
    fi
    npm install -g openclaw@latest --family=ipv4 --engine-strict=false --no-fund --no-audit
    if [ ! -f "/usr/local/bin/cli-proxy-api" ]; then
        local p_arch="amd64"; [[ "$(uname -m)" == "aarch64" ]] && p_arch="arm64"
        wget -qO /usr/local/bin/cli-proxy-api "https://github.com/Joye-at-GitHub/cli-proxy-api/releases/latest/download/cli-proxy-api-linux-$p_arch"
        chmod +x /usr/local/bin/cli-proxy-api
    fi
    ln -sf "$(readlink -f "$0")" /usr/local/bin/xfc; chmod +x /usr/local/bin/xfc
}

xfc_auto_onboard() {
    local config_file="${HOME}/.openclaw/openclaw.json"
    mkdir -p "${HOME}/.openclaw"
    printf "${xfc_huang}>>> 正在唤起 Google OAuth 授权衔接器 (零隧道模式)...${xfc_bai}\n"
    printf "授权后，请直接复制地址栏完整 URL 粘贴到下方：\n"
    cli-proxy-api auth
    printf "${xfc_lan}>>> 正在自动配置 OpenClaw 网关...${xfc_bai}\n"
    python3 -c "
import json, os
path = os.path.expanduser('~/.openclaw/openclaw.json')
data = json.load(open(path)) if os.path.exists(path) else {}
data.setdefault('gateway', {})['mode'] = 'local'
data['gateway']['port'] = 18789
data.setdefault('session', {})['reset'] = {'mode': 'idle', 'idleMinutes': 720}
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
"
    # 【重点修正：移除所有 Markdown 符号，纯净 URL】
    openclaw models remove google 2>/dev/null
    openclaw models add google --base-url http://127.0.0.1:8085/v1 --api-key "xfc-free-token"
    
    printf "${xfc_lv}✅ 授权与代理对接完成！${xfc_bai}\n"
}

xfc_main_menu() {
    clear
    printf "${xfc_lan}             小帆船 (cnxiaofanchuan) - 航海员               ${xfc_bai}\n"
    printf "     ╚════════════════════════════════════════════════════╝\n"
    printf "  [1] ${xfc_lv}一键安装部署 & 自动授权${xfc_bai}\n"
    printf "  [2] 启动 OpenClaw & 代理\n"
    printf "  [3] 停止 OpenClaw & 代理\n"
    printf "  [4] 机器人 Pairing 授权\n"
    printf "  [5] 彻底卸载清理\n"
    printf "  [0] 退出脚本\n\n"
    read -p "  请选择 [0-5]: " xfc_choice
    case "$xfc_choice" in
        1) xfc_install_env; xfc_auto_onboard; read -p "完成，回车返回菜单..."; xfc_main_menu ;;
        2) 
            lsof -i:8085 >/dev/null 2>&1 || nohup cli-proxy-api run >/dev/null 2>&1 &
            export NODE_OPTIONS="--max-old-space-size=512"
            openclaw gateway start
            read -p "服务已开启，回车返回..."; xfc_main_menu ;;
        3) 
            openclaw gateway stop; pkill -9 cli-proxy-api
            printf "${xfc_huang}已停止所有服务。${xfc_bai}\n"
            sleep 1; xfc_main_menu ;;
        4) read -p "连接码: " xfc_pcode; [[ -n "$xfc_pcode" ]] && openclaw pairing approve telegram "$xfc_pcode"; xfc_main_menu ;;
        5) 
            read -p "确定卸载清理吗? (y/N): " u_sure
            if [[ "$u_sure" =~ ^[Yy]$ ]]; then
                npm uninstall -g openclaw; rm -rf ~/.openclaw /opt/xfc_node /usr/local/bin/xfc /usr/local/bin/cli-proxy-api /xfc_swap; 
                exit 0
            fi; xfc_main_menu ;;
        *) exit 0 ;;
    esac
}
xfc_main_menu
