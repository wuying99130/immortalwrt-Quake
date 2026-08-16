#!/bin/bash
set -e

#=============================================
# ImmortalWrt 编译脚本 - NanoPi R1S H3
#=============================================

echo "=== 开始编译 ImmortalWrt for NanoPi R1S H3 ==="

# 克隆 ImmortalWrt 24.10 稳定分支
if [ ! -d immortalwrt ]; then
  echo "=== 克隆 ImmortalWrt 源码 ==="
  git clone --depth 1 -b openwrt-24.10 https://github.com/immortalwrt/immortalwrt.git
fi

cd immortalwrt

# 添加自定义 feeds（如果有的话）
# echo "src-git custom https://github.com/xxx/custom.git" >> feeds.conf.default

# 更新 feeds
echo "=== 更新 feeds ==="
./scripts/feeds update -a
./scripts/feeds install -a

# 写入基础配置
echo "=== 生成 .config ==="
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

# 展开完整 defconfig
echo "=== 展开 defconfig ==="
make defconfig

# 调用 DTS 补丁脚本
echo "=== 应用 DTS 补丁 ==="
bash target/linux/sunxi/patch-dts.sh

# 下载所有源码包
echo "=== 下载源码包 ==="
make download -j8

# 输出编译前的配置摘要
echo "=== 配置摘要 ==="
echo "Target: sunxi/cortexa7 - NanoPi R1S H3"
echo "RootFS: squashfs"
echo "WiFi: brcmfmac + cypress-firmware-43430-sdio"
echo ""

# 编译
echo "=== 开始编译 ==="
make -j$(nproc) || make -j1 V=s

# 输出结果
echo ""
echo "=== 编译完成 ==="
echo ""
echo "生成的固件:"
find bin/targets/sunxi/cortexa7/ -maxdepth 1 -type f \( -name "*.img.gz" -o -name "*.img" -o -name "*squashfs*" \) 2>/dev/null | sort

echo ""
echo "=== 固件信息 ==="
ls -lh bin/targets/sunxi/cortexa7/*.img.gz 2>/dev/null || echo "未找到 .img.gz 文件"

echo ""
echo "=== Done ==="
