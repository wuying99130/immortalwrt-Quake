#!/bin/bash
set -e

# ============================================
# ImmortalWrt 编译脚本 (精简日志版)
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
echo "  目标: Raspberry Pi 4B"
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
libssl-dev python3 python3-dev python3-pip python3-setuptools \
rsync unzip zlib1g-dev file wget subversion patch upx-ucl \
autoconf automake libtool
log_done "编译依赖安装完成"

# ---- 2. 检查环境 ----
next_step "检查编译环境"
log_sub "工作目录: $WORKDIR"

if [ -f "build.sh" ] && [ -f "Config.in" ]; then
    log_done "目录已是 ImmortalWrt 源码根目录"
else
    log_prog "克隆 ImmortalWrt 源码..."
    git clone -b openwrt-24.10 --single-branch --depth=1 \
        https://github.com/immortalwrt/immortalwrt.git "$WORKDIR"
    log_done "源码克隆完成"
fi

# ---- 3. 更新 feeds ----
next_step "更新 feeds"
log_sub "更新 feeds 源..."
./scripts/feeds update -a
log_sub "安装 feeds 包..."
./scripts/feeds install -a
log_done "feeds 更新完成"

# ---- 4. 写入 .config ----
next_step "生成编译配置 (.config)"
cat > .config << 'EOF'
CONFIG_TARGET_bcm27xx=y
CONFIG_TARGET_bcm27xx_bcm2711=y
CONFIG_TARGET_bcm27xx_bcm2711_DEVICE_rpi-4=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-ssl=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_openssh-sftp-server=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_wget=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_iperf3=y
CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_kmod-fs-vfat=y
CONFIG_PACKAGE_kmod-fs-exfat=y
CONFIG_PACKAGE_kmod-fs-ntfs3=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_luci-app-samba4=y
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-statistics=y
CONFIG_PACKAGE_luci-app-nlbwmon=y
CONFIG_PACKAGE_luci-app-wireguard=y
EOF
log_done ".config 写入完成"

# ---- 5. defconfig ----
next_step "展开默认配置 (make defconfig)"
make defconfig
log_done "defconfig 完成"

# ---- 6. 下载源码 ----
next_step "下载源码包 (make download)"
log_prog "下载中，请耐心等待..."
make download -j8
log_sub "清理下载失败的空文件..."
find dl -size -1024c -exec rm -f {} \;
log_done "源码包下载完成"

# ---- 7. 编译工具链 ----
next_step "编译工具链 (make tools/install)"
log_prog "编译中..."
make tools/install -j$(nproc)
log_done "工具链编译完成"

# ---- 8. 编译交叉工具链 ----
next_step "编译交叉工具链 (make toolchain/install)"
log_prog "编译中..."
make toolchain/install -j$(nproc)
log_done "交叉工具链编译完成"

# ---- 9. 编译固件 ----
next_step "编译固件 (make)"
log_prog "编译固件，耗时较长，请耐心等待..."
echo "=== 开始编译（静默并行，失败时自动切换到详细模式） ==="
if make -j$(nproc) > /dev/null 2>&1; then
    log_done "固件编译完成"
else
    echo ""
    echo "=========================================="
    echo "  ⚠ 并行编译失败，切换到详细模式重试..."
    echo "=========================================="
    echo ""
    make -j1 V=s
    log_done "固件编译完成（详细模式）"
fi

# ---- 10. 输出 ----
next_step "生成产物"
log_sub "查找生成的固件..."
echo "=== 正在精准提取固件 ==="
BUILD_DATE=$(date +%Y%m%d)

mkdir -p bin/out
for file in bin/targets/bcm27xx/bcm2711/*.img.gz; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        new_filename="immortalwrt-bcm27xx-bcm2711-rpi-4-${BUILD_DATE}.img.gz"
        cp -f "$file" "bin/out/$new_filename"
        echo "已重命名镜像: $filename -> $new_filename"
    fi
done

for file in bin/targets/bcm27xx/bcm2711/*rootfs.tar.gz; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        new_filename="immortalwrt-bcm27xx-bcm2711-rootfs-${BUILD_DATE}.tar.gz"
        cp -f "$file" "bin/out/$new_filename"
        echo "已提取 Docker 容器包: $filename -> $new_filename"
    fi
done

if [ -f "bin/targets/bcm27xx/bcm2711/sha256sums" ]; then
    cp -f bin/targets/bcm27xx/bcm2711/sha256sums bin/out/
fi

echo "=== 打包输出目录清单 ==="
ls -lh bin/out/
log_done "产物就绪"

# ---- 汇总 ----
echo ""
echo "=========================================="
echo "          编译汇总"
echo "=========================================="
printf "  %-20s : %s\n" "源码分支" "openwrt-24.10"
printf "  %-20s : %s\n" "目标设备" "Raspberry Pi 4B"
printf "  %-20s : %s\n" "LuCI 主题" "Argon"
printf "  %-20s : %s\n" "管理界面" "中文 (zh-cn)"
printf "  %-20s : %s\n" "SSH 工具" "openssh-sftp-server"
printf "  %-20s : %s\n" "USB 存储" "ext4/vfat/exfat/ntfs3"
printf "  %-20s : %s\n" "插件" "Samba/UPnP/统计/负载/WireGuard"
printf "  %-20s : %s\n" "固件目录" "bin/out/"
echo "=========================================="
echo ""
log_done "全部完成! 固件位于 bin/out/"
echo ""
