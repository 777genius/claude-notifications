#!/bin/bash
# webhook.sh - Send webhook notifications

# Global error handler protection
[[ -z "${ERROR_HANDLER_LOADED:-}" ]] && source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/error-handler.sh"

# Source JSON parser
_WEBHOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_WEBHOOK_DIR}/json-parser.sh"

# Send webhook notification
# Args: $1 - status, $2 - message, $3 - session_id, $4 - config JSON
send_webhook() {
  local status="$1"
  local message="$2"
  local session_id="$3"
  local config="$4"

  # Check if webhook is enabled
  local enabled=$(echo "$config" | json_get ".notifications.webhook.enabled" "false")
  if [[ "$enabled" != "true" ]]; then
    return 0
  fi

  # Get webhook URL
  local url=$(echo "$config" | json_get ".notifications.webhook.url" "")
  if [[ -z "$url" ]]; then
    return 0
  fi

  # Get format (text or json)
  local format=$(echo "$config" | json_get ".notifications.webhook.format" "text")

  # Get custom headers (returns JSON object)
  local headers=$(echo "$config" | json_get ".notifications.webhook.headers" "{}")

  # Get preset (slack, discord, telegram, custom)
  local preset=$(echo "$config" | json_get ".notifications.webhook.preset" "custom")

  # Get chat_id (required for Telegram)
  local chat_id=$(echo "$config" | json_get ".notifications.webhook.chat_id" "")

  # Send webhook in background to avoid blocking
  send_webhook_async "$url" "$format" "$status" "$message" "$session_id" "$headers" "$preset" "$chat_id" &
}

# Send webhook asynchronously
send_webhook_async() {
  local url="$1"
  local format="$2"
  local status="$3"
  local message="$4"
  local session_id="$5"
  local headers="$6"
  local preset="$7"
  local chat_id="$8"

  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build custom headers array for curl
  local curl_header_args=()
  if [[ "$headers" != "{}" ]] && [[ -n "$headers" ]]; then
    # Extract header names and values into array
    while IFS= read -r header_line; do
      # Remove trailing CR/LF using tr (Windows compatible)
      header_line=$(echo "$header_line" | tr -d '\r\n')
      if [[ -n "$header_line" ]]; then
        curl_header_args+=(-H "$header_line")
      fi
    done < <(echo "$headers" | json_to_entries)
  fi

  # Build JSON payload based on preset
  local json_data=""

  case "$preset" in
    "slack")
      # Slack Incoming Webhooks
      # Docs: https://docs.slack.dev/messaging/sending-messages-using-incoming-webhooks
      json_data=$(json_build text "$message")
      ;;

    "discord")
      # Discord Webhooks
      # Docs: https://birdie0.github.io/discord-webhooks-guide/
      json_data=$(json_build content "$message" username "Claude Code")
      ;;

    "telegram")
      # Telegram Bot API sendMessage
      # Docs: https://core.telegram.org/bots/api#sendmessage
      if [[ -z "$chat_id" ]]; then
        log_debug "Telegram webhook error: chat_id is required"
        return 1
      fi
      json_data=$(json_build chat_id "$chat_id" text "$message")
      ;;

    "custom"|*)
      # Custom/default format
      if [[ "$format" == "text" ]]; then
        # Text format - will be handled separately below
        json_data=""
      else
        # JSON format (default)
        json_data=$(json_build \
          status "$status" \
          message "$message" \
          timestamp "$timestamp" \
          session_id "$session_id" \
          source "claude-notifications")
      fi
      ;;
  esac

  # Send webhook with error handling
  local http_code
  local curl_output

  if [[ -n "$json_data" ]]; then
    # JSON payload
    curl_output=$(curl -s -w "\n%{http_code}" --max-time 10 -X POST "$url" \
      -H "Content-Type: application/json" \
      "${curl_header_args[@]}" \
      -d "$json_data" 2>&1)
  else
    # Text format (only for custom preset with format=text)
    local text_message="[$status] $message"
    curl_output=$(curl -s -w "\n%{http_code}" --max-time 10 -X POST "$url" \
      -H "Content-Type: text/plain" \
      "${curl_header_args[@]}" \
      -d "$text_message" 2>&1)
  fi

  # Extract HTTP code from last line
  http_code=$(echo "$curl_output" | tail -n 1)

  # Log result
  if [[ "$http_code" =~ ^[2][0-9][0-9]$ ]]; then
    log_debug "Webhook sent successfully (HTTP $http_code)"
  else
    log_debug "Webhook failed: HTTP $http_code, Output: ${curl_output:0:200}"
  fi
}

export -f send_webhook
export -f send_webhook_async
