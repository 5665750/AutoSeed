#!/bin/bash
# FileName: test.sh
#
# Author: rachpt@126.com
# Version: 3.0v
# Date: 2018-12-11
#
#--------------------------------------#
# 说明：该文件用于逐个测试站点情况，
# 仅用于 debug。
# 使用该测试文件的效果：
#   - 快速设置发布站点，
#   - 不会删除 tmp 中的简介文件，方便 debug，
#   - 不会删除已经发布的 .torrent 文件，
#   - 不会进入脚本超时控制模块，不会进入清理种子模块，
#   - 使用 test_func，会跳过种子下载完成检测(*)。
#--------------------------------------#
test_func() {
    test_func_probe=1
    #---[hudbt]---#
    enable_hudbt='yes'
    #---[whu]---#
    enable_whu='no'
    #---[npupt]---#
    enable_npupt='yes'
    #---[nanyangpt]---#
    enable_nanyangpt='yes'
    #---[byrbt]---#
    enable_byrbt='yes'
    #---[cmct]---#
    enable_cmct='yes'
    #---[tjupt]---#
    enable_tjupt='yes'
    #
}
#--------------------------------------#
#test_func  #--
#
# debug function
debug_func() {
    # set true to debug, false to close
    if false; then
        echo "[$(date '+%m-%d %H:%M:%S')]：$1" >> "$debug_Log"
    fi
}
