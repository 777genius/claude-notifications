#!/bin/bash
# analyzer.sh - Analyze hook data to determine task status

# Prevent double-sourcing (causes "readonly variable" errors)
[[ -n "${_ANALYZER_SOURCED:-}" ]] && return 0
_ANALYZER_SOURCED=1

# Source dependencies
_ANALYZER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_ANALYZER_DIR}/json-parser.sh"

# Tool categories for state machine classification
readonly ACTIVE_TOOLS=("Write" "Edit" "Bash" "NotebookEdit" "SlashCommand" "KillShell")
readonly QUESTION_TOOLS=("AskUserQuestion")
readonly PLANNING_TOOLS=("ExitPlanMode" "TodoWrite")
readonly PASSIVE_TOOLS=("Read" "Grep" "Glob" "WebFetch" "WebSearch" "Task")

# Helper: Get last N assistant messages from JSONL transcript
# Args: $1 - JSONL transcript, $2 - number of messages (default 15)
# Returns: JSON array of assistant messages
_get_last_assistant_messages() {
  local transcript="$1"
  local count="${2:-15}"

  # Convert JSONL to array, filter assistant, take last N
  local all_arr=$(echo "$transcript" | jsonl_slurp)

  # Use Python/PowerShell/jq depending on availability
  local backend=$(_json_backend)
  case "$backend" in
    jq)
      echo "$all_arr" | jq -c "[.[] | select(.type == \"assistant\")] | .[-${count}:]" 2>/dev/null || echo "[]"
      ;;
    powershell)
      echo "$all_arr" | powershell -NoProfile -Command "
        \$json = [Console]::In.ReadToEnd()
        try {
          \$arr = \$json | ConvertFrom-Json -Depth 200
          \$filtered = @(\$arr | Where-Object { \$_.type -eq 'assistant' })
          \$last = if (\$filtered.Count -gt $count) { \$filtered[-$count..-1] } else { \$filtered }
          \$last | ConvertTo-Json -Depth 200 -Compress
        } catch { '[]' }
      " 2>/dev/null | tr -d '\r' || echo "[]"
      ;;
    python3|python)
      echo "$all_arr" | "$backend" -c "
import sys, json
try:
    arr = json.loads(sys.stdin.read())
    filtered = [msg for msg in arr if msg.get('type') == 'assistant']
    last = filtered[-$count:] if len(filtered) > $count else filtered
    sys.stdout.write(json.dumps(last, separators=(',', ':')))
except: sys.stdout.write('[]')
" 2>/dev/null || echo "[]"
      ;;
    *)
      echo "[]"
      ;;
  esac
}

# Helper: Extract tools with positions from assistant messages array
# Args: $1 - JSON array of assistant messages
# Returns: JSON array of {position: N, tool: "ToolName"}
_extract_tools_with_positions() {
  local messages="$1"

  local backend=$(_json_backend)
  case "$backend" in
    jq)
      echo "$messages" | jq -r '
        . as $messages |
        [range(0; length) as $i |
          $messages[$i].message.content[]? |
          select(.type? == "tool_use") |
          {position: $i, tool: .name}
        ]
      ' 2>/dev/null || echo "[]"
      ;;
    powershell)
      echo "$messages" | powershell -NoProfile -Command "
        \$json = [Console]::In.ReadToEnd()
        try {
          \$msgs = \$json | ConvertFrom-Json -Depth 200
          \$tools = @()
          for (\$i = 0; \$i -lt \$msgs.Count; \$i++) {
            \$msg = \$msgs[\$i]
            if (\$msg.message.content) {
              foreach (\$item in \$msg.message.content) {
                if (\$item.type -eq 'tool_use') {
                  \$tools += @{position = \$i; tool = \$item.name}
                }
              }
            }
          }
          \$tools | ConvertTo-Json -Depth 200 -Compress
        } catch { '[]' }
      " 2>/dev/null | tr -d '\r' || echo "[]"
      ;;
    python3|python)
      echo "$messages" | "$backend" -c "
