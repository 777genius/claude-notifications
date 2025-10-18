#!/bin/bash
# notification-handler.sh - Main orchestrator for Claude Code notifications

# Get the plugin directory first (before set -e)
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PLUGIN_DIR

# Setup logging
LOG_FILE="${PLUGIN_DIR}/notification-debug.log"
log_debug() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Error handler
error_handler() {
  local line_no=$1
  log_debug "ERROR: Script failed at line $line_no"
  log_debug "Last command: $BASH_COMMAND"
  exit 1
}

trap 'error_handler ${LINENO}' ERR

set -eu

# Source all library functions
source "${PLUGIN_DIR}/lib/platform.sh"
source "${PLUGIN_DIR}/lib/cross-platform.sh"
source "${PLUGIN_DIR}/lib/json-parser.sh"
source "${PLUGIN_DIR}/lib/analyzer.sh"
source "${PLUGIN_DIR}/lib/summarizer.sh"
source "${PLUGIN_DIR}/lib/notifier.sh"
source "${PLUGIN_DIR}/lib/webhook.sh"
source "${PLUGIN_DIR}/lib/sound.sh"
source "${PLUGIN_DIR}/lib/session-name.sh"

# Main function
main() {
  local hook_event="${1:-Stop}"
  log_debug "=== Hook triggered: $hook_event [PID: $$] ==="

  # Read JSON data from stdin
  local hook_data=$(cat)
  log_debug "Hook data received: ${#hook_data} bytes [PID: $$]"

  # Get session ID early for deduplication
  local session_id=$(echo "$hook_data" | json_get ".session_id" "unknown")

  # Deduplication: защита от бага Claude Code (versions 2.0.17-2.0.21)
  # Хуки выполняются 2-4 раза для одного события (GitHub issues #9602, #3465, #3523)
  # NOTE: Lock создается ПОСЛЕ всех early exit проверок, чтобы избежать "0 уведомлений"
  local TEMP_DIR=$(get_temp_dir)
  local LOCK_FILE="${TEMP_DIR}/claude-notification-${hook_event}-${session_id}.lock"

  # Ранняя проверка на дубликат (не создаем lock здесь!)
  if [[ -f "$LOCK_FILE" ]]; then
    local lock_timestamp=$(get_file_mtime "$LOCK_FILE")
    local current_timestamp=$(get_current_timestamp)
    local age=$((current_timestamp - lock_timestamp))

    # На Windows stat может вернуть 0 (mtime недоступно) — считаем это свежим дубликатом
    if [[ $lock_timestamp -eq 0 ]] || [[ $age -lt 2 ]]; then
      log_debug "Duplicate hook detected early (age: ${age}s, mtime: $lock_timestamp), skipping [PID: $$]"
      exit 0
    fi
  fi

  # Load configuration
  local config_file="${PLUGIN_DIR}/config/config.json"
  local config="{}"
  if [[ -f "$config_file" ]]; then
    config=$(cat "$config_file")
    log_debug "Config loaded successfully"
  else
    log_debug "Config file not found: $config_file"
  fi

  # Check if desktop notifications are enabled
  local desktop_enabled=$(echo "$config" | json_get ".notifications.desktop.enabled" "true")
  log_debug "Desktop notifications enabled: $desktop_enabled"

  # Only proceed if at least one notification method is enabled
  local webhook_enabled=$(echo "$config" | json_get ".notifications.webhook.enabled" "false")
  log_debug "Webhook enabled: $webhook_enabled"
  if [[ "$desktop_enabled" != "true" ]] && [[ "$webhook_enabled" != "true" ]]; then
    log_debug "All notifications disabled, exiting"
    exit 0
  fi

  # Declare status variable
  local status=""

  # For PreToolUse - check tool_name (fires BEFORE tool execution)
  if [[ "$hook_event" == "PreToolUse" ]]; then
    local tool_name=$(echo "$hook_data" | json_get ".tool_name" "")
    log_debug "PreToolUse: tool_name='$tool_name'"

    if [[ "$tool_name" == "ExitPlanMode" ]]; then
      status="plan_ready"
      log_debug "PreToolUse: ExitPlanMode detected → plan_ready notification"

      # Persist interactive state for this session (used by Notification hook)
      # Based on official hooks flow: PreToolUse fires before UI prompts; Notification fires separately
      # Docs: https://docs.claude.com/en/docs/claude-code/hooks-guide#custom-notification-hook
      local state_file="${TEMP_DIR}/claude-session-state-${session_id}.json"
      local now_ts=$(get_current_timestamp)
      local hook_session_id=$(echo "$hook_data" | json_get ".session_id" "")
      local hook_cwd=$(echo "$hook_data" | json_get ".cwd" "")
      local state_json=$(json_build session_id "$hook_session_id" last_interactive_tool "$tool_name" last_ts "$now_ts" cwd "$hook_cwd")
      echo "$state_json" > "$state_file"
      log_debug "PreToolUse: session state written to $state_file"
    elif [[ "$tool_name" == "AskUserQuestion" ]]; then
      status="question"
      log_debug "PreToolUse: AskUserQuestion detected → question notification"

      # Persist interactive state for AskUserQuestion as well
      local state_file="${TEMP_DIR}/claude-session-state-${session_id}.json"
      local now_ts=$(get_current_timestamp)
      local hook_session_id=$(echo "$hook_data" | json_get ".session_id" "")
      local hook_cwd=$(echo "$hook_data" | json_get ".cwd" "")
      local state_json=$(json_build session_id "$hook_session_id" last_interactive_tool "$tool_name" last_ts "$now_ts" cwd "$hook_cwd")
      echo "$state_json" > "$state_file"
      log_debug "PreToolUse: session state written to $state_file"
    else
      # Should never happen with matcher, but just in case
      log_debug "PreToolUse: unexpected tool '$tool_name' - skipping"
      exit 0
    fi
    # Continue to notification sending below...
  else
    # For other hooks (Stop, SubagentStop, Notification), analyze status
    status=$(analyze_status "$hook_event" "$hook_data")
    log_debug "Status determined: $status"

    # Skip unknown and generic notification statuses
    if [[ "$status" == "unknown" ]] || [[ "$status" == "notification" ]]; then
      log_debug "Status is $status, skipping notification"
      exit 0
    fi
  fi

  log_debug "Processing status: $status"

  # === Все early exits пройдены — пытаемся атомарно захватить lock ===
  if try_acquire_lock "$LOCK_FILE"; then
    log_debug "Exclusive lock acquired: $LOCK_FILE [PID: $$]"
  else
    # Lock уже существует — проверим его возраст
    local lock_timestamp=$(get_file_mtime "$LOCK_FILE")
    local current_timestamp=$(get_current_timestamp)
    local age=$((current_timestamp - lock_timestamp))

    if [[ $lock_timestamp -eq 0 ]] || [[ $age -lt 2 ]]; then
      log_debug "Duplicate detected at lock acquire (age: ${age}s, mtime: $lock_timestamp), skipping [PID: $$]"
      exit 0
    fi

    # Похоже, lock устарел — попробуем заменить его
    rm -f "$LOCK_FILE" 2>/dev/null || true
    if try_acquire_lock "$LOCK_FILE"; then
      log_debug "Stale lock replaced: $LOCK_FILE [PID: $$]"
    else
      log_debug "Another process acquired the lock concurrently, skipping [PID: $$]"
      exit 0
    fi
  fi

  # Get transcript path, session ID, and working directory
  local transcript_path=$(echo "$hook_data" | json_get ".transcript_path" "")
  local session_id=$(echo "$hook_data" | json_get ".session_id" "unknown")
  local cwd=$(echo "$hook_data" | json_get ".cwd" "")
  log_debug "Transcript path: $transcript_path"

  # Generate summary with status context
  local summary=$(generate_summary "$transcript_path" "$hook_data" "$status")
  summary=$(clean_text "$summary")
  if [[ -z "$summary" ]] || [[ "$summary" =~ ^[[:space:]]*$ ]]; then
    log_debug "Empty summary after cleaning, using default message for status: $status"
    summary=$(get_default_message "$status")
  fi
  log_debug "Summary generated: ${summary:0:50}..."

  # Get status configuration
  local status_title=$(echo "$config" | json_get ".statuses.${status}.title" "Claude Code")
  local sound_file=$(echo "$config" | json_get ".statuses.${status}.sound" "")
  local app_icon=$(echo "$config" | json_get ".notifications.desktop.appIcon" "")

  # Generate friendly session name and add to title
  local session_name=$(generate_session_name "$session_id")
  status_title="${status_title} [${session_name}]"

  log_debug "Status title: $status_title"
  log_debug "Session name: $session_name"
  log_debug "Sound file from config: $sound_file"
  log_debug "App icon from config: $app_icon"

  # Resolve sound file path
  if [[ -n "$sound_file" ]] && [[ ! "$sound_file" = /* ]]; then
    sound_file="${PLUGIN_DIR}/${sound_file}"
  fi
  log_debug "Resolved sound file path: $sound_file"

  # Resolve app icon path (expand ${CLAUDE_PLUGIN_ROOT} and relative paths)
  if [[ -n "$app_icon" ]]; then
    app_icon="${app_icon//\$\{CLAUDE_PLUGIN_ROOT\}/${PLUGIN_DIR}}"
    if [[ ! "$app_icon" = /* ]]; then
      app_icon="${PLUGIN_DIR}/${app_icon}"
    fi
    log_debug "Resolved app icon path: $app_icon"
  fi

  # Send desktop notification
  if [[ "$desktop_enabled" == "true" ]]; then
    log_debug "Sending desktop notification..."
    send_notification "$status_title" "$summary" "$cwd" "$app_icon" || true
    log_debug "Desktop notification sent"

    # Play sound if configured
    if [[ -n "$sound_file" ]] && [[ -f "$sound_file" ]]; then
      log_debug "Playing sound: $sound_file"
      play_sound "$sound_file" "$config" || true
      log_debug "Sound playback initiated"
    else
      log_debug "Sound file not found or not configured: $sound_file"
    fi
  fi

  # Send webhook notification
  if [[ "$webhook_enabled" == "true" ]]; then
    log_debug "Sending webhook notification..."
    send_webhook "$status" "$summary" "$session_id" "$config" || true
    log_debug "Webhook sent"
  fi

  # Session state cleanup on Stop/SubagentStop
  if [[ "$hook_event" == "Stop" ]] || [[ "$hook_event" == "SubagentStop" ]]; then
    local state_file="${TEMP_DIR}/claude-session-state-${session_id}.json"
    if [[ -f "$state_file" ]]; then
      rm -f "$state_file" 2>/dev/null || true
      log_debug "Session state file removed: $state_file"
    fi
  fi

  # Cleanup старых lock-файлов (старше 60 секунд)
  cleanup_old_files "$TEMP_DIR" "claude-notification-*.lock" 60 || true

  log_debug "=== Notification handler completed successfully ==="
  # Exit successfully (don't block Claude)
  exit 0
}

# Run main function
main "$@"
