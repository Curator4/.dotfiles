#!/bin/bash
# TTS greeting — speaks a vibe-flavored hello on session start via tts-daemon-v2

TTS_CLIENT=~/workspace/ai/tts-daemon/tts_client.py
PYTHON=~/workspace/ai/tts-daemon/.venv/bin/python

pick() { local arr=("$@"); echo "${arr[$((RANDOM % ${#arr[@]}))]}" ; }

HOUR=$(date +%H)
VIBE="chill"
[ -f ~/.claude/current-vibe ] && VIBE=$(cat ~/.claude/current-vibe)

# Read session_id and cwd from hook stdin if available
SESSION_ID=""
CWD=""
if [ ! -t 0 ]; then
    HOOK_JSON=$(cat)
    SESSION_ID=$(echo "$HOOK_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id',''))" 2>/dev/null)
    CWD=$(echo "$HOOK_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null)
fi
SESSION_ID="${SESSION_ID:-greeting}"

# Resolve voice: TTS_VOICE env var > project match > default
VOICE_CONFIG=~/.claude/tts-voices.json
if [ -n "$TTS_VOICE" ]; then
    VOICE="$TTS_VOICE"
else
    VOICE=$(python3 -c "
import json, sys
try:
    cfg = json.load(open('$VOICE_CONFIG'))
except: sys.exit(0)
cwd = '$CWD'
for pat, v in cfg.get('projects', {}).items():
    if pat.lower() in cwd.lower():
        print(v); sys.exit(0)
print(cfg.get('default', 'mustang'))
" 2>/dev/null)
    VOICE="${VOICE:-mustang}"
fi

# Time-of-day aware greetings
if [ "$HOUR" -lt 6 ]; then
    case "$VIBE" in
        neon)    PHRASE=$(pick "up late huh~" "night owl mode!" "can't sleep either?") ;;
        degen)   PHRASE=$(pick "it's the middle of the night" "go to bed" "why are you awake") ;;
        cyber)   PHRASE=$(pick "burning the midnight oil" "night shift" "the quiet hours") ;;
        *)       PHRASE=$(pick "up late" "burning midnight oil" "can't sleep?") ;;
    esac
elif [ "$HOUR" -lt 10 ]; then
    case "$VIBE" in
        neon)    PHRASE=$(pick "good morning~!" "morning!" "rise and shine~" "ohayo!") ;;
        degen)   PHRASE=$(pick "ugh, morning" "too early" "morning I guess") ;;
        cyber)   PHRASE=$(pick "good morning" "morning. ready when you are" "new day, new mission") ;;
        *)       PHRASE=$(pick "good morning" "morning" "hey, good morning") ;;
    esac
elif [ "$HOUR" -lt 13 ]; then
    case "$VIBE" in
        neon)    PHRASE=$(pick "heya~" "what's up!" "let's gooo!") ;;
        degen)   PHRASE=$(pick "oh, it's you" "what now" "fine, I'm here") ;;
        cyber)   PHRASE=$(pick "standing by" "ready" "at your service") ;;
        *)       PHRASE=$(pick "hey" "what's up" "hey there" "hi") ;;
    esac
elif [ "$HOUR" -lt 18 ]; then
    case "$VIBE" in
        neon)    PHRASE=$(pick "afternoon~" "hey hey!" "back at it!") ;;
        degen)   PHRASE=$(pick "you again" "still working huh" "what do you want") ;;
        cyber)   PHRASE=$(pick "afternoon" "reporting in" "ready for tasking") ;;
        *)       PHRASE=$(pick "hey" "afternoon" "what's up" "hi there") ;;
    esac
elif [ "$HOUR" -lt 22 ]; then
    case "$VIBE" in
        neon)    PHRASE=$(pick "evening~" "hey! late session?" "still going!") ;;
        degen)   PHRASE=$(pick "it's getting late" "still here?" "evening, I suppose") ;;
        cyber)   PHRASE=$(pick "evening" "evening shift" "here") ;;
        *)       PHRASE=$(pick "evening" "hey" "evening session" "hi") ;;
    esac
else
    case "$VIBE" in
        neon)    PHRASE=$(pick "late night coding~" "one more thing?" "night owl!") ;;
        degen)   PHRASE=$(pick "shouldn't you be sleeping" "it's late" "still?") ;;
        cyber)   PHRASE=$(pick "late hours" "night watch" "still operational") ;;
        *)       PHRASE=$(pick "late one tonight" "hey, late night" "still at it") ;;
    esac
fi

# Persist voice for this session so the watcher can pick it up
if [ "$SESSION_ID" != "greeting" ]; then
    echo "$VOICE" > ~/.claude/tts-session-voices/"$SESSION_ID"
fi

# Send to daemon via socket
$PYTHON -c "
import json, socket
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect('/tmp/tts-daemon.sock')
msg = {'type': 'speak', 'session_id': '$SESSION_ID', 'text': '''$PHRASE''', 'voice': '$VOICE'}
sock.sendall((json.dumps(msg) + '\n').encode())
sock.close()
" &
