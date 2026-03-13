#!/usr/bin/env bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║                                                                  ║
# ║             小帆船 (cnxiaofanchuan) - 航海员专用脚本               ║
# ║                                                                  ║
# ╠══════════════════════════════════════════════════════════════════╣
# ║  版本：v1.2.0 | 适配 1G 内存 | 快捷键：xfc | 纯净/避坑/稳定         ║
# ║  YouTube : @cnxiaofanchuan  |  Telegram: t.me/vipxiaofanchuan    ║
# ╚══════════════════════════════════════════════════════════════════╝

# --- 1. 颜色与基础变量 ---
: "${xfc_hong:='\033[31m'}"    
: "${xfc_lv:='\033[32m'}"      
: "${xfc_huang:='\033[33m'}"    
: "${xfc_lan:='\033[96m'}"      
: "${xfc_bai:='\033[0m'}"       

# --- 2. 五大生存维度检查 ---
xfc_system_check() {
    clear
    echo -e "${xfc_lan}>>> 正在执行小帆船专属系统安检...${xfc_bai}"
    local mem_total=$(free -m | grep Mem | awk '{print $2}')
    if [ "$mem_total" -lt 1500 ] && [ ! -f /xfc_swap ]; then
        echo -e "维度 1 (内存): 正在开启 2G 补丁..."
        fallocate -l 2G /xfc_swap && chmod 600 /xfc_swap && mkswap /xfc_swap && swapon /xfc_swap
        echo '/xfc_swap none swap sw 0 0' >> /etc/fstab
        echo -e "状态: ${xfc_lv}内存补丁已应用${xfc_bai}"
    fi
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" && "$VERSION_ID" == "20.04" ]]; then
            echo -e "维度 2 (版本): ${xfc_hong}Ubuntu 20.04 过旧，请更换 22.04+${xfc_bai}"
            exit 1
        fi
    fi
    if ip -6 addr | grep -q "global"; then
        export GAI_CONF="/etc/gai.conf"
        alias curl='curl -4'; alias wget='wget -4'
        export NPM_CONFIG_REGISTRY=https://registry.npmmirror.com
        echo -e "维度 3 (IPv6): ${xfc_lv}已强制走 IPv4 通道${xfc_bai}"
    fi
    if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" > /etc/resolv.conf
    fi
    echo -e "维度 5 (端口): 正在扫描冲突..."
    local check_ports=(18789 8317 2053 443)
    for p in "${check_ports[@]}"; do
        local p_info=$(lsof -i :$p -t | xargs ps -p 2>/dev/null | awk 'NR==2 {print $NF}')
        if [ -n "$p_info" ]; then
            echo -e "  - 端口 $p : ${xfc_hong}被 [$p_info] 占用${xfc_bai}"
        fi
    done
    sleep 1
}

# --- 3. 环境部署 (Node.js & 快捷键) ---
xfc_install_env() {
    local node_ver="v22.14.0"
    local node_path="/opt/xfc_node"
    if [ ! -d "$node_path" ]; then
        echo -e "${xfc_lan}正在部署 Node.js 环境...${xfc_bai}"
        apt update -y && apt install -y xz-utils wget lsof python3
        local arch=$(uname -m); local node_bin="node-$node_ver-linux-x64.tar.xz"
        [ "$arch" == "aarch64" ] && node_bin="node-$node_ver-linux-arm64.tar.xz"
        wget -c "https://nodejs.org/dist/$node_ver/$node_bin" -O /tmp/node.tar.xz
        mkdir -p "$node_path"; tar -xJf /tmp/node.tar.xz -C "$node_path" --strip-components=1
        ln -sf "$node_path/bin/node" /usr/local/bin/node; ln -sf "$node_path/bin/npm" /usr/local/bin/npm
        rm /tmp/node.tar.xz
    fi
    if ! command -v openclaw &>/dev/null; then
        echo -e "${xfc_lan}正在安装 OpenClaw (512MB 限制模式)...${xfc_bai}"
        export NODE_OPTIONS="--max-old-space-size=512"
        npm install -g openclaw@latest --family=ipv4 --no-fund --no-audit
    fi
    # 植入快捷键 xfc
    local script_path=$(readlink -f "$0")
    ln -sf "$script_path" /usr/local/bin/xfc
    chmod +x /usr/local/bin/xfc
}

