#!/bin/bash
set -e

echo "=== 查找 NanoPi R1S DTS 文件 ==="

DTS_FILE=$(find target/linux/sunxi/ -name "*.dts" | grep -iE "r1s|nanopi" | head -1)

if [ -z "$DTS_FILE" ]; then
  echo "=== ERROR: 未找到 R1S 相关 DTS 文件 ==="
  echo "=== 调试: sunxi 下所有 DTS ==="
  find target/linux/sunxi/ -name "*.dts" | sort
  exit 1
fi

echo "=== 找到 DTS: $DTS_FILE ==="

echo "=== Patch 前 mmc2 块: ==="
grep -A6 '&mmc2' "$DTS_FILE" || echo "(mmc2 块未找到)"

sed -i '/&mmc2/,/};/s/status = "disabled";/status = "okay";/' "$DTS_FILE"

echo "=== Patch 后 mmc2 块: ==="
grep -A6 '&mmc2' "$DTS_FILE"

echo "=== DTS 补丁完成 ==="
