#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"



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
