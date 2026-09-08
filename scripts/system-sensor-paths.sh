#!/usr/bin/env bash
set -euo pipefail

cpu_temperature_path=''
gpu_temperature_path=''
gpu_load_path=''

for sensor_name_file in /sys/class/hwmon/hwmon*/name; do
    [[ -r $sensor_name_file ]] || continue
    sensor_name=''
    IFS= read -r sensor_name < "$sensor_name_file" || true
    sensor_dir=${sensor_name_file%/name}

    case $sensor_name in
        k10temp|coretemp|zenpower)
            if [[ -z $cpu_temperature_path && -r $sensor_dir/temp1_input ]]; then
                cpu_temperature_path=$sensor_dir/temp1_input
            fi
            ;;
        amdgpu|nouveau|nvidia)
            if [[ -z $gpu_temperature_path && -r $sensor_dir/temp1_input ]]; then
                gpu_temperature_path=$sensor_dir/temp1_input
            fi
            if [[ -z $gpu_load_path && -r $sensor_dir/device/gpu_busy_percent ]]; then
                gpu_load_path=$sensor_dir/device/gpu_busy_percent
            fi
            ;;
    esac
done

printf 'CPU_TEMP_PATH=%s\n' "$cpu_temperature_path"
printf 'GPU_TEMP_PATH=%s\n' "$gpu_temperature_path"
printf 'GPU_LOAD_PATH=%s\n' "$gpu_load_path"
