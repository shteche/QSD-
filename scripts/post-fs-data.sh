#!/system/bin/sh

MODPATH=/data/adb/modules/QSD++

for dir in system/lib/egl system/lib64/egl system/vendor/lib/egl system/vendor/lib64/egl; do
    mkdir -p "$MODPATH/$dir"
done

model=$(cat /sys/class/kgsl/kgsl-3d0/gpu_model 2>/dev/null || echo "unknown_gpu")
config="0 1 $model"
for cfg in system/lib/egl/egl.cfg system/lib64/egl/egl.cfg system/vendor/lib/egl/egl.cfg system/vendor/lib64/egl/egl.cfg; do
    echo "$config" > "$MODPATH/$cfg"
done

for blockdev in sda loop0 loop1 loop2 loop3 loop4 loop5 loop6 loop7 dm-0 mmcblk0 mmcblk0rpmb mmcblk1; do
    iostat_path="/sys/block/$blockdev/queue/iostats"
    [ -f "$iostat_path" ] && echo "0" > "$iostat_path"
done

[ -f /sys/module/kernel/parameters/initcall_debug ] && echo "N" > /sys/module/kernel/parameters/initcall_debug
[ -f /sys/module/printk/parameters/console_suspend ] && echo "0" > /sys/module/printk/parameters/console_suspend

if [ -f /sys/module/tcp_bbr/parameters/tcp_congestion_control ]; then
    echo "bbr" > /sys/module/tcp_bbr/parameters/tcp_congestion_control
else
    setprop net.tcp.default_congestion_control bbr
fi

set_properties="
ro.hwui.render_ahead=true
ro.ui.pipeline=skiaglthreaded
persist.sys.egl.swapinterval=1
ro.vendor.perf.scroll_opt=true
persist.sys.purgeable_assets=1
dalvik.vm.execution-mode=int:jit
vendor.perf.framepacing.enable=1
dalvik.vm.dex2oat-filter=everything
persist.sys.debug.gr.swapinterval=1
ro.hwui.hardware.skiaglthreaded=true
persist.sys.dalvik.hyperthreading=true
dalvik.vm.image-dex2oat-filter=everything
persist.sys.perf.topAppRenderThreadBoost.enable=true
"

reset_properties="
sys.use_fifo_ui=1
ro.min_pointer_dur=8
ro.iorapd.enable=false
ro.min.fling_velocity=8000
persist.sys.lgospd.enable=0
persist.sys.pcsync.enable=0
persist.sys.scrollingcache=2
persist.sys.perf.debug=false
ro.max.fling_velocity=20000
windowsmgr.max_event_per_sec=200
ro.surface_flinger.protected_contents=true
persist.vendor.verbose_logging_enabled=false
ro.surface_flinger.has_wide_color_display=true
ro.surface_flinger.use_color_management=true
persist.sys.turbosched.enable.coreApp.optimizer=true
persist.device_config.runtime_native_boot.iorap_perfetto_enable=false
persist.device_config.runtime_native_boot.iorap_readahead_enable=false
"

echo "$set_properties" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    prop_name=${line%%=*}
    prop_value=${line#*=}
    setprop "$prop_name" "$prop_value"
done

echo "$reset_properties" | while IFS= read -r line; do
    [ -z "$line" ] && continue
    prop_name=${line%%=*}
    prop_value=${line#*=}
    resetprop -n "$prop_name" "$prop_value"
done
