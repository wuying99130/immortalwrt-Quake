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
CONFIG_PACKAGE_luci
