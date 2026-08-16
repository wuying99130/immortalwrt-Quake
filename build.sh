#!/bin/bash
set -e

#=============================================
# ImmortalWrt 编译脚本 - NanoPi R1S H3
#=============================================

# 日期和版本号
BUILD_DATE=$(date +%Y%m%d)
VERSION="24.10"
FW_TAG="${VERSION}-${BUILD_DATE}"

echo "=== 开始编译 ImmortalWrt for NanoPi R1S H3 ==="
echo "=== 版本: ${FW_TAG} ==="

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
bash patch-dts.sh

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

# 提取固件到上级目录，只匹配 NanoPi R1，并重命名加日期版本号
FW_DIR="../firmware-${FW_TAG}"
mkdir -p "${FW_DIR}"

echo "=== 提取固件 (NanoPi R1 only) ==="
find bin/targets/sunxi/cortexa7/ -maxdepth 1 -type f \
  \( -name "*NanoPi R1*" -o -name "*nanopi-r1*" -o -name "*nanopi_r1*" \) \
  ! -name "*.manifest" \
  -print0 | while IFS= read -r -d '' f; do
    basename_f=$(basename "$f")
    # 在文件名中插入日期版本号
    # 例如: immortalwrt-24.10.0-sunxi-cortexa7-friendlyarm_nanopi-r1s-h3-squashfs-sdcard.img.gz
    # 变成:  immortalwrt-24.10-20260816-sunxi-cortexa7-friendlyarm_nanopi-r1s-h3-squashfs-sdcard.img.gz
    newname=$(echo "$basename_f" | sed "s/\(immortalwrt\)-[^-]*/\1-${FW_TAG}/")
    cp -v "$f" "${FW_DIR}/${newname}"
done

echo ""
echo "=== 固件目录: ${FW_DIR} ==="
ls -lh "${FW_DIR}"

echo ""
echo "=== Done ==="
