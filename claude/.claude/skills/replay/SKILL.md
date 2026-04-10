---
name: replay
description: "Replay the last TTS message from the current session"
---

# TTS Replay

Replay the last spoken TTS message from the current Claude Code session.

## Instructions

Run:
```
python3 ~/workspace/ai/tts-daemon/tts_client.py replay
```

The client auto-detects the current session by finding the most recently modified JSONL file. This interrupts any currently playing audio and re-speaks the last message.

**CRITICAL: Do not output ANY text after running the command.** Any text response will be picked up by the TTS watcher and interfere with the replay. Only output text if the command returns an error.
