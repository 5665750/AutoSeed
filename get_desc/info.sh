#!/bin/bash
# FileName: get_desc/info.sh
#
# Author: rachpt@126.com
# Version: 3.0v
# Date: 2018-12-11
#
#-------------------------------------#
# 复制 nfo 文件内容至简介，如果没有 nfo 文件，
# 则采用 mediainfo 生成主文件的编码信息至临时文件。
# 自动判断 是否有 nfo 文件，以及 nfo 文件是否下载完成。
#-------------------------------------#

# 读取主文件以获得info，提前生成简介将失效
generate_info_local() {
  # 本地简介大小为零
  if [ ! -s "$source_desc" ]; then
    # 种子文件绝对路径
    debug_func 'info_0:media'  #----debug---
    local main_file_dir="${one_TR_Dir}/${one_TR_Name}"
    # 使用 mediainfo 生成种子中体积最大文件的 iNFO
    local info_generated="$($mediainfo "$(find "$main_file_dir" \
      -type f -exec stat -c "%s %n" {} \;|sort -nr|head -1)"| \
      sed '/Unique/d;/Encoding settings/d;/Complete name/d;/Writing library/d;/Writing application/d')"
    # 存档
    if [ "$info_generated" ]; then
      echo "$info_generated" > "$source_desc"
      debug_func 'info_1:media'  #----debug---
    fi
  fi
}

# 首先判断是否有 nfo 文件，以及nfo是否下载完成
read_info_file() {
  if [ ! "$one_TR_Dir" ]; then
      one_TR_Dir="$(find "$default_FILE_PATH" -name \
          "$one_TR_Name" 2> /dev/null|head -1)"
      one_TR_Dir="${one_TR_Dir%/*}"
  fi
  debug_func 'info_2'  #----debug---

  if [ "$one_TR_Dir" ]; then
    local nfo_file_size=$("$tr_show" "$torrent_Path"| \
      grep -Eo '\.nfo \([0-9\. ]+[kKbB]+\)'|grep -Eo '[0-9]+\.?[0-9]*')
      if [[ $nfo_file_size ]]; then
        local nfo_file_path="$(find "${one_TR_Dir}/${one_TR_Name}" -iname '*.nfo'|head -1)"
        local nfo_file_downloaded=$(stat --format=%s "$nfo_file_path")
      if [[ $nfo_file_downloaded ]]; then
        local judge_download_nfo=$((nfo_file_downloaded/100))
        local judge_nfo_file=$(echo "$nfo_file_size * 10"|bc|awk -F '.' '{print $1}')
        if [ "$judge_download_nfo" -eq  "$judge_nfo_file" ]; then
          local charset="$(file -i "$nfo_file_path"|sed 's/.*charset=//')" 
          [[ ! $charset ]] && charset='iso-8859-1'
          iconv -f "$charset" -t UTF-8 -c "$nfo_file_path"| \
            sed -E "/^ú+$/d" > "$source_desc"
          debug_func 'info_3:nfo'  #----debug---
        fi
      unset charset 
      fi
    else
        generate_info_local
        debug_func 'info_4:media'  #----debug---
    fi
    # byrbt bbcode to html
    [ "$enable_byrbt" = 'yes' ] && [ -s "$source_desc" ] && \
        sed 's/ /&nbsp; /g;s!$!&<br />!g' "$source_desc" > "$source_html" 
    debug_func 'info_5:exit'  #----debug---
  fi
}

#-------------------------------------#

