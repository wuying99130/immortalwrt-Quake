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
readonly LOG_DIR="$WORK_DIR/logs"
readonly BUILD_LOG="$LOG_DIR/build.log"
readonly WARN_LOG="$LOG_DIR/warnings.log"

# ---- 初始化 ----
mkdir -p "$LOG_DIR"
: > "$BUILD_LOG"
: > "$WARN_LOG"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  ImmortalWrt 24.10 — NanoPi R1S-H3 编译"
echo "  开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "  并行数:   $JOBS"
echo "  日志目录: $LOG_DIR"
echo "════════════════════════════════════════════════════════════════"
echo ""

# ═══════════════════════════════════════════════════════════════
#  步骤 1/7：获取源码
# ═══════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  步骤 1/7：获取源码                                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
if [ ! -d "$BUILD_ROOT" ]; then
    git clone --depth=1 -b "$BRANCH" "$REPO_URL" "$BUILD_ROOT"
else
    cd "$BUILD_ROOT"
    git fetch origin "$BRANCH" --depth=1
    git reset --hard "origin/$BRANCH"
    cd "$WORK_DIR"
fi
cd "$BUILD_ROOT"
echo "  ✅ 完成"

# ═══════════════════════════════════════════════════════════════
#  步骤 2/7：更新 feeds
# ═══════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  步骤 2/7：更新 feeds                                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
./scripts/feeds update -a
./scripts/feeds install -a
echo "  ✅ 完成"

# ═══════════════════════════════════════════════════════════════
#  步骤 3/7：修复 radicale3 依赖
# ═══════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  步骤 3/7：修复 radicale3 依赖                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
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
echo "  ✅ 完成"

# ═══════════════════════════════════════════════════════════════
#  步骤 4/7：应用 DTS 补丁
# ═══════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  步骤 4/7：应用 DTS 补丁                                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
DTS_PATCH="$WORK_DIR/patch-dts.sh"
if [ -f "$DTS_PATCH" ]; then
    bash "$DTS_PATCH"
    echo "  ✅ DTS 补丁已应用"
else
    echo "  ❌ patch-dts.sh 未找到: $DTS_PATCH"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════
#  步骤 5/7：生成 .config
# ═══════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  步骤 5/7：生成 .config                                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
if [ ! -f "$WORK_DIR/.config" ] || [ ! -s "$WORK_DIR/.config" ]; then
    echo "  ❌ .config 文件缺失或为空"
    exit 1
fi
cp "$WORK_DIR/.config" .config
make defconfig
echo "  ✅ 完成"

# ═══════════════════════════════════════════════════════════════
#  步骤 6/7：下载源码包
# ═══════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  步骤 6/7：下载源码包                                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
make download -j"$JOBS" || {
    echo "  ⚠️ 部分下载失败，尝试重试..."
    make download -j1 V=s
}
echo "  ✅ 完成"

# ═══════════════════════════════════════════════════════════════
#  步骤 7/7：编译
# ═══════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  步骤 7/7：编译                                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  详细日志: $BUILD_LOG"
echo "  警告日志: $WARN_LOG"
echo ""

# 编译：完整日志写入文件，终端只显示 make 层级 + 警告/错误
make -j"$JOBS" V=s 2>&1 | tee -a "$BUILD_LOG" | grep -E \
    '^(make\[[0-9]\]|.*?(ERROR|Error|error:|WARNING|Warning|warning:|fatal|Failed|FAILED|undefined reference|No rule to make|No such file))' \

    | tee -a "$WARN_LOG" || true

MAKE_EXIT="${PIPESTATUS[0]}"

echo ""

# ---- 警告摘要 ----
if [ -s "$WARN_LOG" ]; then
    echo "─── 警告/错误摘要 ───"
    cat "$WARN_LOG"
    echo "──────────────────────"
fi

# ---- 编译失败处理 ----
if [ "$MAKE_EXIT" -ne 0 ]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      ❌ 编译失败                           ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "  退出码: $MAKE_EXIT"
    echo ""
    echo "─── 错误定位（最后 40 行）───"
    grep -E '(Error |error:|ERROR|FAILED|fatal|undefined reference|No rule to make|No such file)' \
        "$BUILD_LOG" | tail -40 || true
    echo "──────────────────────────────"
    echo ""
    echo "  完整日志: $BUILD_LOG"
    exit 1
fi

echo "  ✅ 编译完成"

# ═══════════════════════════════════════════════════════════════
#  收集固件
# ═══════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  收集固件                                                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
mkdir -p "$OUTPUT_DIR"
cp -v bin/targets/sunxi/cortexa7/*sdcard* "$OUTPUT_DIR/" 2>/dev/null || true
cp -v bin/targets/sunxi/cortexa7/*.img.gz "$OUTPUT_DIR/" 2>/dev/null || true

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  ✅ 编译完成"
echo "  结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "  固件目录: $OUTPUT_DIR"
echo "════════════════════════════════════════════════════════════════"
echo ""
ls -lh "$OUTPUT_DIR/"
