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

# 调用示例
# UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "master" "" "custom_name1 custom_name2"
# UPDATE_PACKAGE "open-app-filter" "destan19/OpenAppFilter" "master" "" "luci-app-appfilter oaf" 这样会把原有的open-app-filter，luci-app-appfilter，oaf相关组件删除，不会出现coremark错误。

# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"


# -----------------------------------------------------------------
# 1. 核心主题与 UI 组件 (全部开启，方便对比测试后筛选)
# -----------------------------------------------------------------
# 【现代化主题】目前最主流、最稳定的高颜值主题
# UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"
# 【扁平化极简主题】基于 shadcn UI 设计风格的轻量主题
UPDATE_PACKAGE "shadcn" "eamonxg/luci-theme-shadcn" "main"
# 【多彩动感主题】Aurora 主题及其控制面板，支持丰富的自定义设置
# UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
# UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"
# 【多功能动态主题】Kucat 主题及其控制面板，带有一些特效和高度自定义功能
# UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "master"
# UPDATE_PACKAGE "kucat-config" "sirpdboy/luci-app-kucat-config" "master"

# -----------------------------------------------------------------
# 2. 核心代理与分流网络组件 (业务架构的基石)
# -----------------------------------------------------------------
# 【主线代理】拥抱极其稳健的全能方案 (HomeProxy)。走 TUN 网卡模式，完全不依赖严苛的内核 eBPF 特性，100% 保证跨架构编译通过。
UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"

# 【异地组网】引入 Tailscale (基于 WireGuard 协议的虚拟局域网，实现跨地域设备无缝直连)
UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"

# -----------------------------------------------------------------
# 3. 实用工具包 (按需精简与核心能力补齐)
# -----------------------------------------------------------------
# 【恢复拉取】动态域名穿透：配合 IPv6 方便在外远程管理主路由后台
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"

# 【恢复拉取】轻量磁盘管理：直观查看和格式化雅典娜 62G eMMC 和外接 U 盘
UPDATE_PACKAGE "diskmanager" "4IceG/luci-app-mini-diskmanager" "main"

# 【DNS 分流与防污染】引入 MosDNS (强大的 DNS 转发器，智能处理国内外 DNS 解析，防止 DNS 泄漏)
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"

# 【恢复拉取】分区扩容：一键挂载雅典娜剩余的 60G+ eMMC 空间，激活存储中转站的前提
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"

# 【恢复拉取】极简文件快传：方便网页端跨设备临时拉取或上传工作物料
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"

# 【定时控制】引入时间控制插件 (可设置定时任务，或用来管控特定设备的连网时段)
UPDATE_PACKAGE "timecontrol" "sirpdboy/luci-app-timecontrol" "main"

# 【异地组网备用】引入 VNT (另一款轻量级虚拟局域网工具，可与 Tailscale 互为备用打通内外网)
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

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
# 4. 强制同步最新双擎内核版本 (双保险容灾引擎)
# -----------------------------------------------------------------
# 确保 HomeProxy 能随时调用最新版的底层二进制文件，应对特征码封锁
UPDATE_VERSION "sing-box"
UPDATE_VERSION "xray-core"

#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
