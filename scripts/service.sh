#!/system/bin/sh

log() {
    echo "[QSD++] $1"
}

write_file() {
    local file="$1"
    local value="$2"
    if [ -w "$file" ] || chmod 644 "$file" 2>/dev/null; then
        echo "$value" > "$file" 2>/dev/null && chmod 444 "$file" 2>/dev/null
    else
        log "无法写入文件 $file"
    fi
}

detect_root() {
    ROOT_METHOD="Unknown"
    ROOT_VERSION="Unknown"

    if [ -d "/data/adb/ksu" ]; then
        ROOT_METHOD="KernelSU"
        if command -v su &>/dev/null; then
            ROOT_VERSION=$(su --version 2>/dev/null | cut -d ':' -f 1)
        fi
    elif [ -d "/data/adb/magisk" ]; then
        ROOT_METHOD="Magisk"
        if command -v magisk &>/dev/null; then
            ROOT_VERSION=$(magisk -V)
        fi
    elif [ -d "/data/adb/ap" ]; then
        ROOT_METHOD="APatch"
        if [ -f "/data/adb/ap/version" ]; then
            ROOT_VERSION=$(cat /data/adb/ap/version)
        fi
    fi
    log "Root检测: $ROOT_METHOD ($ROOT_VERSION)"
}

update_module_description() {
    local moddir="/data/adb/modules/QSD++"
    local prop="$moddir/module.prop"
    local backup="$prop.orig"

    BOARD_PLATFORM=$(getprop ro.board.platform | tr '[:lower:]' '[:upper:]')

    [ -f "$prop" ] && [ ! -f "$backup" ] && cp "$prop" "$backup"
    if [ -f "$prop" ]; then
        sed -i "s/^description=.*/description=[ QSD++ on ${BOARD_PLATFORM} | ${ROOT_METHOD} (${ROOT_VERSION}) ] Snapdragon performance module!/" "$prop"
        log "更新模块描述信息"
    fi
}

wait_for_boot_complete() {
    until [ "$(getprop sys.boot_completed)" = "1" ]; do
        sleep 5
    done
    log "系统启动完成"
}

tune_cpu_freq() {
    for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
        local freq_path="$cpu_dir/cpufreq"
        [ -d "$freq_path" ] || continue

        write_file "$freq_path/scaling_governor" "performance"

        if [ -f "$freq_path/cpuinfo_max_freq" ]; then
            local maxfreq=$(cat "$freq_path/cpuinfo_max_freq")
            for freq_file in scaling_max_freq scaling_min_freq; do
                local target="$freq_path/$freq_file"
                [ -f "$target" ] && write_file "$target" "$maxfreq"
            done
        fi
    done
    log "CPU频率调优完成"
}

tune_gpu() {
    local gpu_dir="/sys/class/kgsl/kgsl-3d0"
    [ -d "$gpu_dir" ] || return

    local devfreq="$gpu_dir/devfreq"
    [ -d "$devfreq" ] || return

    write_file "$devfreq/governor" "msm-adreno-tz"

    if [ -f "$devfreq/available_frequencies" ]; then
        local maxfreq=$(cat "$devfreq/available_frequencies" | tr ' ' '\n' | sort -nr | head -n1)
        for freq_file in min_freq max_freq; do
            local target="$devfreq/$freq_file"
            [ -f "$target" ] && write_file "$target" "$maxfreq"
        done
    fi

    for param in adrenoboost throttling bus_split force_clk_on force_bus_on force_rail_on force_no_nap idle_timer max_pwrlevel snapshot/dump snapshot/snapshot_crashdumper; do
        local target="$gpu_dir/$param"
        [ -e "$target" ] || continue
        case "$param" in
            adrenoboost) write_file "$target" "3" ;;
            throttling|bus_split|max_pwrlevel|snapshot/dump|snapshot/snapshot_crashdumper) write_file "$target" "0" ;;
            force_clk_on|force_bus_on|force_rail_on|force_no_nap) write_file "$target" "1" ;;
            idle_timer) write_file "$target" "100000000" ;;
        esac
    done

    log "GPU调优完成"
}

