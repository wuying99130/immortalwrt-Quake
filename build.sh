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
echo "=== 步骤 1/6：获取源码 ==="
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
echo "=== 步骤 2/6：更新 feeds ==="
./scripts/feeds update -a
./scripts/feeds install -a

# ---------- 3. 修复 radicale3 依赖 ----------
echo "=== 步骤 3/6：修复 radicale3 依赖 ==="
sed -i 's/+rpcd-mod-rad3-enc//g' feeds/luci/applications/luci-app-radicale3/Makefile

# ---------- 4. 生成完整配置 ----------
echo "=== 步骤 4/6：生成 .config ==="
if [ ! -f "$WORK_DIR/.config" ] || [ ! -s "$WORK_DIR/.config" ]; then
    echo "❌ .config 文件缺失或为空"
    exit 1
fi
cp "$WORK_DIR/.config" .config
make defconfig

# ---------- 5. 下载源码包 ----------
echo "=== 步骤 5/6：下载源码包 ==="
make download -j"$JOBS" || {
    echo "⚠️ 部分下载失败，尝试重试..."
    make download -j1 V=s
}

# ---------- 6. 编译 ----------
echo "=== 步骤 6/6：开始编译 (-j${JOBS}) ==="
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
