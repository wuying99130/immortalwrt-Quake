#!/bin/bash
set -e

#=============================================
# DTS 补丁 - 启用 mmc2 (SDIO WiFi)
#=============================================

echo "=== 查找 NanoPi R1S DTS 文件 ==="

DTS_FILE=$(find target/linux/sunxi/ -name "*nanopi*r1s*" -name "*.dts" 2>/dev/null | head -1)

if [ -z "$DTS_FILE" ]; then
  echo "=== ERROR: DTS 文件未找到 ==="
  echo "=== 搜索所有 nanopi 相关 DTS: ==="
  find target/linux/sunxi/ -name "*.dts" -o -name "*.dtsi" 2>/dev/null | grep -i nanopi || echo "(未找到任何 nanopi DTS 文件)"
  echo "=== 列出 sunxi 下所有 DTS 文件: ==="
  find target/linux/sunxi/ -name "*.dts" 2>/dev/null | head -30
  exit 1
fi

echo "=== 找到 DTS: $DTS_FILE ==="

echo "=== Patch 前 mmc2 块: ==="
grep -A6 '&mmc2' "$DTS_FILE" || echo "(mmc2 块未找到)"

# 将 mmc2 的 status = "disabled" 改为 status = "okay"
sed -i '/&mmc2/,/};/s/status = "disabled";/status = "okay";/' "$DTS_FILE"

echo "=== Patch 后 mmc2 块: ==="
grep -A6 '&mmc2' "$DTS_FILE"

echo "=== DTS 补丁完成 ==="
