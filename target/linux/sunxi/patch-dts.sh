#!/bin/bash
set -e

echo "=== 查找/创建 NanoPi R1S DTS 文件 ==="

DTS_DIR="target/linux/sunxi/dts"
DTS_FILE="${DTS_DIR}/sun8i-h3-nanopi-r1s-h3.dts"

# 如果 DTS 文件不存在，创建一个
if [ ! -f "$DTS_FILE" ]; then
    echo "=== DTS 文件不存在，正在创建 ==="
    mkdir -p "$DTS_DIR"
    cat > "$DTS_FILE" << 'DTS_EOF'
/dts-v1/;

#include "sun8i-h3-nanopi.dtsi"

/ {
	model = "FriendlyARM NanoPi R1S H3";
	compatible = "friendlyarm,nanopi-r1s-h3", "allwinner,sun8i-h3";

	aliases {
		serial0 = &uart0;
		ethernet0 = &emac;
		ethernet1 = &rtl8152;
	};

	chosen {
		stdout-path = "serial0:115200n8";
	};

	reg_vdd_cpux: vdd-cpux-regulator {
		compatible = "regulator-gpio";
		regulator-name = "vdd-cpux";
		regulator-min-microvolt = <1100000>;
		regulator-max-microvolt = <1300000>;
		regulator-ramp-delay = <50>;
		regulator-type = "voltage";
		regulator-boot-on;
		regulator-always-on;
		gpios = <&r_pio 0 6 GPIO_ACTIVE_HIGH>; /* PL6 */
		gpios-states = <0x1>;
		states = <1100000 0x0>, <1300000 0x1>;
	};
};

&cpu0 {
	cpu-supply = <&reg_vdd_cpux>;
};

&ehci0 {
	status = "okay";
};

&ohci0 {
	status = "okay";
};

&emac {
	phy-handle = <&int_mii_phy>;
	phy-mode = "mii";
	allwinner,leds-active-low;
	status = "okay";
};

&mmc0 {
	vmmc-supply = <&reg_vcc3v3>;
	bus-width = <4>;
	cd-gpios = <&pio 5 6 GPIO_ACTIVE_LOW>; /* PF6 */
	status = "okay";
};

&uart0 {
	pinctrl-names = "default";
	pinctrl-0 = <&uart0_pa_pins>;
	status = "okay";
};

&usb_otg {
	dr_mode = "host";
	status = "okay";
};

&usbphy {
	usb0_id_det-gpios = <&pio 6 12 GPIO_ACTIVE_HIGH>; /* PG12 */
	status = "okay";
};
DTS_EOF
    echo "=== DTS 文件已创建 ==="
else
    echo "=== DTS 文件已存在 ==="
fi

# 确保 Makefile 里有对应条目
MAKEFILE="target/linux/sunxi/image/cortex-a7.mk"
if ! grep -q "nanopi-r1s-h3" "$MAKEFILE" 2>/dev/null; then
    echo "=== 添加 R1S 到 Makefile ==="
    cat >> "$MAKEFILE" << 'MK_EOF'

define Device/friendlyarm_nanopi-r1s-h3
	DEVICE_VENDOR := FriendlyARM
	DEVICE_MODEL := NanoPi R1S H3
	DEVICE_DTS := sun8i-h3-nanopi-r1s-h3
	SUPPORTED_DEVICES += friendlyarm,nanopi-r1s-h3
	DEVICE_PACKAGES := kmod-usb-net-rtl8152
endef
TARGET_DEVICES += friendlyarm_nanopi-r1s-h3
MK_EOF
    echo "=== Makefile 条目已添加 ==="
else
    echo "=== Makefile 条目已存在 ==="
fi

echo "=== DTS 补丁完成 ==="
