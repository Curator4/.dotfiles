#!/bin/bash
# TTS finalize — sends finalize to tts-daemon on Stop
exec >> /tmp/tts-finalize.log 2>&1
echo "$(date): Stop hook fired"
STDIN=$(cat)
echo "$STDIN" | python3 -c "
import sys, json, hashlib
data = json.loads(sys.stdin.read())
msg = data.get('last_assistant_message','')
h = hashlib.md5(msg.encode()).hexdigest()
print(f'  last_assistant_message hash={h[:8]} len={len(msg)}')
print(f'  first 200 chars: {msg[:200]!r}')
" 2>&1
echo "$STDIN" | ~/workspace/ai/tts-daemon/.venv/bin/python ~/workspace/ai/tts-daemon/tts_client.py finalize
echo "$(date): finalize exit=$?"
