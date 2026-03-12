# ⛵ OpenClaw Nautical Pro Installer

适用于 **1G / 2G RAM VPS** 的 OpenClaw 一键部署脚本。  
脚本负责完成基础环境优化，然后调用 **OpenClaw 官方 Installer** 进行安装，尽量保持与官方流程一致。

## 特性

- 自动创建 **1GB Swap**
- 可选启用 **BBR**
- 自动检查网络与 DNS
- 使用 **官方 installer**
- 支持 **静默安装**

## 适用环境

- Ubuntu / Debian
- 1C1G、1C2G 及以上 VPS
- 需要可访问外网并解析 `openclaw.ai`
- OpenClaw 需要 **Node 22+**，官方 installer 会自动处理

## 安装

    curl -fsSL https://raw.githubusercontent.com/qiao4830/openclaw-vps-installer/main/openclaw-lite.sh -o openclaw-lite.sh && chmod +x openclaw-lite.sh && sudo bash openclaw-lite.sh

## 可选模式

使用 npm 安装：

    sudo OPENCLAW_INSTALL_METHOD=npm bash openclaw-lite.sh

使用 git 安装：

    sudo OPENCLAW_INSTALL_METHOD=git bash openclaw-lite.sh

指定源码目录：

    sudo OPENCLAW_INSTALL_METHOD=git OPENCLAW_GIT_DIR=/opt/openclaw bash openclaw-lite.sh


## 常见问题

**DNS 解析失败怎么办？**  
先检查：
    getent hosts openclaw.ai
    resolvectl status
    systemctl status systemd-resolved

不建议直接覆盖 `/etc/resolv.conf`，因为很多系统会自动托管这个文件。

**为什么不手搓 `git clone && npm install && npm run build`？**  
因为官方 installer 已经支持更完整的自动化安装流程，兼容性通常更好。

## 安装后
    openclaw --help
    node -v

如需首次初始化：
    openclaw onboard --install-daemon

## 链接

- 官方网站：https://openclaw.ai
- 官方文档：https://docs.openclaw.ai/install
- YouTube：https://www.youtube.com/@cnxiaofanchuan

## 声明

这是第三方 VPS 自动化封装脚本，不是 OpenClaw 官方项目。  
OpenClaw 本体安装行为以官方文档为准。
