#!/bin/bash
# FileName: qbittorrent.sh
#
# Author: rachpt@126.com
# Version: 3.0v
# Date: 2018-12-19
#
#--------------------------------------#
qb_login="${qb_HOST}:$qb_PORT/api/v2/auth/login"
qb_add="${qb_HOST}:$qb_PORT/api/v2/torrents/add"
qb_delete="${qb_HOST}:$qb_PORT/api/v2/torrents/delete"
qb_ratio="${qb_HOST}:$qb_PORT/api/v2/torrents/setShareLimits"
qb_lists="${qb_HOST}:$qb_PORT/api/v2/torrents/info"
qb_reans="${qb_HOST}:$qb_PORT/api/v2/torrents/reannounce"
#--------------------------------------#
qbit_webui_cookie() {
  if [ "$(http --ignore-stdin -b GET "${qb_HOST}:$qb_PORT" "$qb_Cookie"| \
    grep 'id="username"')" ]; then
    qb_Cookie="cookie:$(http --ignore-stdin -hf POST "$qb_login" \
        username="$qb_USER" password="$qb_PASSWORD"| \
        sed -En '/set-cookie:/{s/.*(SID=[^;]+).*/\1/i;p;q}')"
    # 更新 qb cookie
    if [ "$qb_Cookie" ]; then
      sed -i "s/^qb_Cookie=.*/qb_Cookie=\'$qb_Cookie\'/" "$ROOT_PATH/settings.sh" 
    else
      echo 'Failed to get qb cookie!' >> "$debug_Log"
    fi
    #----debug---
    debug_func 'qb:cookie'  #----debug---
  fi
}

#--------------------------------------#
qb_reannounce() {
    if [[ $qb_USER ]]; then
        qbit_webui_cookie
        http --ignore-stdin -f POST "$qb_reans" hashes=all "$qb_Cookie"
    fi
}
#--------------------------------------#
qb_delete_torrent() {
    qbit_webui_cookie
    # delete
    http --ignore-stdin -f POST "$qb_delete" hashes=$torrent_hash \
        deleteFiles=false "$qb_Cookie"
    debug_func 'qb:deleted'  #----debug---
}

