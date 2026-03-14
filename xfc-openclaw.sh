#!/usr/bin/env bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║                                                                  ║
# ║             小帆船 (cnxiaofanchuan) - 航海员专用脚本             ║
# ║                                                                  ║
# ╠══════════════════════════════════════════════════════════════════╣
# ║  版本：v1.3.9 | 核心：内存限制保护 | 状态：修复 1G 内存 OOM 崩溃 ║
# ╚══════════════════════════════════════════════════════════════════╝

[[ "$(id -u)" -ne 0 ]] && { echo "请使用 root 用户运行"; exit 1; }

xfc_lv='\033[32m'; xfc_lan='\033[96m'; xfc_huang='\033[33m'; xfc_bai='\033[0m'

# 强制内存限制变量 (给 Node.js 戴上手铐)
export NODE_OPTIONS="--max-old-space-size=448"

xfc_full_install() {
    clear
    printf "${xfc_lan}>>> [1/7] 正在部署环境 (内存压榨模式)...${xfc_bai}\n"
    xfc_install_env
    export PATH="/opt/xfc_node/bin:$PATH"
    hash -r

    printf "${xfc_huang}>>> [2/7] 准备进入配置向导 (限流启动)...${xfc_bai}\n"
    sleep 3
    # 【核心修正】给 onboard 增加内存限制
    node --max-old-space-size=448 /usr/local/bin/openclaw onboard

    printf "${xfc_lan}>>> [3/7] 启动网关服务...${xfc_bai}\n"
    # 【核心修正】给 gateway 增加内存限制
    node --max-old-space-size=448 /usr/local/bin/openclaw gateway start
    sleep 5

    if [ ! -f "/usr/local/bin/cli-proxy-api" ]; then
        local p_arch="amd64"; [[ "$(uname -m)" == "aarch64" ]] && p_arch="arm64"
        wget -qO /usr/local/bin/cli-proxy-api "https://github.com/Joye-at-GitHub/cli-proxy-api/releases/latest/download/cli-proxy-api-linux-$p_arch"
        chmod +x /usr/local/bin/cli-proxy-api
    fi

    printf "${xfc_huang}>>> [5/7] 正在进行 OAuth 授权...${xfc_bai}\n"
    /usr/local/bin/cli-proxy-api auth

    printf "${xfc_lan}>>> [6/7] 正在对接模型接口...${xfc_bai}\n"
    nohup /usr/local/bin/cli-proxy-api run >/dev/null 2>&1 &
    sleep 3
    
    # 【核心修正】后续所有模型管理也必须带内存限制
    node --max-old-space-size=448 /usr/local/bin/openclaw models remove google 2>/dev/null
    node --max-old-space-size=448 /usr/local/bin/openclaw models add google --base-url http://127.0.0.1:8085/v1 --api-key "xfc-free"
    node --max-old-space-size=448 /usr/local/bin/openclaw models set "google/gemini-1.5-flash-latest"

    printf "${xfc_huang}>>> [7/7] 机器人授权对接...${xfc_bai}\n"
    read -p "请输入 8 位连接码: " xfc_pcode
    if [[ -n "$xfc_pcode" ]]; then
        node --max-old-space-size=448 /usr/local/bin/openclaw pairing approve telegram "$xfc_pcode"
        printf "${xfc_lv}✅ 全部流程已通！${xfc_bai}\n"
    fi
}

xfc_install_env() {
    apt update -y && apt install -y wget curl lsof python3 ca-certificates xz-utils git
    local mem_total=$(free -m | grep Mem | awk $'{print $2}')
    if [ "$mem_total" -lt 1500 ] && [ ! -f /xfc_swap ]; then
        # 强制建立 Swap 并等待生效
        fallocate -l 2G /xfc_swap && chmod 600 /xfc_swap && mkswap /xfc_swap && swapon /xfc_swap
        grep -q "/xfc_swap" /etc/fstab || echo '/xfc_swap none swap sw 0 0' >> /etc/fstab
        sleep 2
    fi
    local node_path="/opt/xfc_node"
    if [ ! -d "$node_path" ]; then
        local arch=$(uname -m); local node_bin="node-v22.16.0-linux-x64.tar.xz"
        [[ "$arch" == "aarch64" ]] && node_bin="node-v22.16.0-linux-arm64.tar.xz"
        wget -c "https://nodejs.org/dist/v22.16.0/$node_bin" -O /tmp/node.tar.xz
        mkdir -p "$node_path"; tar -xJf /tmp/node.tar.xz -C "$node_path" --strip-components=1
        ln -sf "$node_path/bin/node" /usr/local/bin/node
        ln -sf "$node_path/bin/npm" /usr/local/bin/npm
    fi
    npm install -g openclaw@latest --family=ipv4 --engine-strict=false
    ln -sf "$node_path/bin/openclaw" /usr/local/bin/openclaw
}

xfc_main_menu() {
    clear
    export PATH="/opt/xfc_node/bin:$PATH"
    printf "${xfc_lan}             小帆船 (cnxiaofanchuan) - 航海员               ${xfc_bai}\n"
    printf "     ╚════════════════════════════════════════════════════╝\n"
    printf "  [1] ${xfc_lv}一键安装部署 (全自动流水线)${xfc_bai}\n"
    printf "  [2] 启动服务\n"
    printf "  [3] 停止服务\n"
    printf "  [4] 机器人授权 (Pairing)\n"
    printf "  [5] 彻底卸载清理\n"
    printf "  [0] 退出脚本\n\n"
    read -p "  请选择 [0-5]: " xfc_choice
    case "$xfc_choice" in
        1) xfc_full_install; read -p "回车继续..."; xfc_main_menu ;;
        2) 
            lsof -i:8085 >/dev/null 2>&1 || nohup /usr/local/bin/cli-proxy-api run >/dev/null 2>&1 &
            node --max-old-space-size=448 /usr/local/bin/openclaw gateway start
            xfc_main_menu ;;
        3) node --max-old-space-size=448 /usr/local/bin/openclaw gateway stop; pkill -9 cli-proxy-api; xfc_main_menu ;;
        4) read -p "连接码: " xfc_pcode; [[ -n "$xfc_pcode" ]] && node --max-old-space-size=448 /usr/local/bin/openclaw pairing approve telegram "$xfc_pcode"; xfc_main_menu ;;
        5) npm uninstall -g openclaw; rm -rf ~/.openclaw /opt/xfc_node /usr/local/bin/xfc /usr/local/bin/cli-proxy-api /xfc_swap; exit 0 ;;
        *) exit 0 ;;
    esac
}
xfc_main_menu