import sys, json
try:
    msgs = json.loads(sys.stdin.read())
    tools = []
    for i, msg in enumerate(msgs):
        if 'message' in msg and 'content' in msg['message']:
            for item in msg['message']['content']:
                if item.get('type') == 'tool_use':
                    tools.append({'position': i, 'tool': item.get('name')})
    sys.stdout.write(json.dumps(tools, separators=(',', ':')))
except: sys.stdout.write('[]')
" 2>/dev/null || echo "[]"
      ;;
    *)
      echo "[]"
      ;;
  esac
}

# Helper: Extract text content from last N assistant messages
# Args: $1 - JSONL transcript, $2 - number of messages (default 5)
# Returns: concatenated text (space-separated)
_get_recent_assistant_text() {
  local transcript="$1"
  local count="${2:-5}"

  local messages=$(_get_last_assistant_messages "$transcript" "$count")

  local backend=$(_json_backend)
  case "$backend" in
    jq)
      echo "$messages" | jq -r '.[] | .message.content[]? | select(.type? == "text") | .text // empty' 2>/dev/null | tr '\n' ' '
      ;;
    powershell)
      echo "$messages" | powershell -NoProfile -Command "
        \$json = [Console]::In.ReadToEnd()
        try {
          \$msgs = \$json | ConvertFrom-Json -Depth 200
          \$texts = @()
          foreach (\$msg in \$msgs) {
            if (\$msg.message.content) {
              foreach (\$item in \$msg.message.content) {
                if (\$item.type -eq 'text' -and \$item.text) {
                  \$texts += \$item.text
                }
              }
            }
          }
          \$texts -join ' '
        } catch { '' }
      " 2>/dev/null | tr -d '\r'
      ;;
    python3|python)
      echo "$messages" | "$backend" -c "
import sys, json
try:
    msgs = json.loads(sys.stdin.read())
    texts = []
    for msg in msgs:
        if 'message' in msg and 'content' in msg['message']:
            for item in msg['message']['content']:
                if item.get('type') == 'text' and item.get('text'):
                    texts.append(item['text'])
    sys.stdout.write(' '.join(texts))
except: pass
" 2>/dev/null
      ;;
    *)
      echo ""
      ;;
  esac
}

# Helper: Count tool uses in JSONL transcript
# Args: $1 - JSONL transcript
# Returns: number of tool uses
_count_tool_uses() {
  local transcript="$1"

  local all_arr=$(echo "$transcript" | jsonl_slurp)

  local backend=$(_json_backend)
  case "$backend" in
    jq)
      echo "$all_arr" | jq '[.[] | select(.message.content[]?.type? == "tool_use")] | length' 2>/dev/null || echo "0"
      ;;
    powershell)
      echo "$all_arr" | powershell -NoProfile -Command "
        \$json = [Console]::In.ReadToEnd()
        try {
          \$arr = \$json | ConvertFrom-Json -Depth 200
          \$count = 0
          foreach (\$msg in \$arr) {
            if (\$msg.message.content) {
              foreach (\$item in \$msg.message.content) {
                if (\$item.type -eq 'tool_use') { \$count++ }
              }
            }
          }
          \$count
        } catch { 0 }
      " 2>/dev/null | tr -d '\r' || echo "0"
      ;;
    python3|python)
      echo "$all_arr" | "$backend" -c "
import sys, json
try:
    arr = json.loads(sys.stdin.read())
    count = 0
    for msg in arr:
        if 'message' in msg and 'content' in msg['message']:
            for item in msg['message']['content']:
                if item.get('type') == 'tool_use':
                    count += 1
    print(count)
except: print(0)
" 2>/dev/null || echo "0"
      ;;
    *)
      echo "0"
      ;;
  esac
}

# Check if tool is in category
is_tool_in_category() {
  local tool="$1"
  local category="$2"

  case "$category" in
    "active")
      for t in "${ACTIVE_TOOLS[@]}"; do
        [[ "$tool" == "$t" ]] && return 0
      done
      ;;
    "question")
      for t in "${QUESTION_TOOLS[@]}"; do
        [[ "$tool" == "$t" ]] && return 0
      done
      ;;
    "planning")
      for t in "${PLANNING_TOOLS[@]}"; do
        [[ "$tool" == "$t" ]] && return 0
      done
      ;;
    "passive")
      for t in "${PASSIVE_TOOLS[@]}"; do
        [[ "$tool" == "$t" ]] && return 0
      done
      ;;
  esac

  return 1
}

