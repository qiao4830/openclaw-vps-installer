# OpenClaw VPS Installer

适用于 **1G / 2G RAM 小内存 VPS** 的 OpenClaw 一键部署脚本。  
本项目不重写 OpenClaw 的核心安装逻辑，而是负责完成 VPS 环境准备，然后调用 **OpenClaw 官方 Installer** 完成安装，这样更稳、更容易兼容后续版本更新。[web:34][web:37]

## 项目定位

这个脚本主要解决下面几个问题：

- 小内存 VPS 安装时容易因为内存不足卡住或失败。
- 新手用户不想手动处理 Swap、基础依赖、网络预检这些步骤。
- 民间“手搓 git clone + npm build”方案容易和官方流程脱节，后续版本更新容易坏掉。[web:34]

所以本仓库的目标很简单：

- 帮你准备好 VPS 环境。
- 尽量做到一键化。
- **OpenClaw 本体安装仍然交给官方 installer**。[web:37][web:102]

---

## 特点

- 针对 **1G / 2G RAM VPS** 做了轻量优化。
- 自动检查并创建 **1G Swap**，减少小内存机器安装失败概率。
- 可选启用 **BBR** 网络优化。
- 安装过程采用 **OpenClaw 官方 installer**，而不是自己维护一套非官方源码构建流程。[web:34][web:37]
- 支持 **静默安装**，适合服务器一键部署。[web:34]
- 尽量避免直接破坏系统托管配置，比如不粗暴覆盖 `/etc/resolv.conf`。[web:34]

---

## 适用环境

- Ubuntu / Debian VPS。
- 推荐全新系统环境。
- 推荐 1C1G、1C2G、2C2G 及以上机型。
- 服务器需要能够正常访问外网，并能解析 `openclaw.ai`。[web:37]

> 说明：OpenClaw 官方要求 **Node 22 或更高版本**，官方 installer 会自动检测并在缺失时安装，所以本脚本不再自己手搓 Node 安装流程。[web:37][web:83]

---

## 安装方式

### 默认安装

```bash
curl -fsSL https://raw.githubusercontent.com/你的用户名/qia4830/openclaw-vps-installer.sh -o openclaw-vps-installer.sh
chmod +x openclaw-vps-installer.sh
sudo bash openclaw-vps-installer.sh
