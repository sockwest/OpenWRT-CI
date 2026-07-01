#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

# [系统精简] 移除旧版固件升级依赖 (防臃肿)
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")

# [极简主题设定] 强制替换编译框架的默认主题为 Shadcn (契合极简高效的数据化审美)
sed -i "s/luci-theme-bootstrap/luci-theme-shadcn/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")

# [网络配置] 修改 immortalwrt.lan 关联的内网 IP 为你自定义的 IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")

# [系统标识] 添加带日期的编译版本号，方便后续在网页后台直观辨识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

# [WIFI 初始化] 预设无线名称与密码 (雅典娜如作纯网关通常不会生效，保留作为代码防错兜底)
WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
	sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

# [网络初始化] 替换全新安装时的默认 IP 和主机名
CFG_FILE="./package/base-files/files/bin/config_generate"
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

# =================================================================
# 写入底层配置文件 (.config)
# =================================================================
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config

# [双语环境] 增加英文环境，保障跨境业务后台的专业网络词汇显示准确无误
echo "CONFIG_LUCI_LANG_en=y" >> ./.config

# [纯净主题锁定] 仅写入扁平化 Shadcn 主题。
# (注意：已剔除原版 echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" 代码，防止因 Shadcn 无配套控制面板而引发编译报错)
echo "CONFIG_PACKAGE_luci-theme-shadcn=y" >> ./.config

# [私有扩展] 引入额外的 PRIVATE.txt 配置文件
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

# [自定义包] 手动调整的插件环境导入
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

# [无 WIFI 标志] 识别全量编译配置中的 Wi-Fi 设定
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

# =================================================================
# 雅典娜 (高通 IPQ60xx 平台) 专属底层调整
# =================================================================
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
	
	# -----------------------------------------------------------------
	# 强制修改内核物理分区大小限制 (雅典娜防报错核心魔法指令)
	# -----------------------------------------------------------------
	# 运作逻辑:
	# 1. 雅典娜原厂源码将内核 (HLOS) 大小死锁在极其保守的体积 (约 6MB-8MB)。
	# 2. 此处暴力搜索高通的 .mk 配置文件，将所有 KERNEL_SIZE 强行拔高到 12MB (12288k)。
	# 3. 借此放宽编译器的体积质检标准，确保即使未来塞入 Docker 底层网络支持，也不会因内核超限而打包失败。
	if [ -f "target/linux/qualcommax/image/ipq60xx.mk" ]; then
		sed -i 's/KERNEL_SIZE := .*/KERNEL_SIZE := 12288k/g' target/linux/qualcommax/image/ipq60xx.mk
		echo "Magically expanded KERNEL_SIZE to 12MB for qualcommax ipq60xx!"
	fi
fi