# Detect status from tool sequence using state machine
# Args: $1 - transcript content (JSONL)
# Returns: status string or "unknown"
detect_status_from_tools() {
  local transcript="$1"

  # Get recent assistant messages (last 15 for temporal locality)
  # JSONL format: slurp with -s, filter assistant messages, take last 15
  local recent_messages=$(_get_last_assistant_messages "$transcript" 15)

  if [[ -z "$recent_messages" ]] || [[ "$recent_messages" == "null" ]] || [[ "$recent_messages" == "[]" ]]; then
    log_debug "No recent assistant messages found"
    echo "unknown"
    return
  fi

  # Extract all tools from recent messages with their positions (reverse index)
  # Format: [{position: 0, tool: "ExitPlanMode"}, {position: 1, tool: "Write"}, ...]
  local tools_with_positions=$(_extract_tools_with_positions "$recent_messages")

  if [[ -z "$tools_with_positions" ]] || [[ "$tools_with_positions" == "null" ]] || [[ "$tools_with_positions" == "[]" ]]; then
    log_debug "No tools found in recent messages"
    echo "unknown"
    return
  fi

  # Get the last tool (highest position)
  local last_tool=$(echo "$tools_with_positions" | json_get ".[-1].tool" "")
  log_debug "Last tool in recent messages: '$last_tool'"

  # Find ExitPlanMode position (if exists)
  local exit_plan_position=-1
  local backend=$(_json_backend)
  case "$backend" in
    jq)
      exit_plan_position=$(echo "$tools_with_positions" | jq -r '[.[] | select(.tool == "ExitPlanMode")] | last | .position // -1' 2>/dev/null || echo "-1")
      ;;
    *)
      # Find last ExitPlanMode position using bash
      local temp_pos=-1
      local i=0
      while true; do
        local tool=$(echo "$tools_with_positions" | json_get ".${i}.tool" "")
        [[ -z "$tool" ]] && break
        local pos=$(echo "$tools_with_positions" | json_get ".${i}.position" "-1")
        [[ "$tool" == "ExitPlanMode" ]] && temp_pos=$pos
        i=$((i + 1))
      done
      exit_plan_position=$temp_pos
      ;;
  esac
  log_debug "ExitPlanMode position: $exit_plan_position"

  # Get highest position (latest tool position)
  local last_position=$(echo "$tools_with_positions" | json_get ".[-1].position" "-1")
  log_debug "Last tool position: $last_position"

  # STATE MACHINE LOGIC (priority order):

  # 1. If last tool is ExitPlanMode → plan just created, awaiting approval
  if [[ "$last_tool" == "ExitPlanMode" ]]; then
    log_debug "State: PLAN_READY (ExitPlanMode is last tool)"
    echo "plan_ready"
    return
  fi

  # 2. If last tool is AskUserQuestion → waiting for user input
  if is_tool_in_category "$last_tool" "question"; then
    log_debug "State: QUESTION (AskUserQuestion is last tool)"
    echo "question"
    return
  fi

  # 3. If ExitPlanMode exists AND tools after it → plan was approved and executed
  if [[ $exit_plan_position -ge 0 ]] && [[ $last_position -gt $exit_plan_position ]]; then
    # Check if there are active tools after ExitPlanMode
    local active_tools_after=0
    local i=0
    while true; do
      local tool=$(echo "$tools_with_positions" | json_get ".${i}.tool" "")
      [[ -z "$tool" ]] && break
      local pos=$(echo "$tools_with_positions" | json_get ".${i}.position" "-1")
      if [[ $pos -gt $exit_plan_position ]]; then
        active_tools_after=$((active_tools_after + 1))
      fi
      i=$((i + 1))
    done
    log_debug "Active tools after ExitPlanMode: $active_tools_after"

    if [[ $active_tools_after -gt 0 ]]; then
      log_debug "State: TASK_COMPLETE (ExitPlanMode + tools after = plan executed)"
      echo "task_complete"
      return
    fi
  fi

  # 4. If last tool is active (Write/Edit/Bash) → work completed
  if is_tool_in_category "$last_tool" "active"; then
    log_debug "State: TASK_COMPLETE (last tool is active: $last_tool)"
    echo "task_complete"
    return
  fi

  # 5. If last tool is passive (Read/Grep/Glob) → might be research, check keywords
  if is_tool_in_category "$last_tool" "passive"; then
    log_debug "State: PASSIVE_ACTIVITY (last tool is passive: $last_tool), will fallback to keyword analysis"
    echo "unknown"  # Signal to use fallback
    return
  fi

  # 6. Unknown tool or no clear state
  log_debug "State: UNKNOWN (last_tool: $last_tool)"
  echo "unknown"
}