#---------------------------------------#
# it's not use now
qb_set_ratio() {
  sleep 8
  qbit_webui_cookie
  # from tr name find other info
  debug_func 'qb_3:r-start'  #----debug---
  local data="$(http --ignore-stdin --pretty=format -f POST "$qb_lists" sort=added_on reverse=true \
    "$qb_Cookie"|sed -E '/^[ ]*[},]+$/d;s/^[ ]+//;s/[ ]+[{]+//;s/[},]+//g'| \
    grep -B18 -A19 'name":'|sed -Ee \
    '/"hash":/{s/"//g};/"name":/{s/"//g};/"tracker":/{s/"//g};'|sed '/"/d')" 
  # get current site
  echo "$data" > "$ROOT_PATH/tmp/`date '+%H-%M-%S'`.txt"
  for site in ${!post_site[*]}; do
    [ "$(echo "$postUrl"|grep "${post_site[$site]}")" ] && \
      add_site_tracker="${trackers[$site]}" && break # get out of for loop
  done
  debug_func "qb_3:rt-[$add_site_tracker]"   #----debug---

  while true; do
    # get torrent hash, match one!
    local pos=$(echo "$data"|sed -n "/name.*$org_tr_name/="|head -1)
    debug_func "qb_pos-[$pos]"   #----debug---
    [ ! "$pos" ] && break
    local torrent_hash="$(echo "$data"|head -n "$(expr $pos - 1)"|tail -1| \
        sed -E 's/hash:[ ]*//')"
    debug_func 'qb_hash-['"$torrent_hash"']'  #----debug---

    local tracker_one="$(echo "$data"|head -n "$(expr $pos + 1)"|tail -1| \
        sed -E 's/tracker:[ ]*//;s/passkey=.*//')"
    debug_func 'qb_tracker-['"$tracker_one"']'  #----debug---

    if [ "$(echo "$tracker_one"|grep "$add_site_tracker")" ];then
      if [ "${#torrent_hash}" -eq 40 ]; then
        # set ratio and say thanks
        debug_func 'qb_rt:success'  #----debug---
        [[ $ratio_set ]] && \
        http --ignore-stdin -f POST "$qb_ratio" hashes="$torrent_hash" \
        ratioLimit=$ratio_set seedingTimeLimit="$(echo \
        ${MAX_SEED_TIME}*60*60|bc)" "$qb_Cookie" && \
        [[ $Allow_Say_Thanks == yes ]] && \
        [[ "$(eval echo '$'"say_thanks_$site")" == yes ]] && \
        http --verify=no --ignore-stdin -f POST "${post_site[$site]}/thanks.php" \
        id="$t_id" "$(eval echo '$'"cookie_$tracker")" && break 
      else
        debug_func 'qb_torrent_hash wrong!'  #----debug---
      fi
    else
      # update data, delete the first name matched
      data="$(echo "$data"|sed "1,${pos}d")"
      debug_func 'qb_rt:rewrite'  #----debug---
    fi
  done
  unset site add_site_tracker data torrent_hash tracker_one
}
 
#---------------------------------------#
qb_set_ratio_queue() {
  for site in ${!post_site[*]}; do
    [ "$(echo "$postUrl"|grep "${post_site[$site]}")" ] && \
      add_site_tracker="${trackers[$site]}" && break # get out of for loop
  done

  echo -e "${org_tr_name}\n${add_site_tracker}\n${ratio_set}" >> "$qb_rt_queue"
  # say thanks 
  [[ $Allow_Say_Thanks == yes ]] && \
  [[ "$(eval echo '$'"say_thanks_$site")" == yes ]] && \
  http --verify=no -h --ignore-stdin -f POST "${post_site[$site]}/thanks.php" \
  id="$t_id" "$(eval echo '$'"cookie_$site")"
  unset site
}

#---------------------------------------#
qb_get_hash() {
  # $1 name; $2 tracker; return hash
  echo "$data"|sed -n "/name.*$1/="|while read pos; do
    local hash="$(echo "$data"|head -n "$(expr $pos - 1)"|tail -1| \
        sed -E 's/hash:[ ]*//')"
    local tr_one="$(echo "$data"|head -n "$(expr $pos + 1)"|tail -1| \
        sed -E 's/tracker:[ ]*//;s/passkey=.*//')"
    [ "$(echo "$tr_one"|grep "$2")" ] && echo "$hash" && break
  done
  unset pos hash tr_one
}

#---------------------------------------#
qb_set_ratio_loop() {
  if [ -s "$qb_rt_queue" ]; then
    sleep 20 # 延时
    qbit_webui_cookie
    local data="$(http --ignore-stdin --pretty=format -f POST "$qb_lists" sort=added_on reverse=true \
    "$qb_Cookie"|sed -E '/^[ ]*[},]+$/d;s/^[ ]+//;s/[ ]+[{]+//;s/[},]+//g'| \
    grep -B18 -A19 'name":'|sed -Ee \
    '/"hash":/{s/"//g};/"name":/{s/"//g};/"tracker":/{s/"//g};'|sed '/"/d')" 
    qb_lp_counter=0
    while true; do
      local name="$(head -1 "$qb_rt_queue")"           # line one
      [[ ! $name ]] && break                           # jump out
      [[ $qb_lp_counter -gt 50 ]] && break             # jump out
      local trker="$(head -2 "$qb_rt_queue"|tail -1)"  # line second
      local rtio="$(head -3 "$qb_rt_queue"|tail -1)"   # line third
      local hash="$(qb_get_hash "$name" "$trker")"     # get hash  
      # 设置qbit 做种时间以及做种分享率
      [ "${#hash}" -eq 40 ] && \
        http --ignore-stdin -f POST "$qb_ratio" hashes="$hash" \
         ratioLimit=$rtio seedingTimeLimit="$(echo \
         ${MAX_SEED_TIME} \* 60 \* 60|bc)" "$qb_Cookie" && sleep 1 && \
         debug_func "qb:sussess_set_rt[$trker]"      #----debug---
      sed -i '1,3d' "$qb_rt_queue"                     # delete record
      ((qb_lp_counter++))                              # C 形式的增1
    done
  fi
}
#---------------------------------------#
qb_add_torrent_url() {
  qbit_webui_cookie
  # add url
  http --ignore-stdin -f POST "$qb_add" urls="$torrent2add" root_folder=true \
      savepath="$one_TR_Dir" skip_checking=true "$qb_Cookie"
  sleep 1
  qb_set_ratio_queue
  #qb_set_ratio
  debug_func 'qb:addurl'  #----debug---
}
#---------------------------------------#
qb_add_torrent_file() {
  qbit_webui_cookie
  # add file
  http --ignore-stdin -f POST "$qb_add" skip_checking=true root_folder=true \
      name@"${ROOT_PATH}/tmp/${t_id}.torrent" savepath="$one_TR_Dir" "$qb_Cookie"
  #  ----> ok
  sleep 1
  qb_set_ratio_queue
  #qb_set_ratio
  debug_func 'qb:addfile'  #----debug---
}

#---------------------------------------#
# call in main.sh
qb_get_torrent_completion() {
  qbit_webui_cookie
  # need a parameter
  local data="$(http --ignore-stdin --pretty=format -f POST "$qb_lists" sort=added_on reverse=true \
    "$qb_Cookie"|sed -E '/^[ ]*[},]+$/d;s/^[ ]+//;s/[ ]+[{]+//;s/[},]+//g'| \
    grep -B17 -A15 'name":'|sed -E \
    '/"completed":/{s/"//g};/"name":/{s/"//g};/"save_path":/{s/"//g};/"size":/{s/"//g};'|sed '/"/d')" 
  # match one!
  local pos=$(echo "$data"|sed -n "/name.*$org_tr_name/="|tail -1)
  [[ $pos ]] && {
  local compl_one="$(echo "$data"|head -n $(expr $pos - 1)|tail -1|grep -Eo '[0-9]{4,}')"
  local size_one="$(echo "$data"|head -n $(expr $pos + 2)|tail -1|grep -Eo '[0-9]{4,}')"
  one_TR_Dir="$(echo "$data"|head -n $(expr $pos + 1)|tail -1|grep -o '/.*$')";
  }
  # return completed precent
  [[ $compl_one && $size_one ]] && \
  completion=$(awk -v a="$compl_one" -v b="$size_one" 'BEGIN{printf "%d",(a/b)*100}')
  unset data compl_one size_one pos
  debug_func 'qb:complete'  #----debug---
}
#---------------------------------------#

