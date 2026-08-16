#!/bin/bash
set -e

# 克隆 ImmortalWrt 24.10 稳定分支
if [ ! -d immortalwrt ]; then
  git clone --depth 1 -b openwrt-24.10 https://github.com/immortalwrt/immortalwrt.git
fi

cd immortalwrt

./scripts/feeds update -a
./scripts/feeds install -a

cat > .config << 'EOF'
CONFIG_TARGET_sunxi=y
CONFIG_TARGET_sunxi_cortexa7=y
CONFIG_TARGET_sunxi_cortexa7_DEVICE_friendlyarm_nanopi-r1s-h3=y
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_coreutils=y
CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-net-rtl8152=y
CONFIG_PACKAGE_kmod-brcmfmac=y
CONFIG_PACKAGE_cypress-firmware-43430-sdio=y
CONFIG_PACKAGE_iw=y
CONFIG_PACKAGE_iwinfo=y
CONFIG_PACKAGE_wpad-basic-mbedtls=y
CONFIG_PACKAGE_luci=y
CONFIG_LUCI_LANG_zh_Hans=y
EOF

make defconfig

# 修复 mmc2 DTS — 让 SDIO 控制器启用
DTS_FILE=$(find target/linux/sunxi/dts* -name "*nanopi*r1s*" -name "*.dts" | head -1)
if [ -n "$DTS_FILE" ]; then
  echo "=== Patching DTS: $DTS_FILE ==="
  sed -i '/&mmc2/,/};/s/status = "disabled";/status = "okay";/' "$DTS_FILE"
fi

make download -j8
make -j$(nproc) || make -j1 V=s

echo "=== Done ==="
find bin/targets/sunxi/cortexa7/ -maxdepth 1 -type f -name "*.img.gz"
