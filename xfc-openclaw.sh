#!/usr/bin/env bash
#
# ╔══════════════════════════════════════════════════════════════════╗
# ║                                                                  ║
# ║             小帆船 (cnxiaofanchuan) - 航海员专用脚本               ║
# ║                                                                  ║
# ╠══════════════════════════════════════════════════════════════════╣
# ║  版本：v1.2.1 | 适配 1G 内存 | 快捷键：xfc | 纯净/避坑/稳定         ║
# ║  YouTube : @cnxiaofanchuan  |  Telegram: t.me/vipxiaofanchuan    ║
# ╚══════════════════════════════════════════════════════════════════╝

# 0. Root 检查 (ChatGPT 建议)
if [ "$(id -u)" -ne 0 ]; then 
    echo "请使用 root 用户运行 (sudo bash $0)"; exit 1
fi

# --- 1. 颜色与基础变量 ---
: "${xfc_hong:='\033[31m'}"    
: "${xfc_lv:='\033[32m'}"      
: "${xfc_huang:='\033[33m'}"    
: "${xfc_lan:='\033[96m'}"      
: "${xfc_bai:='\033[0m'}"       

# --- 2. 系统深度检查 ---
xfc_system_check() {
    clear
    echo -e "${xfc_lan}>>> 正在执行系统安检与环境优化...${xfc_bai}"

    # [内存] Swap 开启（增加 grep 检查防止重复写入）
local mem_total=$(free -m | grep Mem | awk '{print $2}')
if [ "$mem_total" -lt 1500 ] && [ ! -f /xfc_swap ]; then
    fallocate -l 2G /xfc_swap && chmod 600 /xfc_swap && mkswap /xfc_swap && swapon /xfc_swap
    # 检查 fstab 是否已经存在该记录，不存在才写入
    if ! grep -q "/xfc_swap" /etc/fstab; then
        echo '/xfc_swap none swap sw 0 0' >> /etc/fstab
    fi
    echo -e "状态: ${xfc_lv}2G 内存补丁已应用${xfc_bai}"
fi

    # [版本] 兼容性检查 (ChatGPT 建议：改为警告而非强制退出)
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" && "$VERSION_ID" == "20.04" ]]; then
            echo -e "${xfc_huang}提示: 检测到 Ubuntu 20.04，建议使用 22.04+ 以获得最佳兼容性。${xfc_bai}"
            read -p "是否继续? (y/N): " u_choice
            [[ ! "$u_choice" =~ ^[Yy]$ ]] && exit 1
        fi
    fi

    # [DNS] 备份并尝试修复 (ChatGPT 建议)
    [ ! -f /etc/resolv.conf.bak ] && cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null
    if ! ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
        echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" > /etc/resolv.conf
        echo -e "状态: ${xfc_lv}DNS 已临时修复${xfc_bai}"
    fi

    # [IPv6] 
    if ip -6 addr | grep -q "global"; then
        export GAI_CONF="/etc/gai.conf"
        alias curl='curl -4'; alias wget='wget -4'
        export NPM_CONFIG_REGISTRY=https://registry.npmmirror.com
    fi
    sleep 1
}

# --- 3. 环境部署 ---
xfc_install_env() {
    local node_ver="v22.16.0"
    local node_path="/opt/xfc_node"
    if [ ! -d "$node_path" ]; then
        echo -e "${xfc_lan}正在部署 Node.js 环境 ($node_ver)...${xfc_bai}"
        # 核心：加入 git 依赖
        apt update -y && apt install -y xz-utils wget lsof python3 git
        local arch=$(uname -m); local node_bin="node-$node_ver-linux-x64.tar.xz"
        [ "$arch" == "aarch64" ] && node_bin="node-$node_ver-linux-arm64.tar.xz"
        wget -c "https://nodejs.org/dist/$node_ver/$node_bin" -O /tmp/node.tar.xz
        mkdir -p "$node_path"; tar -xJf /tmp/node.tar.xz -C "$node_path" --strip-components=1
        ln -sf "$node_path/bin/node" /usr/local/bin/node; ln -sf "$node_path/bin/npm" /usr/local/bin/npm
        rm -f /tmp/node.tar.xz  # ChatGPT 建议：加 -f
    fi
    if ! command -v openclaw &>/dev/null; then
        echo -e "${xfc_lan}正在安装 OpenClaw (512MB 限制模式)...${xfc_bai}"
        export NODE_OPTIONS="--max-old-space-size=512"
        # 核心：加入 --engine-strict=false 强行适配版本
        npm install -g openclaw@latest --family=ipv4 --no-fund --no-audit --engine-strict=false
    fi
    # 快捷键 xfc
    local script_path=$(readlink -f "$0")
    ln -sf "$script_path" /usr/local/bin/xfc
    chmod +x /usr/local/bin/xfc
}

