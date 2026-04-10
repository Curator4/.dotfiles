#!/bin/bash

read -r used total free <<< $(nvidia-smi --query-gpu=memory.used,memory.total,memory.free --format=csv,noheader,nounits | tr ',' ' ')

pct=$((used * 100 / total))

tooltip="VRAM Usage\nUsed: ${used} MiB\nFree: ${free} MiB\nTotal: ${total} MiB"

echo "{\"text\": \"VRAM ${pct}%\", \"tooltip\": \"${tooltip}\"}"
