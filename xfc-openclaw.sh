#!/usr/bin/env bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║                                                                  ║
# ║             小帆船 (cnxiaofanchuan) - 航海员专用脚本             ║
# ║                                                                  ║
# ╠══════════════════════════════════════════════════════════════════╣
# ║  版本：v1.4.1 | 核心：原生 JSON 注入 | 状态：极致压榨 1G 内存    ║
# ╚══════════════════════════════════════════════════════════════════╝

[[ "$(id -u)" -ne 0 ]] && { echo "请使用 root 用户运行"; exit 1; }

xfc_lv='\033[32m'; xfc_lan='\033[96m'; xfc_huang='\033[33m'; xfc_bai='\033[0m'

# 极致内存锁定：只给 256MB，不让它乱申请
export NODE_OPTIONS="--max-old-space-size=256"

xfc_full_install() {
    clear
    printf "${xfc_lan}>>> [1/5] 正在部署环境 (极速模式)...${xfc_bai}\n"
    xfc_install_env
    export PATH="/opt/xfc_node/bin:$PATH"
    
    printf "${xfc_huang}>>> [2/5] 正在生成核心配置 (避开 Python 编码陷阱)...${xfc_bai}\n"
    read -p "请输入 Telegram API ID: " tg_id
    read -p "请输入 Telegram API Hash: " tg_hash
    
    mkdir -p "${HOME}/.openclaw"
    # 使用 cat 写入，支持任何字符编码，绝对不会报错
    cat > "${HOME}/.openclaw/openclaw.json" <<EOF
{
  "gateway": { "mode": "local", "port": 18789 },
  "agents": {
    "defaults": { "model": "google/gemini-1.5-flash-latest" },
    "telegram": { "apiId": "$tg_id", "apiHash": "$tg_hash" }
  },
  "session": { "reset": { "mode": "idle", "idleMinutes": 720 } }
}
EOF

    printf "${xfc_lan}>>> [3/5] 正在唤起白嫖通道 OAuth 授权...${xfc_bai}\n"
    if [ ! -f "/usr/local/bin/cli-proxy-api" ]; then
        local p_arch="amd64"; [[ "$(uname -m)" == "aarch64" ]] && p_arch="arm64"
        wget -qO /usr/local/bin/cli-proxy-api "https://github.com/Joye-at-GitHub/cli-proxy-api/releases/latest/download/cli-proxy-api-linux-$p_arch"
        chmod +x /usr/local/bin/cli-proxy-api
    fi
    /usr/local/bin/cli-proxy-api auth

    printf "${xfc_lan}>>> [4/5] 正在对接模型接口 (强制内存限制)...${xfc_bai}\n"
    # 启动代理
    nohup /usr/local/bin/cli-proxy-api run >/dev/null 2>&1 &
    sleep 3
    # 所有的 openclaw 命令都通过 node 强制压榨运行
    node --max-old-space-size=256 /usr/local/bin/openclaw models remove google 2>/dev/null
    node --max-old-space-size=256 /usr/local/bin/openclaw models add google --base-url http://127.0.0.1:8085/v1 --api-key "xfc-free"
    
    printf "${xfc_huang}>>> [5/5] 准备进行机器人 Pairing 授权...${xfc_bai}\n"
    read -p "请输入 8 位连接码: " xfc_pcode
    if [[ -n "$xfc_pcode" ]]; then
        # 启动网关
        nohup node --max-old-space-size=256 /usr/local/bin/openclaw gateway start >/dev/null 2>&1 &
        sleep 10
        node --max-old-space-size=256 /usr/local/bin/openclaw pairing approve telegram "$xfc_pcode"
        printf "${xfc_lv}✅ 全部流程已通！${xfc_bai}\n"
    fi
}

xfc_install_env() {
    apt update -y && apt install -y wget curl lsof python3 ca-certificates xz-utils git
    # 强制清理内存缓存，给 Node 腾地方
    sync && echo 3 > /proc/sys/vm/drop_caches
    
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
    fi
    # 预先清理 npm 缓存，防止 OOM
    npm cache clean --force
    npm install -g openclaw@latest --family=ipv4 --engine-strict=false
    ln -sf "$node_path/bin/openclaw" /usr/local/bin/openclaw
}

xfc_main_menu() {
    clear
    export PATH="/opt/xfc_node/bin:$PATH"
    printf "${xfc_lan}             小帆船 (cnxiaofanchuan) - 航海员               ${xfc_bai}\n"
    printf "     ╚════════════════════════════════════════════════════╝\n"
    printf "  [1] ${xfc_lv}一键安装部署 (极简注入版)${xfc_bai}\n"
    printf "  [2] 启动服务\n"
    printf "  [3] 停止服务\n"
    printf "  [4] 彻底卸载清理\n"
    printf "  [0] 退出脚本\n\n"
    read -p "  请选择 [0-4]: " xfc_choice
    case "$xfc_choice" in
        1) xfc_full_install; read -p "完成，回车继续..."; xfc_main_menu ;;
        2) 
            lsof -i:8085 >/dev/null 2>&1 || nohup /usr/local/bin/cli-proxy-api run >/dev/null 2>&1 &
            node --max-old-space-size=256 /usr/local/bin/openclaw gateway start
            xfc_main_menu ;;
        3) node --max-old-space-size=256 /usr/local/bin/openclaw gateway stop; pkill -9 cli-proxy-api; xfc_main_menu ;;
        4) npm uninstall -g openclaw; rm -rf ~/.openclaw /opt/xfc_node /usr/local/bin/xfc /usr/local/bin/cli-proxy-api /xfc_swap; exit 0 ;;
        *) exit 0 ;;
    esac
}
xfc_main_menu
