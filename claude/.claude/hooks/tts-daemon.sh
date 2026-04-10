#!/bin/bash
# Unified TTS daemon — systemd service
# Watches all JSONL files for new content and handles:
#   - Intermediate text (assistant text between tool calls)
#   - Tool announcements (vibe-flavored phrases for tool_use)
#   - Agent dispatch/return announcements
#   - Thinking lines (timed, when Claude is quiet for 30/60/90s)
#
# Queue model: everything queues. stfu / Stop sentinel drops the queue.
# Single process, no hooks needed except Stop for the final response.

STATE_DIR="/tmp/tts-daemon"
mkdir -p "$STATE_DIR"

STOP_SENTINEL="$STATE_DIR/stopped"
LAST_PLAY_FILE="$STATE_DIR/thinking-last-play"
AGENT_ACTIVE_FILE="$STATE_DIR/agent-active"
# Per-session thinking state: prompt-time-$JSID, thinking-stage-$JSID

cleanup() {
    rm -rf "$STATE_DIR"
    kill $(jobs -p) 2>/dev/null
    exit 0
}
trap cleanup EXIT INT TERM

stopped() { [ -f "$STOP_SENTINEL" ]; }

pick() { local arr=("$@"); echo "${arr[$((RANDOM % ${#arr[@]}))]}" ; }

tts_busy() {
    pgrep -f "python3 tts_hook.py" >/dev/null 2>&1 ||
    pgrep -f "python3 stream_tts.py" >/dev/null 2>&1 ||
    pgrep -f "python3 -c" >/dev/null 2>&1
}

wait_for_tts() {
    while tts_busy; do
        stopped && return 1
        sleep 0.3
    done
    return 0
}

speak_short() {
    local phrase="$1"
    cd ~/workspace/ai/qwen-tts
    source bin/activate
    PIPEWIRE_NODE=tts-voice python3 -c "
import os, signal, subprocess
from stream_tts import speak
from tts_hook import clean_for_speech

def kill_old():
    my = os.getpid()
    for pat in ['python3 tts_hook.py', 'python3 stream_tts.py', 'python3 -c']:
        try:
            r = subprocess.run(['pgrep', '-f', pat], capture_output=True, text=True)
            for p in r.stdout.strip().split('\n'):
                if p and int(p) != my:
                    os.kill(int(p), signal.SIGKILL)
        except (ProcessLookupError, ValueError):
            pass

speak(clean_for_speech('''$phrase'''), pre_play=kill_old)
" &
}

speak_long() {
    local text="$1"
    cd ~/workspace/ai/qwen-tts
    source bin/activate
    printf '%s\n' "$text" | PIPEWIRE_NODE=tts-voice python3 tts_hook.py &
}

get_vibe() {
    local vibe="chill"
    [ -f ~/.claude/current-vibe ] && vibe=$(cat ~/.claude/current-vibe)
    echo "$vibe"
}

# ─── Greeting Logic ────────────────────────────────────────────────

resolve_greeting() {
    local vibe
    vibe=$(get_vibe)

    case "$vibe" in
        neon)    pick "hey hey~" "hiii!" "oh, you're here!" "what's up!" "heya~" ;;
        degen)   pick "oh, it's you" "what do you want" "ugh, hi" "you again" "fine, I'm here" ;;
        chill)   pick "hey" "what's up" "hey there" "yo" "hi" ;;
        bright)  pick "hi there!" "hey!" "good to see you!" "hello!" "ready when you are!" ;;
        morose)  pick "hey" "I'm here" "hi" "oh. hello" "you came back" ;;
        cyber)   pick "ready" "standing by" "at your service" "here" "awaiting orders" ;;
        shadow)  pick "I've been expecting you" "greetings" "the shadows stir" "you've arrived" "welcome back" ;;
        dommy)   pick "you may begin" "I'm listening" "speak" "go ahead" "present your request" ;;
        blitz)   pick "go" "ready" "what's the task" "let's move" "hey, quick" ;;
        arcane)  pick "the stars align" "I sense your presence" "greetings, seeker" "the veil parts" "you've returned" ;;
        valor)   pick "ready for duty" "standing by" "at your command" "reporting in" "let's begin" ;;
        *)       pick "hey" "hi" "hello" "ready" ;;
    esac
}