# Analyze hook event and determine notification status
# Args: $1 - hook event name, $2 - JSON data from stdin
analyze_status() {
  local hook_event="$1"
  local hook_data="$2"
  local transcript_path=$(echo "$hook_data" | json_get ".transcript_path" "")

  # Notification hooks в Claude Code:
  # - Это системные события, которые приходят отдельно от сообщений/инструментов в транскрипте.
  # - Часто следуют ПОСЛЕ PreToolUse ExitPlanMode (когда UI показывает диалог подтверждения плана),
  #   но сами по себе не содержат имени инструмента. Ранее мы мапили их безусловно → "question",
  #   что приводило к лишнему уведомлению "Claude Has Questions" сразу после "Plan Ready".
  # - Здесь реализована защита от дублей: если по последним сообщениям видно, что последний инструмент
  #   — ExitPlanMode (значит мы уже отправили Plan Ready из PreToolUse), то Notification подавляется.
  # - Если же по инструментам видно явный вопрос (AskUserQuestion), возвращаем "question" как и прежде.
  # - UI‑подтверждения для Write/Edit/Bash неотслеживаемы хуками (архитектурное ограничение Claude Code),
  #   поэтому на них мы не ориентируемся; этот код лишь убирает ложные дубли после ExitPlanMode.
  # - Анализ делается на основе окна последних ~15 ассистент‑сообщений (см. detect_status_from_tools).
  #
  # Итог: при цепочке "PreToolUse: ExitPlanMode → Notification" остаётся только одно уведомление — Plan Ready.
  # Во всех прочих Notification остаётся поведение по умолчанию.
  #
  # For Notification hook - default is "question", but avoid duplicate after ExitPlanMode
  if [[ "$hook_event" == "Notification" ]]; then
    log_debug "Notification event received; duplicate protection with session state + transcript"

    # 1) Try session state first (written by PreToolUse). TTL = 60 seconds.
    local session_id=$(echo "$hook_data" | json_get ".session_id" "")
    local temp_dir=$(get_temp_dir)
    local state_file="${temp_dir}/claude-session-state-${session_id}.json"
    local now_ts=$(get_current_timestamp)
    if [[ -f "$state_file" ]]; then
      local last_ts=$(cat "$state_file" | json_get ".last_ts" "0")
      local last_tool=$(cat "$state_file" | json_get ".last_interactive_tool" "")
      local age=$((now_ts - last_ts))
      log_debug "Notification: session state found (tool=$last_tool, age=${age}s)"

      if [[ $age -lt 60 ]]; then
        if [[ "$last_tool" == "ExitPlanMode" ]]; then
          log_debug "Notification suppressed by session state: recent ExitPlanMode (<60s)"
          echo "unknown"
          return
        fi
        if [[ "$last_tool" == "AskUserQuestion" ]]; then
          # PreToolUse already sent a 'question' notification; suppress Notification duplicate
          log_debug "Notification suppressed by session state: recent AskUserQuestion (<60s)"
          echo "unknown"
          return
        fi
      fi
    fi

    # 2) Fallback: analyze transcript (temporal window) to infer state
    if [[ -n "$transcript_path" ]] && [[ -f "$transcript_path" ]]; then
      local transcript=$(cat "$transcript_path" 2>/dev/null || echo "{}")
      local status_by_tools=$(detect_status_from_tools "$transcript")
      log_debug "Notification: status by tools = $status_by_tools"

      if [[ "$status_by_tools" == "plan_ready" ]]; then
        log_debug "Notification suppressed: ExitPlanMode is last tool (plan already notified)"
        echo "unknown"
        return
      fi
      if [[ "$status_by_tools" == "question" ]]; then
        echo "question"
        return
      fi
    fi

    # 3) Final fallback: treat as generic question
    log_debug "Notification fallback → question status"
    echo "question"
    return
  fi

  # For Stop and SubagentStop hooks, analyze transcript and tools
  if [[ "$hook_event" == "Stop" ]] || [[ "$hook_event" == "SubagentStop" ]]; then
    log_debug "Transcript path from hook_data: '$transcript_path'"

    # Try to read and analyze transcript
    if [[ -f "$transcript_path" ]]; then
      log_debug "Transcript file exists, reading..."
      local transcript=$(cat "$transcript_path" 2>/dev/null || echo "{}")
      log_debug "Transcript size: ${#transcript} bytes"

      # PHASE 1: Tool-based state machine analysis
      local status=$(detect_status_from_tools "$transcript")

      if [[ "$status" != "unknown" ]]; then
        log_debug "Status determined by state machine: $status"
        echo "$status"
        return
      fi

      # PHASE 2: Fallback to keyword and activity analysis
      log_debug "State machine returned unknown, using fallback analysis..."

      # Check for review/analysis keywords in recent messages
      local recent_text=$(_get_recent_assistant_text "$transcript" 5)
      log_debug "Recent text: ${recent_text:0:100}..."

      if echo "$recent_text" | grep -qiE "review|ревью|analyzed|проверка|analysis"; then
        log_debug "Found review keywords, status: review_complete"
        echo "review_complete"
        return
      fi

      # Check for completion keywords
      if echo "$recent_text" | grep -qiE "completed|завершен|done|finished|успешно|ready"; then
        log_debug "Found completion keywords, status: task_complete"
        echo "task_complete"
        return
      fi

      # Count tool usage to determine if significant work was done
      # JSONL format: each line is a separate JSON, need to slurp with -s and check message.content
      local tool_count=$(_count_tool_uses "$transcript")
      log_debug "Tool usage count: $tool_count"

      if [[ $tool_count -ge 3 ]]; then
        log_debug "Tool count >= 3, status: task_complete"
        echo "task_complete"
        return
      fi

      # If there was at least some tool usage, consider it a completed task
      if [[ $tool_count -ge 1 ]]; then
        log_debug "Tool count >= 1, status: task_complete"
        echo "task_complete"
        return
      fi

      log_debug "No significant activity in transcript (tool_count: $tool_count)"
    else
      log_debug "Transcript file does NOT exist at: $transcript_path"
    fi

    # No significant activity detected - return unknown to skip notification
    log_debug "Returning status: unknown (no activity detected)"
    echo "unknown"
    return
  fi

  # Unknown status
  echo "unknown"
}

# Get status configuration from config file
# Args: $1 - status name
get_status_config() {
  local status="$1"
  local config_file="${PLUGIN_DIR}/config/config.json"

  if [[ ! -f "$config_file" ]]; then
    # Return default config if file doesn't exist
    echo "{\"title\":\"Claude Code\",\"sound\":\"\",\"icon\":\"\"}"
    return
  fi

  local config=$(cat "$config_file")
  local status_config=$(echo "$config" | json_get ".statuses.${status}" "")

  if [[ -z "$status_config" ]] || [[ "$status_config" == "null" ]]; then
    echo "{\"title\":\"Claude Code\",\"sound\":\"\",\"icon\":\"\"}"
  else
    echo "$status_config"
  fi
}

export -f analyze_status
export -f get_status_config
export -f detect_status_from_tools
export -f is_tool_in_category