tune_devfreq() {
    local paths=(
        /sys/class/devfreq/*cpu*-lat
        /sys/class/devfreq/*cpu*-bw
        /sys/class/devfreq/*llccbw*
        /sys/class/devfreq/*bus_llcc*
        /sys/class/devfreq/*bus_ddr*
        /sys/class/devfreq/*l3-*
        /sys/class/devfreq/*memlat*
        /sys/class/devfreq/*cpubw*
        /sys/class/devfreq/*gpubw*
        /sys/class/devfreq/*kgsl-ddr-qos*
    )

    for path in "${paths[@]}"; do
        [ -d "$path" ] || continue
        if [ -f "$path/available_frequencies" ]; then
            local maxfreq=$(cat "$path/available_frequencies" | tr ' ' '\n' | sort -nr | head -n1)
            [ -n "$maxfreq" ] && write_file "$path/max_freq" "$maxfreq"
            [ -n "$maxfreq" ] && write_file "$path/min_freq" "$maxfreq"
        fi
    done

    log "设备频率调节完成"
}

tune_storage() {
    for storek in /sys/class/devfreq/*.ufshc /sys/class/devfreq/mmc*; do
        [ -d "$storek" ] || continue
        if [ -f "$storek/available_frequencies" ]; then
            local maxfreq=$(cat "$storek/available_frequencies" | tr ' ' '\n' | sort -nr | head -n1)
            [ -n "$maxfreq" ] && write_file "$storek/max_freq" "$maxfreq"
            [ -n "$maxfreq" ] && write_file "$storek/min_freq" "$maxfreq"
        fi
    done

    for block in /sys/block/*; do
        local queue="$block/queue"
        [ -d "$queue" ] || continue

        if [ -f "$queue/scheduler" ]; then
            local sched=$(cat "$queue/scheduler")
            for algo in cfq noop kyber bfq mq-deadline none; do
                if echo "$sched" | grep -woq "$algo"; then
                    write_file "$queue/scheduler" "$algo"
                    break
                fi
            done
        fi

        for param in add_random iostats read_ahead_kb nr_requests; do
            local target="$queue/$param"
            [ -f "$target" ] || continue
            case "$param" in
                add_random|iostats) write_file "$target" "0" ;;
                read_ahead_kb) write_file "$target" "32" ;;
                nr_requests) write_file "$target" "64" ;;
            esac
        done
    done

    log "存储和缓存优化完成"
}

disable_throttling() {
    find /sys/ -type f -name "*throttling*" | while read -r file; do
        [ -w "$file" ] && write_file "$file" "0"
    done
    log "关闭节流完成"
}

enable_touch_boost() {
    local touch_paths=(
        /sys/module/msm_performance/parameters/touchboost
        /sys/power/pnpmgr/touch_boost
        /proc/perfmgr/tchbst/kernel/tb_enable
        /sys/devices/virtual/touch/touch_boost
        /sys/module/msm_perfmon/parameters/touch_boost_enable
        /sys/devices/platform/goodix_ts.0/switch_report_rate
    )

    for path in "${touch_paths[@]}"; do
        [ -f "$path" ] && write_file "$path" "1"
    done

    log "触摸boost已开启"
}

disable_logs() {
    for svc in logd traced statsd; do
        if pidof "$svc" >/dev/null 2>&1; then
            stop "$svc" 2>/dev/null
            log "已停止日志服务: $svc"
        fi
    done
}

tune_kernel_sched() {
    local sched_path="/proc/sys/kernel"
    write_file "$sched_path/sched_latency_ns" "20000000"
    write_file "$sched_path/sched_wakeup_granularity_ns" "1500000"
    write_file "$sched_path/sched_migration_cost_ns" "1000000"
    write_file "$sched_path/sched_nr_migrate" "32"
    write_file "$sched_path/sched_nr_migrate_cpus" "4"
    log "内核调度参数调整完成"
}

tune_kernel_panic_trace() {
    write_file "/proc/sys/kernel/panic" "10"
    write_file "/proc/sys/kernel/panic_on_oops" "1"
    write_file "/proc/sys/kernel/panic_on_warn" "1"
    write_file "/proc/sys/kernel/trace_enabled" "0"
    write_file "/proc/sys/kernel/trace_printk" "0"
    log "内核panic和trace参数调整完成"
}

tune_zram() {
    local zram_dev="/dev/block/zram0"
    local zram_sys="/sys/block/zram0"
    if [ -e "$zram_dev" ]; then
        swapoff "$zram_dev" 2>/dev/null
        echo 0 > "$zram_sys/reset"
        echo 1 > "$zram_sys/disksize"
        mkswap "$zram_dev"
        swapon -p 32767 "$zram_dev"
        log "ZRAM调整完成"
    fi
}

main() {
    wait_for_boot_complete
    detect_root
    update_module_description

    tune_cpu_freq
    tune_gpu
    tune_devfreq
    tune_storage
    disable_throttling
    enable_touch_boost
    disable_logs
    tune_kernel_sched
    tune_kernel_panic_trace
    tune_zram

    log "QSD性能调优完成"
}

main
