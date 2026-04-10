#!/bin/bash

read -r gpu_usage temp power name <<< $(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,power.draw,name --format=csv,noheader,nounits | tr ',' ' ')

tooltip="GPU: ${name}\nUsage: ${gpu_usage}%\nTemp: ${temp}°C\nPower: ${power}W"

echo "{\"text\": \"GPU ${gpu_usage}%\", \"tooltip\": \"${tooltip}\"}"
