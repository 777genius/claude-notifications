#!/bin/bash
# test-error-handler.sh - Демонстрация enhanced error_handler

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Enhanced Error Handler Demonstration                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Create a temporary broken script that will trigger error_handler
TEMP_SCRIPT="/tmp/test-error-handler-$$.sh"
cat > "$TEMP_SCRIPT" <<'SCRIPT'
#!/bin/bash

# Source the handler to get error_handler
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PLUGIN_DIR
LOG_FILE="${PLUGIN_DIR}/notification-debug.log"
log_debug() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

source "${PLUGIN_DIR}/lib/platform.sh"
source "${PLUGIN_DIR}/lib/json-parser.sh"

# Get call stack for error reporting
get_call_stack() {
  local stack=""
  local frame=0
  for ((frame=2; frame<${#FUNCNAME[@]}; frame++)); do
    local func="${FUNCNAME[$frame]}"
    local line="${BASH_LINENO[$frame-1]}"
    if [[ -n "$stack" ]]; then
      stack="$stack <- "
    fi
    stack="$stack$func:$line"
  done
  echo "$stack"
}

# Enhanced error handler
error_handler() {
  local line_no=$1
  local exit_code=$?
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local platform=$(detect_os 2>/dev/null || echo "unknown")
  local json_backend=$(_json_backend 2>/dev/null || echo "unknown")
  local call_stack=$(get_call_stack)
  local hook_event_name="${hook_event:-Stop}"
  local session_id_val="${session_id:-test-session-123}"
  local cwd_val="${cwd:-$(pwd)}"

  # Detailed error report to log
  log_debug "╔════════════════════════════════════════════════════════════╗"
  log_debug "║                    ERROR REPORT                            ║"
  log_debug "╚════════════════════════════════════════════════════════════╝"
  log_debug "Timestamp:        $timestamp"
  log_debug "Platform:         $platform"
  log_debug "JSON Backend:     $json_backend"
  log_debug "Hook:             $hook_event_name"
  log_debug "Session ID:       $session_id_val"
  log_debug "Working Dir:      $cwd_val"
  log_debug "Failed at line:   $line_no"
  log_debug "Command:          $BASH_COMMAND"
  log_debug "Exit code:        $exit_code"
  log_debug "Call stack:       $call_stack"
  log_debug "════════════════════════════════════════════════════════════"

  # Compact error message for Claude Code (stderr)
  cat >&2 <<EOF
[claude-notifications] FAILED: Hook '$hook_event_name' at line $line_no
Command: $BASH_COMMAND (exit code: $exit_code)
Platform: $platform | JSON: $json_backend | Session: ${session_id_val:0:8}
$(if [[ -n "$call_stack" ]]; then echo "Call stack: $call_stack"; fi)
See ${LOG_FILE} for full diagnostics
EOF

  exit 1
}

trap 'error_handler ${LINENO}' ERR
set -eu

# Set some context variables
hook_event="Stop"
session_id="abc-123-def-456"
cwd="/Users/test/project"

# Define a nested function to show call stack
inner_function() {
  # This will fail and trigger error_handler
  cat /this/file/does/not/exist/deliberately.txt
}

outer_function() {
  inner_function
}

# Trigger the error
outer_function
SCRIPT

chmod +x "$TEMP_SCRIPT"

echo "Test: Simulating error with nested function calls"
echo "─────────────────────────────────────────────────────────────"
echo ""
echo "STDERR output (what Claude Code will see):"
echo "─────────────────────────────────────────────────────────────"

# Run the broken script and capture stderr
"$TEMP_SCRIPT" 2>&1 || true

echo ""
echo "─────────────────────────────────────────────────────────────"
echo ""
echo "Detailed log output (notification-debug.log):"
echo "─────────────────────────────────────────────────────────────"

# Show the ERROR REPORT from log
tail -15 "${PLUGIN_DIR}/notification-debug.log" | grep -A 14 "ERROR REPORT" || tail -15 "${PLUGIN_DIR}/notification-debug.log"

# Cleanup
rm -f "$TEMP_SCRIPT"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Key Features Demonstrated:                                 ║"
echo "║  ✓ Detailed error report in log with box formatting        ║"
echo "║  ✓ Compact error message to stderr for Claude Code         ║"
echo "║  ✓ Platform, JSON backend, hook info                       ║"
echo "║  ✓ Call stack showing function hierarchy                   ║"
echo "║  ✓ Session ID and working directory context                ║"
echo "║  ✓ Exit code and exact command that failed                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