# --- 4. 初始化配置 ---
xfc_init_config() {
    local config_file="${HOME}/.openclaw/openclaw.json"

    # 1. 强制清理旧配置，确保 onboard 能够弹出
    rm -f "$config_file"

    # 2. 核心动作：显式唤起官方配置向导 (不再静音)
    echo -e "${xfc_lan}>>> 准备进入官方配置向导，请在随后出现的蓝框中完成核心配置...${xfc_bai}"
    sleep 2
    openclaw onboard

    # 再次检查文件是否存在
    if [ ! -f "$config_file" ]; then
        echo -e "${xfc_hong}错误: openclaw 配置文件未生成，初始化失败！${xfc_bai}"
        return 1
    fi

    echo -e "${xfc_lan}正在注入博主特供优化 (12 小时长记忆与 Gemini 预设)...${xfc_bai}"

    # 使用 python3 精准注入 JSON 配置
    python3 -c "
import json, os
path = '$config_file'
try:
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # 注入长记忆配置 (720分钟 = 12小时)
    session = data.setdefault('session', {})
    session['resetTriggers'] = ['/reset', '/new', '/重置对话']
    session['reset'] = {'mode': 'idle', 'idleMinutes': 720}

    # 注入默认模型
    agents = data.setdefault('agents', {})
    defaults = agents.setdefault('defaults', {})
    defaults['model'] = 'gemini-1.5-flash'

    # 注入本地网关模式
    data.setdefault('gateway', {})['mode'] = 'local'

    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
except Exception as e:
    print(f'Error: {e}')
    exit(1)
"
    # 注意：echo 必须在双引号外面
    echo -e "${xfc_lv}✅ 优化配置注入成功！${xfc_bai}"
}

# --- 5. 模型与 API 管理 ---
xfc_manage_models() {
    clear
    echo -e "${xfc_lan}--- [ 模型与 API 管理 ] ---${xfc_bai}"
    echo "  [1] 接入 Gemini (1.5 Flash - 推荐)"
    echo "  [2] 接入 Gemini (1.5 Pro - 满血)"
    echo "  [3] 接入 DeepSeek (官方)"
    echo "  [4] 查看当前生效模型"
    echo "  [0] 返回主菜单"
    echo
    read -p "  请选择: " model_choice
    case "$model_choice" in
        1|2)
            read -p "请输入 Gemini API Key: " g_key
            if [ -n "$g_key" ]; then
                local m_id="gemini-1.5-flash"
                [ "$model_choice" == "2" ] && m_id="gemini-1.5-pro"
                
                echo -e "${xfc_lan}正在配置 Google Gemini...${xfc_bai}"
                # 修复 1: 移除 Markdown 括号
                # 修复 2: 2026版 OpenClaw 默认已集成 OpenAI 协议，移除多余 --api 参数
				openclaw models remove google 2>/dev/null
                openclaw models add google --base-url https://generativelanguage.googleapis.com/v1beta/openai/ --api-key "$g_key"
                openclaw models set "google/$m_id"
                
                openclaw gateway restart
                echo -e "${xfc_lv}✅ 已切换至 $m_id 引擎！${xfc_bai}"
            fi ;;
        3)
            read -p "请输入 DeepSeek Key: " d_key
            if [ -n "$d_key" ]; then
                openclaw models remove deepseek 2>/dev/null # 先删后加，万无一失
                openclaw models add deepseek --base-url https://api.deepseek.com/v1 --api-key "$d_key"
                # 在 2026 版中，如果 set 不带前缀报错，则使用标准格式
                openclaw models set deepseek/deepseek-chat 
                openclaw gateway restart
                echo -e "${xfc_lv}✅ 已切换至 DeepSeek 引擎！${xfc_bai}"
            fi ;;
        4)
            echo -e "${xfc_huang}当前系统配置的模型列表：${xfc_bai}"
            openclaw models list
            read -p "按回车继续..." ;;
        *) return ;;
    esac
}

# --- 6. 主菜单 ---
xfc_main_menu() {
    clear
    echo -e "${xfc_lan}  "
    echo "                             小帆船 (cnxiaofanchuan) - 航海员               "
    echo -e "            ╚══════════════════════════════════════════════════════════╝${xfc_bai}"
    echo -e "  [1] ${xfc_lv}一键极简安装${xfc_bai} (针对 1G 内存优化)"
    echo -e "  [2] 启动 OpenClaw"
    echo -e "  [3] 停止 OpenClaw"
    echo -e "  [4] 机器人授权"
    echo -e "  [5] 换模型 / 填 Key"
    echo -e "  [6] ${xfc_hong}彻底卸载${xfc_bai}"
    echo -e "  [0] 退出脚本"
    echo
    read -p "  请选择 [0-6]: " xfc_choice
    case "$xfc_choice" in
        1) xfc_system_check; xfc_install_env; xfc_init_config; read -p "安装完成！以后输入 xfc 即可唤醒本菜单。回车继续..."; xfc_main_menu ;;
        2) openclaw gateway start; read -p "启动成功，回车返回..."; xfc_main_menu ;;
        3) openclaw gateway stop; read -p "已停止，回车返回..."; xfc_main_menu ;;
        4)
		   echo -e "${xfc_lan}>>> 正在进入『机器人授权中心』...${xfc_bai}"
		   echo -e "${xfc_huang}请在 Telegram 机器人对话框中获取 8 位 Pairing code (连接码)${xfc_bai}"
		   read -p "请输入连接码: " xfc_pcode
		   if [ ! -z "$xfc_pcode" ]; then
			# 核心命令：将输入的码传给 OpenClaw 授权
			openclaw pairing approve telegram "$xfc_pcode"
			echo -e "${xfc_lv}✅ 授权成功！现在去 Telegram 调教你的机器人吧。${xfc_bai}"
		   else
			echo -e "${xfc_hong}取消授权：未输入连接码。${xfc_bai}"
		   fi
		   read -p "按回车返回菜单..." ; 
           ;;
        5) xfc_manage_models; xfc_main_menu ;;
        6) npm uninstall -g openclaw; rm -rf ~/.openclaw /opt/xfc_node /usr/local/bin/xfc; echo "已清理"; exit 0 ;;
        0) exit 0 ;;
        *) xfc_main_menu ;;
    esac
}
xfc_main_menu
