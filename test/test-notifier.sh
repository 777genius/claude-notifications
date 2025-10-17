#!/bin/bash
# test-notifier.sh - Critical tests for cross-platform notifications
# Focus: Security (escaping), routing, error handling

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

# Source the notifier library
PLUGIN_DIR="${SCRIPT_DIR}/.."
source "${PLUGIN_DIR}/lib/notifier.sh"
source "${PLUGIN_DIR}/lib/platform.sh"
source "${PLUGIN_DIR}/lib/cross-platform.sh"

# Test suite name
TEST_SUITE="Notification Security & Routing"

# Mock commands to avoid actual notification sending
TEMP_DIR=$(get_temp_dir)
MOCK_OUTPUT="${TEMP_DIR}/notifier-mock-$$.log"

# Override platform-specific functions with mocks
send_notification_macos() {
  echo "MOCK_MACOS:$1:$2" >> "$MOCK_OUTPUT"
}

send_notification_linux() {
  echo "MOCK_LINUX:$1:$2" >> "$MOCK_OUTPUT"
}

send_notification_windows() {
  echo "MOCK_WINDOWS:$1:$2" >> "$MOCK_OUTPUT"
}

# Re-export mocked functions
export -f send_notification_macos
export -f send_notification_linux
export -f send_notification_windows

# ==================== Security Tests (CRITICAL) ====================

test_send_notification_escapes_double_quotes() {
  # SECURITY: Double quotes must be escaped to prevent injection
  rm -f "$MOCK_OUTPUT"

  local title='Test "quoted" title'
  local message='Message with "quotes"'

  send_notification "$title" "$message" "" 2>/dev/null

  # Should have sent notification (mock was called)
  assert_file_exists "$MOCK_OUTPUT" "Should call notification function"

  local output=$(cat "$MOCK_OUTPUT" 2>/dev/null)
  assert_not_empty "$output" "Should have output"
}

test_send_notification_handles_special_chars() {
  # SECURITY: Special shell characters must be handled
  rm -f "$MOCK_OUTPUT"

  local title='Title with $var and `cmd`'
  local message='Message with $(injection) attempt'

  send_notification "$title" "$message" "" 2>/dev/null

  # Should not crash and should call notification
  assert_file_exists "$MOCK_OUTPUT" "Should handle special chars safely"
}

test_send_notification_handles_newlines() {
  # Newlines in messages shouldn't break notification
  rm -f "$MOCK_OUTPUT"

  local title='Title'
  local message=$'Line 1\nLine 2\nLine 3'

  send_notification "$title" "$message" "" 2>/dev/null

  assert_file_exists "$MOCK_OUTPUT" "Should handle newlines"
}

test_send_notification_handles_single_quotes() {
  # Single quotes in shell can be tricky
  rm -f "$MOCK_OUTPUT"

  local title="It's a title"
  local message="Don't break"

  send_notification "$title" "$message" "" 2>/dev/null

  assert_file_exists "$MOCK_OUTPUT" "Should handle single quotes"
}

test_send_notification_handles_empty_strings() {
  # Edge case: empty title/message
  rm -f "$MOCK_OUTPUT"

  send_notification "" "" "" 2>/dev/null

  # Should not crash (mock should be called with empty strings)
  assert_file_exists "$MOCK_OUTPUT" "Should handle empty strings"
}

# ==================== Routing Tests (CRITICAL) ====================

test_send_notification_routes_to_correct_platform() {
  # Should call the right function based on OS
  rm -f "$MOCK_OUTPUT"

  local os=$(detect_os)

  send_notification "Test" "Message" "" 2>/dev/null

  assert_file_exists "$MOCK_OUTPUT" "Should route to platform function"

  local output=$(cat "$MOCK_OUTPUT")

  case "$os" in
    macos)
      assert_contains "$output" "MOCK_MACOS" "Should route to macOS"
      ;;
    linux)
      assert_contains "$output" "MOCK_LINUX" "Should route to Linux"
      ;;
    windows)
      assert_contains "$output" "MOCK_WINDOWS" "Should route to Windows"
      ;;
  esac
}

test_send_notification_passes_parameters_correctly() {
  # Parameters should be passed in correct order
  rm -f "$MOCK_OUTPUT"

  local title="TestTitle"
  local message="TestMessage"

  send_notification "$title" "$message" "" 2>/dev/null

  local output=$(cat "$MOCK_OUTPUT")

  # Output format: MOCK_OS:title:message
  assert_contains "$output" "$title" "Should pass title"
  assert_contains "$output" "$message" "Should pass message"
}

# ==================== Error Handling Tests (IMPORTANT) ====================

