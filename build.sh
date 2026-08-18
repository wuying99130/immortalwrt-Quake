#!/bin/bash
set -e

# ============================================
# ImmortalWrt 编译脚本 (修复版)
# ============================================

WORKDIR="/tmp/immortalwrt"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# 颜色
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_step()    { echo -e "${CYAN}◉${NC} $1"; }
log_prog()    { echo -e "${YELLOW}◔${NC} $1"; }
log_done()    { echo -e "${GREEN}●${NC} $1"; }
log_sub()     { echo -e "    ➔ $1"; }
log_skip()    { echo -e "    ◌ $1 (跳过)"; }

# 步骤计数
STEP=0
TOTAL=10
next_step() {
    STEP=$((STEP + 1))
    echo ""
    echo "=========================================="
    echo -e "${CYAN}[${STEP}/${TOTAL}]${NC} $1"
    echo "=========================================="
}

echo ""
echo "=========================================="
echo "  ImmortalWrt 编译脚本"
echo "  目标: NanoPi R1S-H3 (Allwinner H3)"
echo "  分支: openwrt-24.10"
echo "  时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="

# ---- 1. 安装编译依赖 ----
next_step "安装编译依赖"
log_prog "换清华源（解决云端 azure 源不通）..."
sudo sed -i 's|http://azure.archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
sudo sed -i 's|http://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
sudo sed -i 's|https://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list
log_sub "更新源..."
sudo apt update
log_sub "安装依赖包..."
sudo apt install -y build-essential clang flex bison g++ gawk \
gcc-multilib g++-multilib gettext git libfuse-dev libncurses5-dev \
libssl-dev python3 python3-dev python3-pip
