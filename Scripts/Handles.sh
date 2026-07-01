#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

# -----------------------------------------------------------------
# 1. 预置 HomeProxy 核心路由规则字典 (极速启动优化)
# -----------------------------------------------------------------
# 逻辑：在编译期提前拉取 Loyalsoldier 的最新 Surge 格式规则库 (包含 CN-IP, GFW 列表等)。
# 好处：刷机后 HomeProxy 无需在线更新规则即可瞬间启动，避免因网络问题导致规则下载失败。
# 注意：这只是“数据字典”，绝对不会影响你在 UI 后台配置的“MAC 强扣”和“默认直连”逻辑。
if [ -d *"homeproxy"* ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	# 清空默认的旧规则
	rm -rf ./$HP_PATH/resources/*

	# 拉取最新规则库
	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	# 生成版本号标识文件
	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	
	# 提取并转换 IP 与 域名 规则
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	
	# 将处理好的纯净版规则移动到 HomeProxy 资源目录中打包
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy data has been successfully pre-loaded!"
fi

# -----------------------------------------------------------------
# 2. UI 主题深度定制与修复
# -----------------------------------------------------------------

# [Argon 主题优化] 修改默认登录界面的主色调和毛玻璃透明度，使其更具高级感
if [ -d *"luci-theme-argon"* ]; then
	echo " " && cd ./luci-theme-argon/

	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

# [Aurora 主题优化] 将侧边栏菜单样式强制改为下拉式 (dropdown)，提升空间利用率
if [ -d *"luci-app-aurora-config"* ]; then
	echo " " && cd ./luci-app-aurora-config/

	sed -i "s/nav_type '.*'/nav_type 'dropdown'/g" $(find ./root/usr/share/aurora/ -type f -name "*.template")

	cd $PKG_PATH && echo "theme-aurora has been fixed!"
fi

# -----------------------------------------------------------------
# 3. 插件菜单归类与编译 Bug 修复
# -----------------------------------------------------------------

# [磁盘管理归类] 将 mini-diskmanager 从杂乱的 services 菜单移到更合理的 system 菜单下
if [ -d *"luci-app-mini-diskmanager"* ]; then
	echo " " && cd ./luci-app-mini-diskmanager/

	sed -i "s/services/system/g" ./luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json

	cd $PKG_PATH && echo "mini-diskmanager has been fixed!"
fi

# [TailScale 编译修复] 移除 Makefile 中的 /files 冲突声明，防止打包报错
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

# [Rust 环境修复] 禁用强制使用 CI-LLVM，解决 GitHub Actions 编译时 Rust 语言组件报错的隐患
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi
