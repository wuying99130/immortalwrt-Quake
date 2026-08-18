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
# ==========================================
# 禁用默认 profile（手写包作为唯一全部）
# ==========================================
CONFIG_TARGET_MULTI_PROFILE=n
CONFIG_TARGET_PER_DEVICE_ROOTFS=y
CONFIG_TARGET_DEFAULT_PACKAGES=""

# ==========================================
# Target: NanoPi R1S-H3 (Allwinner H3, sunxi/cortexa7)
# ==========================================
CONFIG_TARGET_sunxi=y
CONFIG_TARGET_sunxi_cortexa7=y
CONFIG_TARGET_sunxi_cortexa7_DEVICE_friendlyarm_nanopi-r1s-h3=y

# RootFS
CONFIG_TARGET_ROOTFS_EXT4FS=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_TARGET_ROOTFS_TARGZ=y

# ==========================================
# LuCI Web 管理
# ==========================================
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-ssl=y
CONFIG_PACKAGE_libustream-mbedtls=y
CONFIG_PACKAGE_libustream-openssl=n
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-proto-ppp=y
CONFIG_PACKAGE_luci-proto-ipv6=y

# ==========================================
# 主题
# ==========================================
CONFIG_PACKAGE_luci-theme-argon=y

# ==========================================
# USB 内核模块
# ==========================================
CONFIG_PACKAGE_kmod-usb2=y
CONFIG_PACKAGE_kmod-usb-ohci=y
CONFIG_PACKAGE_kmod-usb-ehci=y
CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-net-rtl8152=y

# ==========================================
# WiFi (BCM43430 / AP6212)
# ==========================================
CONFIG_PACKAGE_kmod-brcmfmac=y
CONFIG_PACKAGE_brcmfmac-firmware-43430-sdio=y

# ==========================================
# 无线工具
# ==========================================
CONFIG_PACKAGE_hostapd=y
CONFIG_PACKAGE_wpa-supplicant=y
CONFIG_PACKAGE_wpad-basic=y
CONFIG_PACKAGE_iw=y
CONFIG_PACKAGE_wireless-regdb=y

# ==========================================
# 网络基础（轻量稳定）
# ==========================================
CONFIG_PACKAGE_dnsmasq=y
CONFIG_PACKAGE_dnsmasq-full=n
CONFIG_PACKAGE_firewall4=y
CONFIG_PACKAGE_nftables=y
CONFIG_PACKAGE_ppp=y
CONFIG_PACKAGE_ppp-mod-pppoe=y
CONFIG_PACKAGE_ip-full=y
CONFIG_PACKAGE_iptables-nft=y

# ==========================================
# IPv6
# ==========================================
CONFIG_PACKAGE_ip6tables-nft=y

# ==========================================
# 工具
# ==========================================
CONFIG_PACKAGE_bash=y
CONFIG_PACKAGE_coreutils=y
CONFIG_PACKAGE_block-mount=y

# ==========================================
# 文件系统支持
# ==========================================
CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_kmod-fs-vfat=y
CONFIG_PACKAGE_kmod-nls-cp437=y
CONFIG_PACKAGE_kmod-nls-iso8859-1=y
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
for file in bin/targets/sunxi/cortexa7/*.img.gz; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        new_filename="immortalwrt-sunxi-cortexa7-nanopi-r1s-h3-${BUILD_DATE}.img.gz"
        cp -f "$file" "bin/out/$new_filename"
        echo "已重命名镜像: $filename -> $new_filename"
    fi
done

for file in bin/targets/sunxi/cortexa7/*rootfs.tar.gz; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        new_filename="immortalwrt-sunxi-cortexa7-rootfs-${BUILD_DATE}.tar.gz"
        cp -f "$file" "bin/out/$new_filename"
        echo "已提取 rootfs 包: $filename -> $new_filename"
    fi
done

if [ -f "bin/targets/sunxi/cortexa7/sha256sums" ]; then
    cp -f bin/targets/sunxi/cortexa7/sha256sums bin/out/
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
printf "  %-20s : %s\n" "目标设备" "NanoPi R1S-H3 (Allwinner H3)"
printf "  %-20s : %s\n" "目标平台" "sunxi/cortexa7"
printf "  %-20s : %s\n" "LuCI 主题" "Argon"
printf "  %-20s : %s\n" "WiFi" "BCM43430 (brcmfmac)"
printf "  %-20s : %s\n" "USB 网络" "RTL8152"
printf "  %-20s : %s\n" "文件系统" "ext4/squashfs/targz"
printf "  %-20s : %s\n" "固件目录" "bin/out/"
echo "=========================================="
echo ""
log_done "全部完成! 固件位于 bin/out/"
echo ""
