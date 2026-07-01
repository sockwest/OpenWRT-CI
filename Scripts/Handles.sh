#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

# -----------------------------------------------------------------
# 1. 预置 HomeProxy 核心路由规则字典 (极速启动优化)
# -----------------------------------------------------------------
# 逻辑：在编译期提前拉取 Loyalsoldier 的最新 Surge 格式规则库 (包含 CN-IP, GFW 列表等)。
# 优势：刷机后 HomeProxy 无需在线更新规则即可瞬间启动，避免因刚刷完机网络环境不佳导致规则下载失败。
# 注意：这只是“数据字典”，绝对不会影响你在 UI 后台配置的“MAC 强扣”和“默认直连”逻辑。
if [ -d *"homeproxy"* ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	# 清空默认的旧规则，准备注入最新鲜的规则
	rm -rf ./$HP_PATH/resources/*

	# 从 GitHub 拉取最新规则库 (只拉取最近一次 commit 以加快打包速度)
	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	# 生成版本号标识文件，方便在路由器后台直观查看规则版本
	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	
	# 提取并转换 IP 与 域名 规则 (适配 HomeProxy 的读取格式)
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	
	# 将处理好的纯净版规则移动到 HomeProxy 准备打包的资源目录中
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	# 清理临时下载的规则源码，保持编译环境绝对整洁
	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy data has been successfully pre-loaded!"
fi

# -----------------------------------------------------------------
# 2. 插件菜单归类与体验优化
# -----------------------------------------------------------------

# [磁盘管理归类] 让后台菜单逻辑更符合直觉
# 逻辑：原版 mini-diskmanager 默认挂在“服务(Services)”菜单下。
# 调整：将其强行移动到“系统(System)”菜单下。后续你去挂载或格式化那 62G eMMC 空间时找起来会更顺手。
if [ -d *"luci-app-mini-diskmanager"* ]; then
	echo " " && cd ./luci-app-mini-diskmanager/

	sed -i "s/services/system/g" ./luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json

	cd $PKG_PATH && echo "mini-diskmanager has been fixed!"
fi



# -----------------------------------------------------------------
# 3. 核心底层依赖编译 Bug 修复 (防报错兜底)
# -----------------------------------------------------------------

# [TailScale 编译修复] 异地组网核心组件防错机制
# 逻辑：移除 Makefile 中的 /files 冲突声明，防止在云端 Actions 打包时因路径重叠导致整个固件编译失败。
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

# [Rust 环境修复] 现代高级网络插件的底层编译环境修复
# 逻辑：禁用强制使用 CI-LLVM。GitHub Actions 的云端环境经常因为 Rust 语言组件的版本跨度问题导致编译中断，关闭此项可大幅提升编译成功率。
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi
