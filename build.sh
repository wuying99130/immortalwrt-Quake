#!/bin/bash
set -euo pipefail

# ============================================
# ImmortalWrt 24.10 编译脚本
# 目标：NanoPi R1S-H3 (sunxi/cortexa7)
# ============================================

readonly REPO_URL="https://github.com/immortalwrt/immortalwrt"
readonly BRANCH="openwrt-24.10"
readonly BUILD_ROOT="$PWD/immortalwrt"
readonly WORK_DIR="$PWD"
readonly OUTPUT_DIR="$WORK_DIR/firmware-24.10-$(date +%Y%m%d)"
readonly JOBS="$(($(nproc) + 1))"

# ---------- 1. 克隆源码 ----------
echo "=== 步骤 1/7：获取源码 ==="
if [ ! -d "$BUILD_ROOT" ]; then
    git clone --depth=1 -b "$BRANCH" "$REPO_URL" "$BUILD_ROOT"
else
    cd "$BUILD_ROOT"
    git fetch origin "$BRANCH" --depth=1
    git reset --hard "origin/$BRANCH"
    cd "$WORK_DIR"
fi
cd "$BUILD_ROOT"

# ---------- 2. 更新 feeds ----------
echo "=== 步骤 2/7：更新 feeds ==="
./scripts/feeds update -a
./scripts/feeds install -a

# ---------- 3. 修复 radicale3 依赖 ----------
echo "=== 步骤 3/7：修复 radicale3 依赖 ==="
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

# ---------- 4. 应用 DTS 补丁 ----------
echo "=== 步骤 4/7：应用 DTS 补丁 ==="
DTS_PATCH="$WORK_DIR/patch-dts.sh"
if [ -f "$DTS_PATCH" ]; then
    bash "$DTS_PATCH"
    echo "✅ DTS 补丁已应用"
else
    echo "❌ patch-dts.sh 未找到: $DTS_PATCH"
    exit 1
fi

# ---------- 5. 生成完整配置 ----------
echo "=== 步骤 5/7：生成 .config ==="
if [ ! -f "$WORK_DIR/.config" ] || [ ! -s "$WORK_DIR/.config" ]; then
    echo "❌ .config 文件缺失或为空"
    exit 1
fi
cp "$WORK_DIR/.config" .config
make defconfig

# ---------- 6. 下载源码包 ----------
echo "=== 步骤 6/7：下载源码包 ==="
make download -j"$JOBS" || {
    echo "⚠️ 部分下载失败，尝试重试..."
    make download -j1 V=s
}

# ---------- 7. 编译 ----------
echo "=== 步骤 7/7：开始编译 (-j${JOBS}) ==="
make -j"$JOBS" 2>&1 | tee "$WORK_DIR/build.log" || {
    echo "=== 编译失败，输出详细日志（最后 200 行）==="
    tail -200 "$WORK_DIR/build.log"
    echo ""
    echo "=== 重新编译（单线程 + 详细输出）==="
    make -j1 V=s
    exit 1
}

# ---------- 收集产物 ----------
echo "=== 收集固件 ==="
mkdir -p "$OUTPUT_DIR"
cp -v bin/targets/sunxi/cortexa7/*sdcard* "$OUTPUT_DIR/" 2>/dev/null || true
cp -v bin/targets/sunxi/cortexa7/*.img.gz "$OUTPUT_DIR/" 2>/dev/null || true

echo ""
echo "=========================================="
echo "  编译完成！"
echo "  固件目录: $OUTPUT_DIR"
echo "=========================================="
ls -lh "$OUTPUT_DIR/"
