#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

# -----------------------------------------------------------------
# UPDATE_PACKAGE 函数定义 (保持上游逻辑不变，负责清理旧包并拉取新源码)
# -----------------------------------------------------------------
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}

	echo " "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not fonud directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

# -----------------------------------------------------------------
# 1. 核心主题与 UI 组件 (拉取你想保留的高颜值后台)
# -----------------------------------------------------------------
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"
# (已注释) 移除其他不需要的冗余主题，加快编译速度
# UPDATE_PACKAGE "shadcn" "eamonxg/luci-theme-shadcn" "main"
# UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
# UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"
# UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "master"
# UPDATE_PACKAGE "kucat-config" "sirpdboy/luci-app-kucat-config" "master"

# -----------------------------------------------------------------
# 2. 核心代理与分流网络组件 (业务架构的基石)
# -----------------------------------------------------------------
# 备用带界面的全能代理方案
UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"

# 【新增核心】引入 daed (基于 eBPF 的底层强扣引擎)
UPDATE_PACKAGE "daed" "QiuSimons/openwrt-dae" "master" "pkg"

# (已注释) 移除我们不需要的老旧、冗余代理方案
# UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
# UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
# UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
# UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
# UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"
# UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"

# -----------------------------------------------------------------
# 3. 实用工具包 (仅保留需要的)
# -----------------------------------------------------------------
# 保留网络带宽监控工具
UPDATE_PACKAGE "nlbwmon" "sbwml/luci-app-nlbwmon" "master"

# (已注释) 强制移除所有不需要的伪 NAS、磁盘管理、下载工具
# UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
# UPDATE_PACKAGE "diskman" "sbwml/luci-app-diskman" "main"
# UPDATE_PACKAGE "diskmanager" "4IceG/luci-app-mini-diskmanager" "main"
# UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
# UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
# UPDATE_PACKAGE "netspeedtest" "sirpdboy/netspeedtest" "main" "" "homebox ookla-speedtest"
# UPDATE_PACKAGE "netwizard" "sirpdboy/luci-app-netwizard" "main"
# UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
# UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
# UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
# UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
# UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
# UPDATE_PACKAGE "timecontrol" "sirpdboy/luci-app-timecontrol" "main"
# UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "gecoosac luci-app-timewol luci-app-wolplus"
# UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"


# -----------------------------------------------------------------
# UPDATE_VERSION 函数定义 (自动获取并同步最新底层内核版本号)
# -----------------------------------------------------------------
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

# -----------------------------------------------------------------
# 4. 强制同步最新双擎内核版本
# -----------------------------------------------------------------
UPDATE_VERSION "sing-box"
UPDATE_VERSION "xray-core"

#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