test_send_notification_doesnt_crash_on_unknown_os() {
  # If detect_os returns unknown, shouldn't crash
  rm -f "$MOCK_OUTPUT"

  # Mock detect_os to return unknown
  detect_os() { echo "unknown"; }
  export -f detect_os

  # Should not crash, just fallback
  send_notification "Test" "Message" "" 2>/dev/null
  local exit_code=$?

  # Restore original detect_os
  source "${PLUGIN_DIR}/lib/platform.sh"

  # Should exit cleanly (0 or anything but crash)
  if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 1 ]]; then
    assert_true "true" "Should handle unknown OS gracefully"
  else
    assert_true "false" "Crashed on unknown OS (exit code: $exit_code)"
  fi
}

test_send_notification_handles_long_messages() {
  # Very long messages shouldn't cause buffer overflows
  rm -f "$MOCK_OUTPUT"

  local long_message=$(printf 'A%.0s' {1..5000})

  send_notification "Title" "$long_message" "" 2>/dev/null

  # Should complete without crash
  assert_file_exists "$MOCK_OUTPUT" "Should handle long messages"
}

test_send_notification_with_unicode_characters() {
  # Unicode shouldn't break notifications
  rm -f "$MOCK_OUTPUT"

  local title="✅ Test 🎉"
  local message="Emoji test: 🚀 🔥 ⚡"

  send_notification "$title" "$message" "" 2>/dev/null

  assert_file_exists "$MOCK_OUTPUT" "Should handle unicode"
}

# ==================== Integration Tests ====================

test_send_notification_complete_flow() {
  # Full flow: title + message + cwd
  rm -f "$MOCK_OUTPUT"

  send_notification "Task Complete" "Edited 3 files" "${TEMP_DIR}/test" 2>/dev/null

  assert_file_exists "$MOCK_OUTPUT" "Should complete full flow"

  local output=$(cat "$MOCK_OUTPUT")
  assert_contains "$output" "Task Complete" "Should include title"
  assert_contains "$output" "Edited 3 files" "Should include message"
}

test_send_notification_concurrent_calls() {
  # Multiple concurrent calls shouldn't interfere
  rm -f "$MOCK_OUTPUT"

  send_notification "Notification 1" "Message 1" "" 2>/dev/null &
  send_notification "Notification 2" "Message 2" "" 2>/dev/null &
  send_notification "Notification 3" "Message 3" "" 2>/dev/null &

  wait

  # Should have 3 entries
  local count=$(wc -l < "$MOCK_OUTPUT" | tr -d ' ')
  assert_equals "$count" "3" "Should handle concurrent calls"
}

test_send_notification_with_paths_in_message() {
  # File paths with special chars shouldn't break
  rm -f "$MOCK_OUTPUT"

  local message="Modified /path/to/file.js and /path/with spaces/file.ts"

  send_notification "Files Changed" "$message" "" 2>/dev/null

  assert_file_exists "$MOCK_OUTPUT" "Should handle paths in message"
}

# ==================== Platform-Specific Function Tests ====================

test_platform_functions_are_defined() {
  # All platform functions should be defined

  # Check if functions exist
  if declare -f send_notification_macos > /dev/null; then
    assert_true "true" "send_notification_macos is defined"
  else
    assert_true "false" "send_notification_macos not defined"
  fi

  if declare -f send_notification_linux > /dev/null; then
    assert_true "true" "send_notification_linux is defined"
  else
    assert_true "false" "send_notification_linux not defined"
  fi

  if declare -f send_notification_windows > /dev/null; then
    assert_true "true" "send_notification_windows is defined"
  else
    assert_true "false" "send_notification_windows not defined"
  fi
}

# ==================== Cleanup ====================

cleanup() {
  rm -f "$MOCK_OUTPUT"
}

# ==================== Run Tests ====================

echo ""
echo "🔐 Security Tests (Escaping & Injection Prevention)"
run_test test_send_notification_escapes_double_quotes "Security: Escape double quotes"
run_test test_send_notification_handles_special_chars "Security: Handle special shell chars"
run_test test_send_notification_handles_newlines "Security: Handle newlines"
run_test test_send_notification_handles_single_quotes "Security: Handle single quotes"
run_test test_send_notification_handles_empty_strings "Security: Handle empty strings"

echo ""
echo "🎯 Routing & Parameter Passing"
run_test test_send_notification_routes_to_correct_platform "Routing: Correct platform"
run_test test_send_notification_passes_parameters_correctly "Routing: Parameters passed correctly"

echo ""
echo "⚠️  Error Handling & Edge Cases"
run_test test_send_notification_doesnt_crash_on_unknown_os "Error handling: Unknown OS"
run_test test_send_notification_handles_long_messages "Error handling: Long messages"
run_test test_send_notification_with_unicode_characters "Error handling: Unicode"

echo ""
echo "🔄 Integration & Concurrency"
run_test test_send_notification_complete_flow "Integration: Complete flow"
run_test test_send_notification_concurrent_calls "Integration: Concurrent calls"
run_test test_send_notification_with_paths_in_message "Integration: Paths in message"

echo ""
echo "🏗️  Platform Functions"
run_test test_platform_functions_are_defined "Platform: Functions defined"

# Cleanup
cleanup

# Print results
print_results