# ─── Tool Announcement Logic ───────────────────────────────────────

resolve_tool_phrase() {
    local tool_name="$1"
    local tool_input="$2"
    local vibe
    vibe=$(get_vibe)

    # Agent tool
    if [ "$tool_name" = "Agent" ]; then
        local agent_desc
        agent_desc=$(echo "$tool_input" | jq -r '.description // empty' 2>/dev/null)
        touch "$AGENT_ACTIVE_FILE"

        if [ -n "$agent_desc" ]; then
            case "$vibe" in
                neon)    pick "sending a research agent to $agent_desc~" "dispatching someone to $agent_desc!" "launching an agent to $agent_desc~" ;;
                degen)   pick "sending someone more useful to $agent_desc" "delegating $agent_desc to someone competent" ;;
                chill)   pick "sending an agent to $agent_desc" "getting some help with $agent_desc" "delegating $agent_desc" ;;
                bright)  pick "launching a helper to $agent_desc!" "sending someone to $agent_desc!" ;;
                cyber)   pick "dispatching agent to $agent_desc" "deploying research unit for $agent_desc" ;;
                shadow)  pick "sending an acolyte to $agent_desc" "dispatching someone to $agent_desc" ;;
                dommy)   pick "assigning someone to $agent_desc" "dispatching an agent for $agent_desc" ;;
                blitz)   pick "agent on $agent_desc, go" "dispatching for $agent_desc" ;;
                arcane)  pick "conjuring an agent to $agent_desc" "summoning aid for $agent_desc" ;;
                valor)   pick "dispatching an ally to $agent_desc" "sending aid for $agent_desc" ;;
                morose)  pick "sending someone to $agent_desc" "delegating $agent_desc, maybe they'll manage" ;;
                *)       pick "sending an agent to $agent_desc" "dispatching help for $agent_desc" ;;
            esac
        else
            local vibe_announce="$HOME/.claude/vibes/$vibe/announcements.sh"
            if [ -f "$vibe_announce" ]; then
                source "$vibe_announce" Agent
            else
                pick "launching an agent" "spinning up an agent"
            fi
        fi
        return
    fi

    # Skip non-agent tools while agent is running
    [ -f "$AGENT_ACTIVE_FILE" ] && return

    # MCP tools
    case "$tool_name" in
        mcp__weather__*)          pick "checking the weather" "looking at the forecast" ;;
        mcp__themis__*)           pick "checking themis" "looking at themis" ;;
        mcp__*[Aa]tlassian*)      pick "talking to atlassian" "checking jira" ;;
        mcp__*Gmail*)             pick "checking email" "peeking at gmail" ;;
        mcp__*Calendar*)          pick "checking calendar" "looking at the schedule" ;;
        *)
            # Memory writes — detect Edit/Write targeting memory directories
            local file_path
            file_path=$(echo "$tool_input" | jq -r '.file_path // empty' 2>/dev/null)
            if [ -n "$file_path" ] && { [[ "$file_path" == */memory/* ]] || [[ "$file_path" == */agent-memory/* ]]; }; then
                case "$tool_name" in
                    Edit|Write)
                        case "$vibe" in
                            neon)    pick "writing to memory~" "saving that to memory!" "memorizing~" ;;
                            degen)   pick "writing to memory" "saving to memory, I guess" "memorizing that" ;;
                            chill)   pick "writing to memory" "saving to memory" "updating memory" ;;
                            bright)  pick "saving to memory!" "writing to memory!" "memorizing!" ;;
                            cyber)   pick "writing to memory" "memory updated" "storing to memory" ;;
                            shadow)  pick "committing to memory" "the memory stirs" "inscribing to memory" ;;
                            dommy)   pick "writing to memory" "memorizing" "noted, in memory" ;;
                            blitz)   pick "memory write" "saving" "memorizing" ;;
                            arcane)  pick "inscribing to memory" "the memory deepens" "recording" ;;
                            valor)   pick "writing to memory" "recording to memory" "memorizing" ;;
                            morose)  pick "writing to memory" "saving to memory" "remembering, for what it's worth" ;;
                            *)       pick "writing to memory" "saving to memory" ;;
                        esac
                        return ;;
                    Read)
                        case "$vibe" in
                            neon)    pick "recalling a memory~" "checking memory!" "remembering~" ;;
                            degen)   pick "checking memory" "recalling something" "let me remember" ;;
                            chill)   pick "recalling a memory" "checking memory" "remembering" ;;
                            bright)  pick "recalling a memory!" "checking memory!" ;;
                            cyber)   pick "accessing memory" "memory recall" ;;
                            shadow)  pick "consulting memory" "the memory speaks" ;;
                            dommy)   pick "recalling" "consulting memory" ;;
                            blitz)   pick "memory check" "recalling" ;;
                            arcane)  pick "consulting the memory" "the past reveals itself" ;;
                            valor)   pick "recalling from memory" "consulting memory" ;;
                            morose)  pick "remembering" "recalling" ;;
                            *)       pick "recalling a memory" "checking memory" ;;
                        esac
                        return ;;
                esac
            fi

            # Standard tools — use vibe announcements
            # Special command detection — checked before vibe fallback
            local special_phrase=""
            case "$tool_name" in
                Bash)
                    local bash_cmd
                    bash_cmd=$(echo "$tool_input" | jq -r '.command // empty' 2>/dev/null)
                    case "$bash_cmd" in
                        *"go test"*|*"make test"*)  special_phrase=$(pick "testing" "running tests" "let's see") ;;
                        *"make lint"*|*golangci-lint*) special_phrase=$(pick "linting" "running the linter" "checking style") ;;
                        *"go build"*|*"make build"*) special_phrase=$(pick "building" "compiling" "running the build") ;;
                        *sqlc\ *|*"make sqlc"*)     special_phrase=$(pick "generating sql" "running sqlc" "generating queries") ;;
                        *goose\ *)                  special_phrase=$(pick "running migrations" "migrating" "database migration") ;;
                        git\ *|gh\ *)               special_phrase=$(pick "git" "version control" "doing some git") ;;
                        rm\ *|*"rm -"*)             special_phrase=$(pick "removing files" "cleaning up" "deleting") ;;
                        *python3\ *|*python\ *)     special_phrase=$(pick "running python" "python script" "executing python") ;;
                        *npm\ *|*yarn\ *|*pnpm\ *)  special_phrase=$(pick "running node" "package manager" "node stuff") ;;
                        *docker\ *|*podman\ *)      special_phrase=$(pick "docker" "containers" "running docker") ;;
                        *curl\ *|*wget\ *)          special_phrase=$(pick "fetching" "making a request" "hitting an endpoint") ;;
                        *make\ *)                   special_phrase=$(pick "running make" "make target" "building") ;;
                        *sudo\ *)                   special_phrase=$(pick "running with sudo" "elevated command" "sudo time") ;;
                    esac ;;
                Skill)
                    local skill_name
                    skill_name=$(echo "$tool_input" | jq -r '.skill // empty' 2>/dev/null)
                    case "$skill_name" in
                        backlog) special_phrase=$(pick "checking the backlog" "looking at the backlog") ;;
                        themis)  special_phrase=$(pick "logging to themis" "writing the log") ;;
                        commit)  special_phrase=$(pick "committing" "making a commit") ;;
                    esac ;;
            esac

            if [ -n "$special_phrase" ]; then
                echo "$special_phrase"
            else
                local vibe_announce="$HOME/.claude/vibes/$vibe/announcements.sh"
                if [ -f "$vibe_announce" ]; then
                    source "$vibe_announce" "$tool_name"
                else
                    case "$tool_name" in
                        WebSearch) echo "searching the web" ;;
                        Read)      echo "reading a file" ;;
                        Edit)      echo "editing" ;;
                        Write)     echo "writing a file" ;;
                        Grep)      echo "searching the code" ;;
                        Glob)      echo "looking for files" ;;
                        Bash)      echo "running a command" ;;
                        Skill)     echo "using a skill" ;;
                        *)         ;; # no announcement
                    esac
                fi
            fi
            ;;
    esac
}

resolve_agent_return_phrase() {
    local vibe
    vibe=$(get_vibe)
    rm -f "$AGENT_ACTIVE_FILE"

    case "$vibe" in
        neon)    pick "they're back~" "agent's done!" "got it~" ;;
        degen)   pick "finally." "they're done. took long enough." "back. whatever." ;;
        chill)   pick "agent's back." "done." "got the results." ;;
        bright)  pick "agent's back!" "results are in!" "all done!" ;;
        morose)  pick "they returned." "it's done." "back. for what it's worth." ;;
        cyber)   pick "agent returned." "results in." "task complete." ;;
        shadow)  pick "the acolyte returns." "it is done." "they emerge from the dark." ;;
        dommy)   pick "they're done." "back, as expected." "report received." ;;
        blitz)   pick "done." "back. moving on." "results, let's go." ;;
        arcane)  pick "the servant returns." "it is revealed." "the answer emerges." ;;
        valor)   pick "ally returned." "report in." "task fulfilled." ;;
        *)       pick "agent finished." "done." "results are in." ;;
    esac
}

# ─── Thinking Line Logic ───────────────────────────────────────────

get_thinking_line() {
    local stage="$1"
    local vibe
    vibe=$(get_vibe)

    case "$stage" in
        1)
            case "$vibe" in
                neon)    pick "thinking~" "hmm let me think!" "processing!" "one sec~" "brain is braining!" ;;
                degen)   pick "thinking, hold on" "wait, idiot" "give me a sec, loser" "processing, don't be needy" ;;
                chill)   pick "thinking..." "working on it" "give me a sec" "hmm let me think" "one moment" ;;
                bright)  pick "thinking!" "working on it!" "one moment!" "let me figure this out!" ;;
                morose)  pick "thinking" "processing" "working on it i guess" "let me think" ;;
                dommy)   pick "thinking" "patience" "wait" "let me consider" ;;
                shadow)  pick "contemplating" "thinking" "considering" "turning this over" ;;
                blitz)   pick "thinking" "processing" "sec" "hold on" ;;
                arcane)  pick "contemplating" "the threads are being woven" "seeking clarity" ;;
                valor)   pick "thinking" "considering" "deliberating" "gathering my thoughts" ;;
                cyber)   pick "thinking" "working on it" "processing" "let me think" ;;
                *)       pick "thinking" "working on it" "processing" "one moment" ;;
            esac ;;
        2)
            case "$vibe" in
                neon)    pick "still thinking~" "this is a big one!" "bear with me!" "deeper than I thought~" ;;
                degen)   pick "still thinking, relax" "don't rush me" "I said hold on" "this isn't easy" ;;
                chill)   pick "still thinking..." "taking a bit longer" "still on it" "this one needs more thought" ;;
                bright)  pick "still working on it!" "this one's tricky!" "hang in there!" "getting closer!" ;;
                morose)  pick "still thinking" "this is taking a while" "still here" "not done yet" ;;
                dommy)   pick "still working" "be patient" "I said wait" "complex matters take time" ;;
                shadow)  pick "still deliberating" "the answer requires depth" "patience" "deeper study is needed" ;;
                blitz)   pick "still going" "complex one" "working" "need more time" ;;
                arcane)  pick "the depths are deeper than expected" "still seeking" "the veil is thick" ;;
                valor)   pick "still deliberating" "this demands careful thought" "endure" "steady" ;;
                cyber)   pick "still working on it" "this needs more thought" "bear with me" ;;
                *)       pick "still thinking" "still working on it" "bear with me" ;;
            esac ;;
        3)
            case "$vibe" in
                neon)    pick "okay this is taking a while~" "big brain time!" "sorry for the wait!" ;;
                degen)   pick "this is taking forever, I know" "blame the problem not me" "ugh this is complex" ;;
                chill)   pick "this is taking a while..." "sorry, complex one" "still here, still thinking" ;;
                bright)  pick "wow this is a big one!" "still at it, don't worry!" "almost there I think!" ;;
                morose)  pick "this is taking a while" "the answer doesn't want to be found" "still working" ;;
                dommy)   pick "this requires more time" "do not rush me" "the answer will come when it is ready" ;;
                shadow)  pick "the answer does not yield easily" "some knowledge takes time" "perseverance" ;;
                blitz)   pick "this one is actually complex" "still on it" "taking longer than expected" ;;
                arcane)  pick "the mysteries do not reveal themselves quickly" "still divining" "nearly there" ;;
                valor)   pick "some battles are not won quickly" "perseverance" "hold the line" ;;
                cyber)   pick "this is taking longer than expected" "complex problem" "almost there" ;;
                *)       pick "this is taking a while" "still working" "almost there" ;;
            esac ;;
    esac
}

# ─── Thinking Timer (background) ──────────────────────────────────

thinking_timer() {
    while true; do
        sleep 5
        [ -f ~/.claude/tts-enabled ] || continue
        stopped && continue
        tts_busy && continue

        # Check all per-session prompt files
        local fired=0
        for pt_file in "$STATE_DIR"/prompt-time-*; do
            [ -f "$pt_file" ] || continue

            local jsid prompt_time now elapsed stage_file current_stage last_play since_last stage
            jsid="${pt_file##*prompt-time-}"
            prompt_time=$(cat "$pt_file")
            now=$(date +%s)
            elapsed=$((now - prompt_time))

            # Verify the session JSONL exists and the turn is still open
            # (last line should be "user" type — if it's "assistant" or "last-prompt",
            # the turn already completed and we shouldn't fire thinking lines)
            local jsonl_path
            jsonl_path=$(find "$HOME/.claude/projects/" -name "${jsid}.jsonl" 2>/dev/null | head -1)
            if [ -z "$jsonl_path" ] || [ ! -f "$jsonl_path" ]; then
                rm -f "$pt_file" "$STATE_DIR/thinking-stage-$jsid"
                continue
            fi
            local tail_type
            tail_type=$(tail -1 "$jsonl_path" 2>/dev/null | jq -r '.type // empty' 2>/dev/null)
            if [ "$tail_type" != "user" ]; then
                # Turn ended or assistant is actively writing — no thinking line
                rm -f "$pt_file" "$STATE_DIR/thinking-stage-$jsid"
                continue
            fi

            stage_file="$STATE_DIR/thinking-stage-$jsid"
            current_stage=$(cat "$stage_file" 2>/dev/null || echo "0")
            last_play=$(cat "$LAST_PLAY_FILE" 2>/dev/null || echo "0")
            since_last=$((now - last_play))

            if [ "$elapsed" -ge 90 ]; then
                stage=3
                [ "$current_stage" -ge 3 ] && [ "$since_last" -lt 30 ] && continue
            elif [ "$elapsed" -ge 60 ] && [ "$current_stage" -lt 2 ]; then
                stage=2
            elif [ "$elapsed" -ge 30 ] && [ "$current_stage" -lt 1 ]; then
                stage=1
            else
                continue
            fi

            local line
            line=$(get_thinking_line "$stage")
            echo "$stage" > "$stage_file"
            date +%s > "$LAST_PLAY_FILE"

            speak_short "$line"
            fired=1
            break  # Only fire one thinking line per cycle
        done
    done
}

# Start thinking timer in background
thinking_timer &
THINKING_PID=$!

# ─── Main JSONL Watcher ───────────────────────────────────────────

inotifywait -m -r -e modify --include '\.jsonl$' --format '%w%f' \
    "$HOME/.claude/projects/" 2>/dev/null | while read -r JSONL; do

    [ -f ~/.claude/tts-enabled ] || continue

    # Skip subagent JSONLs
    [[ "$JSONL" == */subagents/* ]] && continue

    JSID=$(basename "$JSONL" .jsonl)
    OFFSET_FILE="$STATE_DIR/offset-$JSID"
    SPOKEN_FILE="$STATE_DIR/spoken-$JSID"

    # Initialize offset on first modify (if CREATE event was missed, e.g. daemon restart)
    if [ ! -f "$OFFSET_FILE" ]; then
        wc -c < "$JSONL" > "$OFFSET_FILE"
        : > "$SPOKEN_FILE"
        continue
    fi

    OFFSET=$(cat "$OFFSET_FILE")
    CURRENT_SIZE=$(wc -c < "$JSONL")
    [ "$CURRENT_SIZE" -le "$OFFSET" ] && continue

    NEW_CONTENT=$(tail -c +$((OFFSET + 1)) "$JSONL")
    echo "$CURRENT_SIZE" > "$OFFSET_FILE"

    echo "$NEW_CONTENT" | while IFS= read -r line; do
        [ -z "$line" ] && continue

        MSG_TYPE=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)

        PT_FILE="$STATE_DIR/prompt-time-$JSID"
        TS_FILE="$STATE_DIR/thinking-stage-$JSID"

        # Turn complete markers — clear thinking timer, this session is idle
        if [ "$MSG_TYPE" = "last-prompt" ] || [ "$MSG_TYPE" = "system" ] || [ "$MSG_TYPE" = "file-history-snapshot" ]; then
            rm -f "$PT_FILE" "$TS_FILE"
            continue
        fi

        # New user message = new turn or tool result
        if [ "$MSG_TYPE" = "user" ]; then
            rm -f "$STOP_SENTINEL"
            # Start thinking timer for this session
            date +%s > "$PT_FILE"
            rm -f "$TS_FILE"

            # Check if this is a tool_result (agent return)
            HAS_TOOL_RESULT=$(echo "$line" | jq -r '[.message.content[]? | select(.type == "tool_result")] | length' 2>/dev/null)
            if [ "$HAS_TOOL_RESULT" != "0" ] && [ -f "$AGENT_ACTIVE_FILE" ]; then
                rm -f "$AGENT_ACTIVE_FILE"
                PHRASE=$(resolve_agent_return_phrase)
                if [ -n "$PHRASE" ]; then
                    stopped && continue
                    TAIL_TYPE=$(tail -1 "$JSONL" 2>/dev/null | jq -r '.type // empty' 2>/dev/null)
                    [ "$TAIL_TYPE" = "last-prompt" ] || [ "$TAIL_TYPE" = "file-history-snapshot" ] || [ "$TAIL_TYPE" = "system" ] && continue
                    speak_short "$PHRASE"
                fi
            fi
            continue
        fi

        [ "$MSG_TYPE" != "assistant" ] && continue
        stopped && continue

        # Assistant activity resets thinking timer (Claude is working, not stuck)
        date +%s > "$PT_FILE"
        rm -f "$TS_FILE"

        # ── Handle tool_use blocks (announcements) ──
        TOOL_NAMES=$(echo "$line" | jq -r '
            .message.content[]? |
            select(.type == "tool_use") |
            .name // empty
        ' 2>/dev/null)

        if [ -n "$TOOL_NAMES" ]; then
            FIRST_TOOL_INPUT=$(echo "$line" | jq -c '
                [.message.content[]? | select(.type == "tool_use")][0].input // {}
            ' 2>/dev/null)

            FIRST_TOOL=$(echo "$TOOL_NAMES" | head -1)

            # Deduplicate rapid-fire announcements
            NOW_MS=$(date +%s)
            LAST_TOOL_FILE="$STATE_DIR/last-tool"
            LAST_RESEARCH_FILE="$STATE_DIR/last-research"
            LAST_TOOL_INFO=$(cat "$LAST_TOOL_FILE" 2>/dev/null)
            LAST_TOOL_NAME="${LAST_TOOL_INFO%%:*}"
            LAST_TOOL_TIME="${LAST_TOOL_INFO##*:}"

            # Research tool group dedup — Read/Grep/Glob suppress each other for 10s
            IS_RESEARCH=0
            case "$FIRST_TOOL" in Read|Grep|Glob) IS_RESEARCH=1 ;; esac
            LAST_RESEARCH_TIME=$(cat "$LAST_RESEARCH_FILE" 2>/dev/null || echo "0")

            # Important Bash commands bypass same-tool dedup (tests, git)
            IS_IMPORTANT_BASH=0
            if [ "$FIRST_TOOL" = "Bash" ]; then
                local bash_cmd_check
                bash_cmd_check=$(echo "$FIRST_TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null)
                case "$bash_cmd_check" in
                    *"go test"*|*"make test"*|*"make lint"*) IS_IMPORTANT_BASH=1 ;;
                esac
            fi

            if [ "$IS_RESEARCH" = "1" ] && \
               [ "$LAST_RESEARCH_TIME" != "0" ] && \
               [ $((NOW_MS - LAST_RESEARCH_TIME)) -lt 10 ]; then
                # Research tool fired recently — skip
                :
            elif [ "$IS_IMPORTANT_BASH" = "0" ] && \
               [ "$FIRST_TOOL" = "$LAST_TOOL_NAME" ] && \
               [ -n "$LAST_TOOL_TIME" ] && \
               [ $((NOW_MS - LAST_TOOL_TIME)) -lt 3 ]; then
                # Same tool within 3 seconds — skip announcement (unless important)
                :
            else
                echo "$FIRST_TOOL:$NOW_MS" > "$LAST_TOOL_FILE"
                [ "$IS_RESEARCH" = "1" ] && echo "$NOW_MS" > "$LAST_RESEARCH_FILE"
                PHRASE=$(resolve_tool_phrase "$FIRST_TOOL" "$FIRST_TOOL_INPUT")

                if [ -n "$PHRASE" ]; then
                    stopped && continue
                    # Check if turn already ended
                    TAIL_TYPE=$(tail -1 "$JSONL" 2>/dev/null | jq -r '.type // empty' 2>/dev/null)
                    [ "$TAIL_TYPE" = "last-prompt" ] || [ "$TAIL_TYPE" = "file-history-snapshot" ] || [ "$TAIL_TYPE" = "system" ] && continue
                    [ -f ~/.claude/tts-enabled ] || continue
                    speak_short "$PHRASE"
                fi
            fi
        fi

        # ── Handle text blocks (intermediate speech) ──
        # Join all text blocks from this message into one string so multi-line
        # content (like insight blocks) stays intact for tts_hook.py to parse.
        FULL_TEXT=$(echo "$line" | jq -r '
            [.message.content[]? | select(.type == "text") | .text // empty] | join("\n")
        ' 2>/dev/null)

        [ -z "$FULL_TEXT" ] && continue
        stopped && continue

        HASH=$(printf '%s' "$FULL_TEXT" | md5sum | cut -d' ' -f1)
        grep -qF "$HASH" "$SPOKEN_FILE" 2>/dev/null && continue

        wait_for_tts || continue
        stopped && continue

        # Brief delay, then check if the turn ended while we waited.
        # If last-prompt/file-history-snapshot appeared at the end of
        # the JSONL, this is the final response — let the Stop hook
        # handle it instead of double-speaking.
        sleep 0.5
        stopped && continue
        TAIL_TYPE=$(tail -1 "$JSONL" 2>/dev/null | jq -r '.type // empty' 2>/dev/null)
        if [ "$TAIL_TYPE" = "last-prompt" ] || [ "$TAIL_TYPE" = "file-history-snapshot" ] || [ "$TAIL_TYPE" = "system" ]; then
            continue
        fi

        [ -f ~/.claude/tts-enabled ] || continue

        echo "$HASH" >> "$SPOKEN_FILE"
        speak_long "$FULL_TEXT"

    done
done

# Clean up thinking timer
kill $THINKING_PID 2>/dev/null
