#!/bin/bash
# error-handler.sh - Global error handler for all plugin files
#
# This file provides centralized error handling for the entire plugin.
# It should be sourced FIRST in every script/library to ensure consistent
# error reporting with accurate file names and line numbers.
#
# Usage:
#   source "${PLUGIN_DIR}/lib/error-handler.sh"
#
# Features:
# - Automatic trap installation on sourcing
# - Accurate file and line number reporting using BASH_LINENO/BASH_SOURCE
# - Detailed error diagnostics in log
# - Compact error messages to stderr for Claude Code
# - Call stack generation showing function hierarchy

# Prevent multiple loading
if [[ -n "${ERROR_HANDLER_LOADED:-}" ]]; then
  return 0
fi
export ERROR_HANDLER_LOADED=1

# Auto-detect PLUGIN_DIR if not set (lib dir parent)
if [[ -z "${PLUGIN_DIR:-}" ]]; then
  PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  export PLUGIN_DIR
fi

# Auto-set LOG_FILE if not set
if [[ -z "${LOG_FILE:-}" ]]; then
  export LOG_FILE="${PLUGIN_DIR}/notification-debug.log"
fi

# Simple logging function (defined here to avoid circular dependencies)
log_error() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Get call stack for error reporting
# Skips first 2 frames (get_call_stack and global_error_handler)
get_error_call_stack() {
  local stack=""
  local frame=0
  # Start from frame 2 to skip get_error_call_stack and global_error_handler
  for ((frame=2; frame<${#FUNCNAME[@]}; frame++)); do
    local func="${FUNCNAME[$frame]}"
    local line="${BASH_LINENO[$frame-1]}"
    local file="${BASH_SOURCE[$frame]}"
    local file_name="${file##*/}"  # Extract filename only

    if [[ -n "$stack" ]]; then
      stack="$stack <- "
    fi
    stack="$stack$func($file_name:$line)"
  done
  echo "$stack"
}

# Global error handler with accurate file/line detection
global_error_handler() {
  local exit_code=$?
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  # BASH_LINENO[0] = line where error occurred
  # BASH_SOURCE[1] = file where error occurred
  # FUNCNAME[1] = function where error occurred
  local error_line="${BASH_LINENO[0]}"
  local error_file="${BASH_SOURCE[1]}"
  local error_func="${FUNCNAME[1]}"
  local error_cmd="$BASH_COMMAND"

  # Extract just the filename for compact display
  local file_name="${error_file##*/}"
  local file_path_relative="${error_file#${PLUGIN_DIR}/}"  # Relative to plugin root

  # Get platform info (with fallback to avoid nested errors)
  local platform="unknown"
  local json_backend="unknown"
  if declare -f detect_os >/dev/null 2>&1; then
    platform=$(detect_os 2>/dev/null || echo "unknown")
  fi
  if declare -f _json_backend >/dev/null 2>&1; then
    json_backend=$(_json_backend 2>/dev/null || echo "unknown")
  fi

  # Get context variables (with safe fallbacks)
  local hook_event_name="${hook_event:-unknown}"
  local session_id_val="${session_id:-unknown}"
  local cwd_val="${cwd:-$(pwd 2>/dev/null || echo "unknown")}"

  # Get call stack
  local call_stack=$(get_error_call_stack)

  # Detailed error report to log
  log_error "╔════════════════════════════════════════════════════════════╗"
  log_error "║                    ERROR REPORT                            ║"
  log_error "╚════════════════════════════════════════════════════════════╝"
  log_error "Timestamp:        $timestamp"
  log_error "File:             $file_path_relative"
  log_error "Line:             $error_line"
  log_error "Function:         $error_func"
  log_error "Command:          $error_cmd"
  log_error "Exit code:        $exit_code"
  log_error "Platform:         $platform"
  log_error "JSON Backend:     $json_backend"
  log_error "Hook:             $hook_event_name"
  log_error "Session ID:       $session_id_val"
  log_error "Working Dir:      $cwd_val"
  if [[ -n "$call_stack" ]]; then
    log_error "Call stack:       $call_stack"
  fi
  log_error "════════════════════════════════════════════════════════════"

  # Compact error message for Claude Code (stderr)
  # This is what the user sees in Claude Code UI
  cat >&2 <<EOF
[claude-notifications] FAILED in $file_path_relative:$error_line
Function: $error_func
Command: $error_cmd (exit code: $exit_code)
Platform: $platform | JSON: $json_backend | Session: ${session_id_val:0:8}
$(if [[ -n "$call_stack" ]]; then echo "Call stack: $call_stack"; fi)
See ${LOG_FILE} for full diagnostics
EOF

  exit 1
}

# Install trap automatically when this file is sourced
trap 'global_error_handler' ERR

# Set strict mode (exit on error, exit on unset variable, pipefail)
set -euo pipefail
