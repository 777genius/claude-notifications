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

set -euo pipefail

# Source all library functions
source "${PLUGIN_DIR}/lib/platform.sh"
source "${PLUGIN_DIR}/lib/cross-platform.sh"
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
  local session_id=$(echo "$hook_data" | jq -r '.session_id // "unknown"')

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

    if [[ $age -lt 2 ]]; then
      log_debug "Duplicate hook detected early (age: ${age}s), skipping [PID: $$]"
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
  local desktop_enabled=$(echo "$config" | jq -r '.notifications.desktop.enabled // true')
  log_debug "Desktop notifications enabled: $desktop_enabled"

  # Only proceed if at least one notification method is enabled
  local webhook_enabled=$(echo "$config" | jq -r '.notifications.webhook.enabled // false')
  log_debug "Webhook enabled: $webhook_enabled"
  if [[ "$desktop_enabled" != "true" ]] && [[ "$webhook_enabled" != "true" ]]; then
    log_debug "All notifications disabled, exiting"
    exit 0
  fi

  # Declare status variable
  local status=""

  # For PreToolUse - check tool_name (fires BEFORE tool execution)
  if [[ "$hook_event" == "PreToolUse" ]]; then
    local tool_name=$(echo "$hook_data" | jq -r '.tool_name // empty')
    log_debug "PreToolUse: tool_name='$tool_name'"

    if [[ "$tool_name" == "ExitPlanMode" ]]; then
      status="plan_ready"
      log_debug "PreToolUse: ExitPlanMode detected → plan_ready notification"
    elif [[ "$tool_name" == "AskUserQuestion" ]]; then
      status="question"
      log_debug "PreToolUse: AskUserQuestion detected → question notification"
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

  # === Все early exits пройдены - создаем lock перед отправкой ===
  # Финальная проверка на race condition (могли пройти оба процесса выше)
  if [[ -f "$LOCK_FILE" ]]; then
    local lock_timestamp=$(get_file_mtime "$LOCK_FILE")
    local current_timestamp=$(get_current_timestamp)
    local age=$((current_timestamp - lock_timestamp))

    if [[ $age -lt 2 ]]; then
      log_debug "Duplicate detected at final check (age: ${age}s), skipping [PID: $$]"
      exit 0
    fi
  fi

  # Создаем lock прямо перед генерацией summary и отправкой
  create_lock_file "$LOCK_FILE"
  log_debug "Lock file created before notification: $LOCK_FILE [PID: $$]"

  # Get transcript path, session ID, and working directory
  local transcript_path=$(echo "$hook_data" | jq -r '.transcript_path // empty')
  local session_id=$(echo "$hook_data" | jq -r '.session_id // "unknown"')
  local cwd=$(echo "$hook_data" | jq -r '.cwd // empty')
  log_debug "Transcript path: $transcript_path"

  # Generate summary with status context
  local summary=$(generate_summary "$transcript_path" "$hook_data" "$status")
  summary=$(clean_text "$summary")
  log_debug "Summary generated: ${summary:0:50}..."

  # Get status configuration
  local status_title=$(echo "$config" | jq -r ".statuses.${status}.title // \"Claude Code\"")
  local sound_file=$(echo "$config" | jq -r ".statuses.${status}.sound // empty")

  # Generate friendly session name and add to title
  local session_name=$(generate_session_name "$session_id")
  status_title="${status_title} [${session_name}]"

  log_debug "Status title: $status_title"
  log_debug "Session name: $session_name"
  log_debug "Sound file from config: $sound_file"

  # Resolve sound file path
  if [[ -n "$sound_file" ]] && [[ ! "$sound_file" = /* ]]; then
    sound_file="${PLUGIN_DIR}/${sound_file}"
  fi
  log_debug "Resolved sound file path: $sound_file"

  # Send desktop notification
  if [[ "$desktop_enabled" == "true" ]]; then
    log_debug "Sending desktop notification..."
    send_notification "$status_title" "$summary" "$cwd"
    log_debug "Desktop notification sent"

    # Play sound if configured
    if [[ -n "$sound_file" ]] && [[ -f "$sound_file" ]]; then
      log_debug "Playing sound: $sound_file"
      play_sound "$sound_file" "$config"
      log_debug "Sound playback initiated"
    else
      log_debug "Sound file not found or not configured: $sound_file"
    fi
  fi

  # Send webhook notification
  if [[ "$webhook_enabled" == "true" ]]; then
    log_debug "Sending webhook notification..."
    send_webhook "$status" "$summary" "$session_id" "$config"
    log_debug "Webhook sent"
  fi

  # Cleanup старых lock-файлов (старше 60 секунд)
  cleanup_old_files "$TEMP_DIR" "claude-notification-*.lock" 60

  log_debug "=== Notification handler completed successfully ==="
  # Exit successfully (don't block Claude)
  exit 0
}

# Run main function
main "$@"
