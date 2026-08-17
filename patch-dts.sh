#!/bin/bash
set -e

echo "=== 查找/创建 NanoPi R1S DTS 文件 ==="

DTS_DIR="target/linux/sunxi/dts"
DTSI_FILE="${DTS_DIR}/sun8i-h3-nanopi.dtsi"
DTS_FILE="${DTS_DIR}/sun8i-h3-nanopi-r1s-h3.dts"

# ============================================================
# 第一步：如果 sun8i-h3-nanopi.dtsi 不存在，创建它
# 这是所有 NanoPi H3 板子的公共基文件
# ============================================================
if [ ! -f "$DTSI_FILE" ]; then
    echo "=== sun8i-h3-nanopi.dtsi 不存在，正在创建 ==="
    mkdir -p "$DTS_DIR"
    cat > "$DTSI_FILE" << 'DTSI_EOF'
// SPDX-License-Identifier: (GPL-2.0+ OR MIT)
/*
 * Common dtsi for NanoPi H3 boards (NEO, NEO Air, NEO Core, M1, R1, R1S etc.)
 * Based on FriendlyARM's sunxi-4.14.y kernel tree
 */

#include "sun8i-h3.dtsi"

/ {
	aliases {
		serial0 = &uart0;
		ethernet0 = &emac;
	};

	chosen {
		stdout-path = "serial0:115200n8";
	};

	leds {
		compatible = "gpio-leds";
		pinctrl-names = "default";
		pinctrl-0 = <&leds_nanopi>, <&leds_r_nanopi>;

		status_led: status {
			label = "nanopi:green:status";
			gpios = <&pio 0 10 GPIO_ACTIVE_HIGH>; /* PA10 */
			linux,default-trigger = "heartbeat";
		};

		pwr_led: pwr {
			label = "nanopi:green:pwr";
			gpios = <&r_pio 0 10 GPIO_ACTIVE_HIGH>; /* PL10 */
			default-state = "on";
		};
	};

	reg_vcc3v3: vcc3v3 {
		compatible = "regulator-fixed";
		regulator-name = "vcc3v3";
		regulator-min-microvolt = <3300000>;
		regulator-max-microvolt = <3300000>;
	};

	reg_usb0_vbus: usb0-vbus {
		compatible = "regulator-fixed";
		regulator-name = "usb0-vbus";
		regulator-min-microvolt = <5000000>;
		regulator-max-microvolt = <5000000>;
		enable-active-high;
		gpio = <&r_pio 0 2 GPIO_ACTIVE_HIGH>; /* PL2 */
		status = "okay";
	};

	reg_gmac_3v3: gmac-3v3 {
		compatible = "regulator-fixed";
		regulator-name = "gmac-3v3";
		regulator-min-microvolt = <3300000>;
		regulator-max-microvolt = <3300000>;
		startup-delay-us = <100000>;
		enable-active-high;
		gpio = <&pio 3 6 GPIO_ACTIVE_HIGH>; /* PD6 */
	};
};

&pio {
	leds_nanopi: led-pins {
		pins = "PA10";
		function = "gpio_out";
	};
};

&r_pio {
	leds_r_nanopi: led-pins {
		pins = "PL10";
		function = "gpio_out";
	};
};

&mmc0 {
	pinctrl-names = "default";
	pinctrl-0 = <&mmc0_pins>;
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
	usb0_vbus-supply = <&reg_usb0_vbus>;
	status = "okay";
};
DTSI_EOF
    echo "=== sun8i-h3-nanopi.dtsi 已创建 ==="
else
    echo "=== sun8i-h3-nanopi.dtsi 已存在 ==="
fi

# ============================================================
# 第二步：创建 R1S 专用的板级 DTS（你之前的代码）
# ============================================================
if [ ! -f "$DTS_FILE" ]; then
    echo "=== DTS 文件不存在，正在创建 ==="
    cat > "$DTS_FILE" << 'DTS_EOF'
/dts-v1/;

#include "sun8i-h3-nanopi.dtsi"

/ {
	model = "FriendlyARM NanoPi R1S H3";
	compatible = "friendlyarm,nanopi-r1s-h3", "allwinner,sun8i-h3";

	aliases {
		ethernet1 = &rtl8152;
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
DTS_EOF
    echo "=== DTS 文件已创建 ==="
else
    echo "=== DTS 文件已存在 ==="
fi

# ============================================================
# 第三步：确保 Makefile 里有对应条目
# ============================================================
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
