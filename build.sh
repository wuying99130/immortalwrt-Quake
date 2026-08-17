#!/bin/bash
set -e

# ==========================================
#  ImmortalWrt NanoPi R1S-H3 编译脚本
#  用于 GitHub Actions 云端编译
# ==========================================

EXTRA_PACKAGES="$1"

TARGET="sunxi/cortexa7"
DEVICE="friendlyarm_nanopi-r1s-h3"
DATE_ONLY=$(date +%Y%m%d)
BUILD_TIME=$(date '+%Y-%m-%d %H:%M:%S')
OUTPUT_DIR="/tmp/immortalwrt/firmware-${DATE_ONLY}"

cd /tmp/immortalwrt

# ---------- 更新 feeds ----------
echo ">>> 更新 feeds"
./scripts/feeds update -a
./scripts/feeds install -a

# ---------- 生成配置 ----------
echo ">>> 生成 .config"

cat > .config << EOF
CONFIG_TARGET_sunxi=y
CONFIG_TARGET_sunxi_cortexa7=y
CONFIG_TARGET_sunxi_cortexa7_DEVICE_${DEVICE}=y
CONFIG_TARGET_ROOTFS_EXT4FS=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_TARGET_ROOTFS_TARGZ=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-ssl=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_wget=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_iperf3=y
CONFIG_PACKAGE_nano=y
CONFIG_PACKAGE_tmux=y
CONFIG_PACKAGE_luci-app-statistics=y
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-firewall=y
CONFIG_PACKAGE_luci-app-nlbwmon=y
EOF

# 追加额外软件包
if [ -n "$EXTRA_PACKAGES" ]; then
    for pkg in $EXTRA_PACKAGES; do
        echo "CONFIG_PACKAGE_${pkg}=y" >> .config
    done
fi

make defconfig

# ---------- 编译 ----------
echo ""
echo "=========================================="
echo "  开始编译"
echo "=========================================="
echo ""

echo "[1/5] 下载源码包..."
make download V=s 2>&1 | grep -E "^\+|error|warning|Error|Warning|fail|Fail" || true

echo "[2/5] 编译工具链..."
make tools/compile V=s -j$(nproc) 2>&1 | grep -E "^make\[[12]\]|error|warning|Error|Warning" || true

echo "[3/5] 编译交叉工具链..."
make toolchain/compile V=s -j$(nproc) 2>&1 | grep -E "^make\[[12]\]|error|warning|Error|Warning" || true

echo "[4/5] 编译固件 (这步最久，耐心等待)..."
make V=s -j$(nproc) 2>&1 | grep -E "^make\[[12]\]|error|warning|Error|Warning" || true

echo "[5/5] 收集产物..."

# ---------- 收集产物 ----------
mkdir -p "$OUTPUT_DIR"

# 格式1: ext4-sdcard 裸镜像
EXT4_IMG=$(ls bin/targets/sunxi/cortexa7/*nanopi-r1*ext4-sdcard.img.gz 2>/dev/null | head -1)
if [ -f "$EXT4_IMG" ]; then
    gunzip -c "$EXT4_IMG" > "$OUTPUT_DIR/immortalwrt-sunxi-cortexa7-friendlyarm_nanopi-r1-ext4-sdcard-${DATE_ONLY}.img"
    echo "✅ ext4-sdcard 镜像"
fi

# 格式2: squashfs-sdcard 裸镜像
SQUASHFS_IMG=$(ls bin/targets/sunxi/cortexa7/*nanopi-r1*squashfs-sdcard.img.gz 2>/dev/null | head -1)
if [ -f "$SQUASHFS_IMG" ]; then
    gunzip -c "$SQUASHFS_IMG" > "$OUTPUT_DIR/immortalwrt-sunxi-cortexa7-friendlyarm_nanopi-r1-squashfs-sdcard-${DATE_ONLY}.img"
    echo "✅ squashfs-sdcard 镜像"
fi

# 格式3: rootfs.tar
ROOTFS_TAR=$(ls bin/targets/sunxi/cortexa7/*nanopi-r1*rootfs.tar.gz 2>/dev/null | head -1)
if [ -f "$ROOTFS_TAR" ]; then
    gunzip -c "$ROOTFS_TAR" > "$OUTPUT_DIR/immortalwrt-sunxi-cortexa7-rootfs-${DATE_ONLY}.tar"
    echo "✅ rootfs.tar"
fi

# ---------- 编译信息 ----------
cat > "$OUTPUT_DIR/build-info-${DATE_ONLY}.txt" << EOF
============================================
  ImmortalWrt NanoPi R1S-H3 编译信息
============================================
编译日期  : ${BUILD_TIME}
目标平台  : ${TARGET}
设备型号  : FriendlyARM NanoPi R1S-H3
内核版本  : $(ls bin/targets/sunxi/cortexa7/ 2>/dev/null | grep -oP 'linux-\K[0-9.]+' | head -1 || echo "未检测到")

--- 固件清单 ---
$(ls -lh "$OUTPUT_DIR/" 2>/dev/null | grep -v build-info)

--- 系统信息 ---
Git 分支  : $(git branch --show-current 2>/dev/null || echo "N/A")
Git 提交  : $(git rev-parse --short HEAD 2>/dev/null || echo "N/A")

--- 已选软件包 ---
$(grep -E '^CONFIG_PACKAGE_' .config 2>/dev/null | sort | sed 's/CONFIG_PACKAGE_/  - /' || echo "  无")

--- 完整 .config ---
$(cat .config 2>/dev/null || echo "  无")
EOF

echo ""
echo "=========================================="
echo "  编译完成！"
echo "=========================================="
ls -lh "$OUTPUT_DIR/"
