#!/bin/bash
set -e

# ============================================
# ImmortalWrt 24.10 编译脚本
# 目标：NanoPi R1S-H3 (sunxi/cortexa7)
# ============================================

REPO_URL="https://github.com/immortalwrt/immortalwrt"
BRANCH="openwrt-24.10"
BUILD_ROOT="$PWD/immortalwrt"
WORK_DIR="$PWD"              # immortalwrt-Quake 目录
OUTPUT_DIR="$WORK_DIR/firmware-24.10-$(date +%Y%m%d)"

# ---------- 1. 克隆源码 ----------
if [ ! -d "$BUILD_ROOT" ]; then
    echo "=== 克隆 ImmortalWrt 源码 ==="
    git clone --depth=1 -b "$BRANCH" "$REPO_URL" "$BUILD_ROOT"
else
    echo "=== 源码已存在，git pull 更新 ==="
    cd "$BUILD_ROOT"
    git pull
    cd "$WORK_DIR"
fi

cd "$BUILD_ROOT"

# ---------- 2. 更新 feeds ----------
echo "=== 更新 feeds ==="
./scripts/feeds update -a
./scripts/feeds install -a

# ---------- 3. 修复 radicale3 依赖 ----------
echo "=== 修复 radicale3 依赖 ==="
mkdir -p package/feeds/luci/rpcd-mod-rad3-enc
cat > package/feeds/luci/rpcd-mod-rad3-enc/Makefile << 'MAKEFILE_EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=rpcd-mod-rad3-enc
PKG_VERSION:=1.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/rpcd-mod-rad3-enc
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Radicale 3 encryption module (stub)
  DEPENDS:=+rpcd
endef

define Package/rpcd-mod-rad3-enc/description
  Stub package to satisfy luci-app-radicale3 dependency.
endef

define Build/Compile
endef

define Package/rpcd-mod-rad3-enc/install
endef

$(eval $(call BuildPackage,rpcd-mod-rad3-enc))
MAKEFILE_EOF

# ---------- 4. 生成配置 ----------
echo "=== 生成 .config ==="
cat > .config << 'CONFIG_EOF'
CONFIG_TARGET_sunxi=y
CONFIG_TARGET_sunxi_cortexa7=y
CONFIG_TARGET_sunxi_cortexa7_DEVICE_friendlyarm_nanopi-r1s-h3=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-radicale3=y
CONFIG_PACKAGE_rpcd-mod-rad3-enc=y
CONFIG_PACKAGE_yate=n
CONFIG_EOF

echo "=== 展开 defconfig ==="
make defconfig

# ---------- 5. 应用 DTS 补丁 ----------
echo "=== 应用 DTS 补丁 ==="
DTS_PATCH="$WORK_DIR/patch-dts.sh"
if [ -f "$DTS_PATCH" ]; then
    bash "$DTS_PATCH"
    echo "✅ DTS 补丁已应用"
else
    echo "⚠️  patch-dts.sh 未找到: $DTS_PATCH"
fi

# ---------- 6. 编译（单线程，避免 OOM）----------
echo "=== 开始编译 ==="
make -j1 V=s 2>&1 | tee build.log

# ---------- 7. 收集产物 ----------
echo "=== 收集固件 ==="
mkdir -p "$OUTPUT_DIR"
cp bin/targets/sunxi/cortexa7/*sdcard* "$OUTPUT_DIR/" 2>/dev/null || tr