# --- 4. 初始化配置 ---
xfc_init_config() {
    echo -e "${xfc_lan}正在注入 12 小时长记忆与 Gemini 预设...${xfc_bai}"
    local config_file="${HOME}/.openclaw/openclaw.json"
    [ ! -f "$config_file" ] && openclaw onboard --install-daemon >/dev/null 2>&1
    python3 -c "
import json, os
path = '$config_file'
if not os.path.exists(path): exit(0)
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)
data['profile'] = 'full'
session = data.setdefault('session', {})
session['resetTriggers'] = ['/reset', '/new', '重置对话']
session['reset'] = {'mode': 'idle', 'idleMinutes': 720}
agents = data.setdefault('agents', {})
defaults = agents.setdefault('defaults', {})
defaults['model'] = 'google/gemini-pro'
data.setdefault('gateway', {})['logLevel'] = 'info'
with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
"
}

# --- 5. 模型与 API 管理 ---
xfc_manage_models() {
    clear
    echo -e "${xfc_lan}--- [ 模型与 API 管理 ] ---${xfc_bai}"
    echo "  [1] 接入 Gemini (Google 官方)"
    echo "  [2] 接入 DeepSeek (官方 API)"
    echo "  [3] 接入自定义 OpenAI 格式 API"
    echo "  [4] 查看当前配置"
    echo "  [0] 返回主菜单"
    echo
    read -p "  请选择: " model_choice
    case "$model_choice" in
        1)
            read -p "请输入 Gemini Key: " g_key
            if [ -n "$g_key" ]; then
                openclaw models add google --api openai-chat-completions --base-url https://generativelanguage.googleapis.com/v1beta/openai/ --api-key "$g_key"
                openclaw models set google/gemini-1.5-pro
                openclaw gateway restart; echo -e "${xfc_lv}成功！${xfc_bai}"
            fi ;;
        2)
            read -p "请输入 DeepSeek Key: " d_key
            if [ -n "$d_key" ]; then
                openclaw models add deepseek --api openai-chat-completions --base-url https://api.deepseek.com/v1 --api-key "$d_key"
                openclaw models set deepseek/deepseek-chat
                openclaw gateway restart; echo -e "${xfc_lv}成功！${xfc_bai}"
            fi ;;
        3)
            read -p "名称: " p_name; read -p "Base URL: " p_url; read -p "Key: " p_key; read -p "模型ID: " p_model
            if [ -n "$p_name" ]; then
                openclaw models add "$p_name" --api openai-chat-completions --base-url "$p_url" --api-key "$p_key"
                openclaw models set "${p_name}/${p_model}"
                openclaw gateway restart; echo -e "${xfc_lv}成功！${xfc_bai}"
            fi ;;
        4) openclaw models list; read -p "回车继续...";;
        *) return ;;
    esac
}

# --- 6. 主菜单 ---
xfc_main_menu() {
    clear
    echo -e "${xfc_lan}  ╔══════════════════════════════════════════════════════════╗"
    echo "               ║             小帆船 (cnxiaofanchuan) - 航海员              ║"
    echo -e "            ╚══════════════════════════════════════════════════════════╝${xfc_bai}"
    echo -e "  [1] ${xfc_lv}一键极简安装${xfc_bai} (针对 1G 内存优化)"
    echo -e "  [2] 启动 OpenClaw"
    echo -e "  [3] 停止 OpenClaw"
    echo -e "  [4] 对接机器人 (连接码)"
    echo -e "  [5] 换模型 / 填 Key"
    echo -e "  [6] ${xfc_hong}彻底卸载${xfc_bai}"
    echo -e "  [0] 退出脚本"
    echo
    read -p "  请选择 [0-6]: " xfc_choice
    case "$xfc_choice" in
        1) xfc_system_check; xfc_install_env; xfc_init_config; read -p "安装完成！以后输入 xfc 即可唤醒本菜单。回车继续..."; xfc_main_menu ;;
        2) openclaw gateway start; read -p "启动成功，回车返回..."; xfc_main_menu ;;
        3) openclaw gateway stop; read -p "已停止，回车返回..."; xfc_main_menu ;;
        4) read -p "连接码: " bot_code; openclaw pairing approve telegram "$bot_code"; xfc_main_menu ;;
        5) xfc_manage_models; xfc_main_menu ;;
        6) npm uninstall -g openclaw; rm -rf ~/.openclaw /opt/xfc_node /usr/local/bin/xfc; echo "已清理"; exit 0 ;;
        0) exit 0 ;;
        *) xfc_main_menu ;;
    esac
}
xfc_main_menu
