#!/bin/bash
# 用法: 在 immortalwrt 源码根目录下执行
# ./patch-dts.sh

DTS_FILE=$(find target/linux/sunxi/dts* -name "*nanopi*r1s*" -name "*.dts" 2>/dev/null | head -1)

if [ -z "$DTS_FILE" ]; then
  echo "ERROR: DTS file not found"
  echo "Searching for related files..."
  find target/linux/sunxi/ -name "*.dts" -o -name "*.dtsi" | grep -iE "r1s|nanopi"
  exit 1
fi

echo "=== Found: $DTS_FILE ==="
echo ""
echo "Before (mmc2 section):"
grep -A5 '&mmc2' "$DTS_FILE" || echo "(mmc2 block not found)"
echo ""

sed -i '/&mmc2/,/};/s/status = "disabled";/status = "okay";/' "$DTS_FILE"

echo "After (mmc2 section):"
grep -A5 '&mmc2' "$DTS_FILE" || echo "(mmc2 block not found)"
echo "=== Done ==="
