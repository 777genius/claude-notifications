#!/bin/bash
# test-pretooluse.sh - Test PreToolUse tool_name filtering

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source test helpers
source "$SCRIPT_DIR/test-helpers.sh"

# Source cross-platform helpers
source "${PLUGIN_DIR}/lib/platform.sh"
source "${PLUGIN_DIR}/lib/cross-platform.sh"

# Test configuration
TEMP_DIR=$(get_temp_dir)
TEST_LOG="${PLUGIN_DIR}/notification-debug.log"
TEST_TRANSCRIPT="${TEMP_DIR}/test-pretooluse-transcript.jsonl"
TEST_SESSION="test-pretooluse-session-$$"

# Setup
setup_tests() {
  # Create minimal transcript with some activity
  cat > "$TEST_TRANSCRIPT" << 'EOF'
{"type":"user","message":{"role":"user","content":"Test"},"timestamp":"2025-01-01T00:00:00.000Z"}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Testing"}]},"timestamp":"2025-01-01T00:00:01.000Z"}
EOF

  # Cleanup old locks
  cleanup_test_locks
  rm -f "${TEMP_DIR}/claude-notification-PreToolUse-${TEST_SESSION}.lock"
}

# Teardown
teardown_tests() {
  rm -f "$TEST_TRANSCRIPT"
  rm -f "${TEMP_DIR}/claude-notification-PreToolUse-${TEST_SESSION}.lock"
  cleanup_test_locks
}

# Helper: Run notification-handler.sh with PreToolUse hook data
# Args: tool_name
# Returns: exit code and log output
run_pretooluse_handler() {
  local tool_name="$1"

  # Create hook data JSON
  local hook_data=$(cat <<EOF
{
  "session_id": "${TEST_SESSION}",
  "transcript_path": "${TEST_TRANSCRIPT}",
  "cwd": "/tmp",
  "hook_event_name": "PreToolUse",
  "tool_name": "${tool_name}",
  "tool_input": {},
  "tool_response": {}
}
EOF
)

  # Run handler and capture exit code
  echo "$hook_data" | bash "${PLUGIN_DIR}/hooks/notification-handler.sh" PreToolUse >> "$TEST_LOG" 2>&1
  return $?
}

# Helper: Check if log contains a pattern
log_contains() {
  local pattern="$1"
  grep -qF "$pattern" "$TEST_LOG"
}

# Helper: Clear log for next test
clear_log() {
  # Just remove lock file, logs are appended
  rm -f "${TEMP_DIR}/claude-notification-PreToolUse-${TEST_SESSION}.lock"
}

#
# Test Cases
#

test_exitplanmode_detected() {
  test_case "PreToolUse with ExitPlanMode should set status=plan_ready"
  clear_log

  # Run handler with ExitPlanMode
  run_pretooluse_handler "ExitPlanMode"
  local exit_code=$?

  # Should NOT exit early (exit code 0 means it completed and sent notification)
  assert_equals 0 $exit_code "Handler should complete successfully"

  # Log should show ExitPlanMode was detected
  assert_true "log_contains \"tool_name='ExitPlanMode'\"" "Log should contain tool_name=ExitPlanMode"
  assert_true "log_contains 'plan_ready'" "Log should contain plan_ready status"

  # Should create lock file (notification was sent)
  assert_file_exists "${TEMP_DIR}/claude-notification-PreToolUse-${TEST_SESSION}.lock" "Lock file should be created"
}

test_askuserquestion_detected() {
  test_case "PreToolUse with AskUserQuestion should set status=question"
  clear_log

  # Run handler with AskUserQuestion
  run_pretooluse_handler "AskUserQuestion"
  local exit_code=$?

  assert_equals 0 $exit_code "Handler should complete successfully"

  # Log should show AskUserQuestion was detected
  assert_true "log_contains \"tool_name='AskUserQuestion'\"" "Log should contain tool_name=AskUserQuestion"
  assert_true "log_contains 'question'" "Log should contain question status"

  assert_file_exists "${TEMP_DIR}/claude-notification-PreToolUse-${TEST_SESSION}.lock" "Lock file should be created"
}

test_write_tool_skipped() {
  test_case "PreToolUse with Write should skip (unexpected tool)"
  clear_log

  # Run handler with Write (should not match PreToolUse matcher)
  run_pretooluse_handler "Write"
  local exit_code=$?

  # Should exit early without error
  assert_equals 0 $exit_code "Handler should exit cleanly"

  # Log should show it was skipped
  assert_true "log_contains \"tool_name='Write'\"" "Log should contain tool_name=Write"
  assert_true "log_contains 'unexpected'" "Log should contain 'unexpected' message"

  # Should NOT create lock file (notification was not sent)
  assert_file_not_exists "${TEMP_DIR}/claude-notification-PreToolUse-${TEST_SESSION}.lock" "Lock file should not be created"
}

test_duplicate_prevention() {
  test_case "PreToolUse duplicate detection should work"
  clear_log

  # First call - should succeed
  run_pretooluse_handler "ExitPlanMode"
  local exit_code_1=$?
  assert_equals 0 $exit_code_1 "First call should succeed"
  assert_file_exists "${TEMP_DIR}/claude-notification-PreToolUse-${TEST_SESSION}.lock" "Lock file should exist after first call"

  # Second call (duplicate) - should exit early (log 'Duplicate' may vary per platform)
  run_pretooluse_handler "ExitPlanMode"
  local exit_code_2=$?
  assert_equals 0 $exit_code_2 "Second call should exit cleanly"

  # Log should show duplicate detection (accept different phrasings)
  if log_contains "Duplicate"; then
    assert_true "true" "Duplicate detection logged"
  else
    assert_true "log_contains 'skipping'" "Duplicate detection implied by 'skipping'"
  fi
}

#
# Main test runner
#

main() {
  test_suite "PreToolUse tool_name Filtering"

  setup_tests

  # Run all tests
  test_exitplanmode_detected
  test_askuserquestion_detected
  test_write_tool_skipped
  test_duplicate_prevention

  teardown_tests

  # Report results
  report_results
}

# Run tests
main
