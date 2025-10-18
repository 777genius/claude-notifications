#!/bin/bash
# analyzer.sh - Analyze hook data to determine task status

# Tool categories for state machine classification
readonly ACTIVE_TOOLS=("Write" "Edit" "Bash" "NotebookEdit" "SlashCommand" "KillShell")
readonly QUESTION_TOOLS=("AskUserQuestion")
readonly PLANNING_TOOLS=("ExitPlanMode" "TodoWrite")
readonly PASSIVE_TOOLS=("Read" "Grep" "Glob" "WebFetch" "WebSearch" "Task")

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
  local recent_messages=$(echo "$transcript" | jq -s -c '[.[] | select(.type == "assistant")] | .[-15:]' 2>/dev/null)

  if [[ -z "$recent_messages" ]] || [[ "$recent_messages" == "null" ]] || [[ "$recent_messages" == "[]" ]]; then
    log_debug "No recent assistant messages found"
    echo "unknown"
    return
  fi

  # Extract all tools from recent messages with their positions (reverse index)
  # Format: [{position: 0, tool: "ExitPlanMode"}, {position: 1, tool: "Write"}, ...]
  local tools_with_positions=$(echo "$recent_messages" | jq -r '
    . as $messages |
    [range(0; length) as $i |
      $messages[$i].message.content[]? |
      select(.type? == "tool_use") |
      {position: $i, tool: .name}
    ]
  ' 2>/dev/null)

  if [[ -z "$tools_with_positions" ]] || [[ "$tools_with_positions" == "null" ]] || [[ "$tools_with_positions" == "[]" ]]; then
    log_debug "No tools found in recent messages"
    echo "unknown"
    return
  fi

  # Get the last tool (highest position)
  local last_tool=$(echo "$tools_with_positions" | jq -r 'last | .tool' 2>/dev/null)
  log_debug "Last tool in recent messages: '$last_tool'"

  # Find ExitPlanMode position (if exists)
  local exit_plan_position=$(echo "$tools_with_positions" | jq -r '[.[] | select(.tool == "ExitPlanMode")] | last | .position // -1' 2>/dev/null)
  log_debug "ExitPlanMode position: $exit_plan_position"

  # Get highest position (latest tool position)
  local last_position=$(echo "$tools_with_positions" | jq -r 'last | .position' 2>/dev/null)
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
    local active_tools_after=$(echo "$tools_with_positions" | jq -r "[.[] | select(.position > $exit_plan_position) | .tool] | length" 2>/dev/null)
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
  local transcript_path=$(echo "$hook_data" | jq -r '.transcript_path // empty')

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
    local session_id=$(echo "$hook_data" | jq -r '.session_id // empty')
    local temp_dir=$(get_temp_dir)
    local state_file="${temp_dir}/claude-session-state-${session_id}.json"
    local now_ts=$(get_current_timestamp)
    if [[ -f "$state_file" ]]; then
      local last_ts=$(jq -r '.last_ts // 0' "$state_file" 2>/dev/null || echo 0)
      local last_tool=$(jq -r '.last_interactive_tool // empty' "$state_file" 2>/dev/null || echo "")
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
      local recent_text=$(echo "$transcript" | jq -s -r '.[-5:] | .[] | select(.type == "assistant") | .message.content[]? | select(.type? == "text") | .text // empty' 2>/dev/null | tr '\n' ' ')
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
      local tool_count=$(echo "$transcript" | jq -s '[.[] | select(.message.content[]?.type? == "tool_use")] | length' 2>/dev/null || echo 0)
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

  jq -r ".statuses.${status} // {\"title\":\"Claude Code\",\"sound\":\"\",\"icon\":\"\"}" "$config_file"
}

export -f analyze_status
export -f get_status_config
export -f detect_status_from_tools
export -f is_tool_in_category
