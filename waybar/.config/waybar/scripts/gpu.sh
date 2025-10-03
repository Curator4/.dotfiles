#!/bin/bash

gpu_usage=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)

echo "󰢮 ${gpu_usage}%"
