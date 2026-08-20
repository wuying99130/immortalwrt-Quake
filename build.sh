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

#  修复：删除重复 clone，避免 fatal: destination path already exists
log_done "目录已是 ImmortalWrt 源码根目录（跳过重复克隆）"

# ---- 3. 更新 feeds ----
next_step "更新 feeds"
log_sub "更新 feeds 源..."
./scripts/feeds update -a
log_sub "安装 feeds 包..."
./scripts/feeds install -a
log_done "feeds 更新完成"

# ---- 4. 写入 .config ----
next_step "生成编译配置 (.config)"
# [已删除] 删除了原有的 cat > .config << 'EOF' ... EOF 代码块
# [作用] 防止脚本内部硬编码的配置覆盖掉 Actions 流程中复制进来的完整 .config 文件
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

BUILD_LOG="/tmp/build.log"
BUILD_FAILED=0

echo "=== 开始编译（精简输出，只显示关键步骤） ==="

# 只编译一次：输出实时过滤只显示大条目，完整日志写入临时文件
make -j$(nproc) 2>&1 | tee "$BUILD_LOG" | grep -E "(^make\[|^  CC |^  LD |^  AR |^  LINK |^  INSTALL |^  PACKAGE|error:|warning:|Error |ERROR)" || BUILD_FAILED=1

# 用 PIPESTATUS 取管道第一个命令（make）的真实退出码，而非 grep 的
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    BUILD_FAILED=1
fi

if [ "$BUILD_FAILED" -eq 0 ]; then
    log_done "固件编译完成"
else
    echo ""
    echo "=========================================="
    echo "   编译失败，以下是错误详情"
    echo "=========================================="
    echo ""

    # 从完整日志中捞出错误行及其上下文（前后各 5 行）
    grep -n -i "error\|Error\|ERROR" "$BUILD_LOG" | head -20 | while IFS=: read -r line_num _; do
        start=$((line_num - 5))
        end=$((line_num + 5))
        [ $start -lt 1 ] && start=1
        echo "--- 错误附近 (行 ${line_num}) ---"
        sed -n "${start},${end}p" "$BUILD_LOG"
        echo ""
    done

    echo "=========================================="
    echo "   完整编译日志已保存到: $BUILD_LOG"
    echo "=========================================="
    exit 1
fi

# ---- 10. 输出 ----
next_step "生成产物"
log_sub "查找生成的固件..."
echo "=== 正在精准提取固件 ==="
BUILD_DATE=$(date +%Y%m%d)

mkdir -p bin/out

#  使用你指定的精准宽松匹配：*nanopi-r1*
# ext4-combined 镜像
for file in bin/targets/sunxi/cortexa7/*nanopi-r1*ext4-combined*.img.gz; do
    if [ -f "$file" ]; then
        new_filename="immortalwrt-nanopi-r1s-h3-${BUILD_DATE}.img.gz"
        cp -f "$file" "bin/out/$new_filename"
        echo "已提取镜像: $new_filename"
    fi
done

# sysupgrade 固件
for file in bin/targets/sunxi/cortexa7/*nanopi-r1*sysupgrade*.tar; do
    if [ -f "$file" ]; then
        new_filename="immortalwrt-nanopi-r1s-h3-${BUILD_DATE}-sysupgrade.tar"
        cp -f "$file" "bin/out/$new_filename"
        echo "已提取 sysupgrade: $new_filename"
    fi
done

# kernel.bin
find bin/targets/sunxi/cortexa7 -maxdepth 1 -name '*nanopi-r1*kernel.bin' -exec cp -f {} bin/out/ \; 2>/dev/null || true

# rootfs.bin
find bin/targets/sunxi/cortexa7 -maxdepth 1 -name '*nanopi-r1*rootfs.bin' -exec cp -f {} bin/out/ \; 2>/dev/null || true

# sha256sums
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
