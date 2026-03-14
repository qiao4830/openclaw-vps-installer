#!/usr/bin/env bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║                                                                  ║
# ║             小帆船 (cnxiaofanchuan) - 航海员专用脚本             ║
# ║                                                                  ║
# ╠══════════════════════════════════════════════════════════════════╣
# ║  版本：v1.5.0 | 核心：低配机深度优化 | 状态：极致轻量/无 GUM     ║
# ║  YouTube : @cnxiaofanchuan  |  Telegram: t.me/vipxiaofanchuan    ║
# ╚══════════════════════════════════════════════════════════════════╝

# 0. 权限与变量设置
[[ "$(id -u)" -ne 0 ]] && { echo "请使用 root 用户运行"; exit 1; }

# 强制 Node.js 内存上限，防止 1G 小鸡崩溃
export NODE_OPTIONS="--max-old-space-size=448"
xfc_lv='\033[32m'; xfc_lan='\033[96m'; xfc_huang='\033[33m'; xfc_hong='\033[31m'; xfc_bai='\033[0m'

# --- 1. 环境检查与极简安装 ---
xfc_install_core() {
    printf "${xfc_lan}>>> [1/4] 正在清理系统并准备 Swap...${xfc_bai}\n"
    apt update -y && apt install -y wget curl lsof python3 ca-certificates xz-utils git
    
    # 强制开启 2G Swap，这是 1G 小鸡的救命稻草
    if [ ! -f /xfc_swap ]; then
        fallocate -l 2G /xfc_swap && chmod 600 /xfc_swap && mkswap /xfc_swap && swapon /xfc_swap
        echo '/xfc_swap none swap sw 0 0' >> /etc/fstab
    fi

    # 安装 Node.js 22
    if ! command -v node &>/dev/null; then
        printf "${xfc_lan}>>> [2/4] 正在安装 Node.js (精简版)...${xfc_bai}\n"
        local arch=$(uname -m); local node_bin="node-v22.16.0-linux-x64.tar.xz"
        [[ "$arch" == "aarch64" ]] && node_bin="node-v22.16.0-linux-arm64.tar.xz"
        wget -c "https://nodejs.org/dist/v22.16.0/$node_bin" -O /tmp/node.tar.xz
        mkdir -p /opt/xfc_node && tar -xJf /tmp/node.tar.xz -C /opt/xfc_node --strip-components=1
        ln -sf /opt/xfc_node/bin/node /usr/local/bin/node
        ln -sf /opt/xfc_node/bin/npm /usr/local/bin/npm
    fi

    printf "${xfc_lan}>>> [3/4] 正在安装 OpenClaw (内存限速模式)...${xfc_bai}\n"
    export PATH="/opt/xfc_node/bin:$PATH"
    npm install -g openclaw@latest --family=ipv4 --engine-strict=false
    ln -sf /opt/xfc_node/bin/openclaw /usr/local/bin/openclaw

    printf "${xfc_huang}>>> [4/4] 请输入 Telegram 配置 (跳过 UI 向导以免崩溃)...${xfc_bai}\n"
    read -p "API ID: " xfc_id
    read -p "API Hash: " xfc_hash
    mkdir -p ~/.openclaw
    cat > ~/.openclaw/openclaw.json <<EOF
{
  "gateway": { "mode": "local", "port": 18789 },
  "agents": {
    "defaults": { "model": "google/gemini-1.5-flash-latest" },
    "telegram": { "apiId": "$xfc_id", "apiHash": "$xfc_hash" }
  }
}
EOF
    printf "${xfc_lv}环境部署完成！${xfc_bai}\n"
}

# --- 2. 白嫖组件与 OAuth 管理 ---
xfc_oauth_manager() {
    if [ ! -f "/usr/local/bin/cli-proxy-api" ]; then
        printf "${xfc_lan}正在获取授权组件...${xfc_bai}\n"
        local p_arch="amd64"; [[ "$(uname -m)" == "aarch64" ]] && p_arch="arm64"
        wget -qO /usr/local/bin/cli-proxy-api "https://github.com/Joye-at-GitHub/cli-proxy-api/releases/latest/download/cli-proxy-api-linux-$p_arch"
        chmod +x /usr/local/bin/cli-proxy-api
    fi
    printf "${xfc_huang}>>> 正在启动 OAuth 授权链接，请在浏览器完成后粘贴回调 URL：${xfc_bai}\n"
    /usr/local/bin/cli-proxy-api auth
}

# --- 3. 核心启动/停止逻辑 ---
xfc_service_start() {
    printf "${xfc_lan}正在拉起服务...${xfc_bai}\n"
    lsof -i:8085 >/dev/null 2>&1 || nohup /usr/local/bin/cli-proxy-api run >/dev/null 2>&1 &
    sleep 2
    # 添加模型并设置为默认
    openclaw models add google --base-url http://127.0.0.1:8085/v1 --api-key "xfc-free" 2>/dev/null
    openclaw models set "google/gemini-1.5-flash-latest" 2>/dev/null
    openclaw gateway start
}

# --- 4. 主菜单 ---
xfc_main_menu() {
    clear
    export PATH="/opt/xfc_node/bin:$PATH"
    local status_oc="${xfc_hong}STOPPED${xfc_bai}"; pgrep -f "openclaw.*gatewa" >/dev/null && status_oc="${xfc_lv}RUNNING${xfc_bai}"
    local status_api="${xfc_hong}STOPPED${xfc_bai}"; pgrep -f "cli-proxy-api" >/dev/null && status_api="${xfc_lv}RUNNING${xfc_bai}"

    printf "${xfc_lan}             小帆船 (cnxiaofanchuan) - 航海员               ${xfc_bai}\n"
    printf "     ╚════════════════════════════════════════════════════╝\n"
    printf "  网关状态: $status_oc  |  白嫖代理: $status_api\n"
    printf "  --------------------------------------------------------\n"
    printf "  [1] ${xfc_lv}一键部署 (Node+OpenClaw+静默配置)${xfc_bai}\n"
    printf "  [2] Google OAuth 授权登录\n"
    printf "  [3] 启动服务 (网关 + 代理)\n"
    printf "  [4] 停止服务\n"
    printf "  [5] 机器人 Pairing 对接 (输入连接码)\n"
    printf "  [6] 查看运行日志\n"
    printf "  [7] 彻底卸载清理\n"
    printf "  [0] 退出脚本\n\n"
    read -p "请选择 [0-7]: " xfc_choice
    case "$xfc_choice" in
        1) xfc_install_core; read -p "按回车返回..."; xfc_main_menu ;;
        2) xfc_oauth_manager; read -p "按回车返回..."; xfc_main_menu ;;
        3) xfc_service_start; read -p "按回车返回..."; xfc_main_menu ;;
        4) openclaw gateway stop; pkill -9 cli-proxy-api; xfc_main_menu ;;
        5) read -p "请输入 8 位连接码: " xfc_code; [[ -n "$xfc_code" ]] && openclaw pairing approve telegram "$xfc_code"; xfc_main_menu ;;
        6) openclaw logs; xfc_main_menu ;;
        7) 
            read -p "确认清理所有环境? (y/N): " u_sure
            if [[ "$u_sure" =~ ^[Yy]$ ]]; then
                npm uninstall -g openclaw; rm -rf ~/.openclaw /opt/xfc_node /usr/local/bin/xfc /usr/local/bin/cli-proxy-api /xfc_swap; exit 0
            fi; xfc_main_menu ;;
        *) exit 0 ;;
    esac
}

xfc_main_menu
