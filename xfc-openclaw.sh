#!/usr/bin/env bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║                                                                  ║
# ║             小帆船 (cnxiaofanchuan) - 航海员专用脚本             ║
# ║                                                                  ║
# ╠══════════════════════════════════════════════════════════════════╣
# ║  版本：v1.3.5 | 核心：路径自动追踪 | 状态：彻底解决模块找不到问题║
# ╚══════════════════════════════════════════════════════════════════╝

[[ "$(id -u)" -ne 0 ]] && { echo "请使用 root 用户运行"; exit 1; }

xfc_lv='\033[32m'; xfc_lan='\033[96m'; xfc_huang='\033[33m'; xfc_bai='\033[0m'

xfc_auto_setup() {
    clear
    printf "${xfc_lan}>>> 第一步：正在安装 Node.js 与 OpenClaw 环境...${xfc_bai}\n"
    xfc_install_env

    # 强制刷新路径缓存
    hash -r

    if [ ! -f "/usr/local/bin/cli-proxy-api" ]; then
        printf "${xfc_lan}>>> 第二步：正在获取 OAuth 授权组件...${xfc_bai}\n"
        local p_arch="amd64"; [[ "$(uname -m)" == "aarch64" ]] && p_arch="arm64"
        wget -qO /usr/local/bin/cli-proxy-api "https://github.com/Joye-at-GitHub/cli-proxy-api/releases/latest/download/cli-proxy-api-linux-$p_arch"
        chmod +x /usr/local/bin/cli-proxy-api
    fi

    printf "${xfc_huang}>>> 第三步：进入 Google OAuth 授权流程 (零隧道)...${xfc_bai}\n"
    printf "授权后，请直接复制地址栏完整 URL 粘贴到下方：\n"
    sleep 1
    /usr/local/bin/cli-proxy-api auth

    printf "${xfc_lan}>>> 第四步：正在自动对接网关与模型接口...${xfc_bai}\n"
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
    # 【核心修正】：不再写死绝对路径，使用 which 动态寻找 openclaw 位置
    # 这样可以完美避开 MODULE_NOT_FOUND 错误
    OPENCLAW_BIN=$(which openclaw)
    if [ -z "$OPENCLAW_BIN" ]; then
        OPENCLAW_BIN="/opt/xfc_node/bin/openclaw"
    fi

    $OPENCLAW_BIN models remove google 2>/dev/null
    $OPENCLAW_BIN models add google --base-url http://127.0.0.1:8085/v1 --api-key "xfc-free"
    
    printf "${xfc_lv}✅ 全部流程自动衔接完成！请选择 [2] 启动服务。${xfc_bai}\n"
}

xfc_install_env() {
    apt update -y && apt install -y wget curl lsof python3 ca-certificates xz-utils git
    local mem_total=$(free -m | grep Mem | awk '{print $2}')
    if [ "$mem_total" -lt 1500 ] && [ ! -f /xfc_swap ]; then
        fallocate -l 2G /xfc_swap && chmod 600 /xfc_swap && mkswap /xfc_swap && swapon /xfc_swap
        grep -q "/xfc_swap" /etc/fstab || echo '/xfc_swap none swap sw 0 0' >> /etc/fstab
    fi
    local node_path="/opt/xfc_node"
    if [ ! -d "$node_path" ]; then
        local arch=$(uname -m); local node_bin="node-v22.16.0-linux-x64.tar.xz"
        [[ "$arch" == "aarch64" ]] && node_bin="node-v22.16.0-linux-arm64.tar.xz"
        wget -c "https://nodejs.
