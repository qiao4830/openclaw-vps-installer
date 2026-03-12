# OpenClaw Lite VPS Installer 🚀

本项目是专门为 **低配置 VPS**（如 1核1G 内存、200Mbps 带宽的日本 OpenClaw 等机器）优化的一键安装脚本。

针对原版 OpenClaw 在小内存机器上容易出现的构建失败、运行 OOM（内存溢出）等问题进行了专门处理，并集成了网络加速功能。

---

## ✨ 脚本特点

* **⚡ TCP BBR 加速**：自动开启内核 BBR，充分利用 200Mbps 优化线路，降低丢包带来的速度衰减。
* **🧠 内存自动优化**：
    * **Swap 自动配置**：检测到内存小于 1.5GB 时，自动创建 1GB 交换分区，防止编译挂起。
    * **Node.js 限制**：针对 1G 内存机器，限制 Node 运行内存，预留系统空间，确保稳定。
* **🛠️ 一键部署**：自动处理 Node.js 环境、依赖安装及 Systemd 守护进程。
* **📦 简单易用**：一键命令，无需手动配置。

---

## 🚀 快速安装

在你的 VPS 终端（推荐 Debian/Ubuntu）直接复制并执行以下命令：

```bash
curl -O [https://raw.githubusercontent.com/qiao4830/openclaw-vps-installer/main/openclaw-lite.sh](https://raw.githubusercontent.com/qiao4830/openclaw-vps-installer/main/openclaw-lite.sh) && chmod +x openclaw-lite.sh && ./openclaw-lite.sh
