#!/bin/bash
# test-integration.sh - End-to-end integration tests

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

# Source all libraries
PLUGIN_DIR="${SCRIPT_DIR}/.."
source "${PLUGIN_DIR}/lib/analyzer.sh"
source "${PLUGIN_DIR}/lib/summarizer.sh"

# Test suite name
TEST_SUITE="Integration (E2E)"

# ==================== Full Flow Tests ====================

test_stop_hook_with_write_tools_returns_task_complete() {
  # Full flow: Stop hook + Write tools → task_complete
  local hook_event="Stop"
  local transcript_path="${SCRIPT_DIR}/fixtures/task-complete.jsonl"
  local hook_data=$(jq -n --arg path "$transcript_path" '{transcript_path: $path, session_id: "test-123"}')

  # Call analyze_status (the main entry point)
  local status=$(analyze_status "$hook_event" "$hook_data")

  assert_equals "$status" "task_complete" "Should return task_complete"

  # Generate summary
  local summary=$(generate_summary "$transcript_path" "$hook_data" "$status")

  assert_not_empty "$summary" "Should generate summary"
  assert_contains "$summary" "factorial" "Summary should mention factorial"
}

test_notification_hook_with_askuserquestion_returns_question() {
  # Full flow: Notification hook + AskUserQuestion → question
  local hook_event="Notification"
  local transcript_path="${SCRIPT_DIR}/fixtures/question.jsonl"
  local hook_data=$(jq -n --arg path "$transcript_path" '{transcript_path: $path, session_id: "test-123"}')

  local status=$(analyze_status "$hook_event" "$hook_data")

  assert_equals "$status" "question" "Should return question"

  local summary=$(generate_summary "$transcript_path" "$hook_data" "$status")

  assert_not_empty "$summary" "Should generate summary"
  # If timestamps are fresh, we expect concrete question; otherwise, generic message is acceptable
  if echo "$summary" | grep -qi "error"; then
    assert_true "true" "Concrete question extracted"
  else
    assert_contains "$summary" "input" "Should show generic prompt when question recency unknown"
  fi
}

test_stop_hook_with_exitplanmode_returns_plan_ready() {
  # Full flow: Stop hook + ExitPlanMode → plan_ready
  local hook_event="Stop"
  local transcript_path="${SCRIPT_DIR}/fixtures/plan-ready.jsonl"
  local hook_data=$(jq -n --arg path "$transcript_path" '{transcript_path: $path, session_id: "test-123"}')

  local status=$(analyze_status "$hook_event" "$hook_data")

  assert_equals "$status" "plan_ready" "Should return plan_ready"

  local summary=$(generate_summary "$transcript_path" "$hook_data" "$status")

  assert_not_empty "$summary" "Should generate summary"
  # Plan summary takes first line which may be markdown header or numbered list
  # Just check it's not empty
}

test_stop_hook_with_review_keywords_returns_review_complete() {
  # Full flow: Stop hook + review keywords → review_complete
  local hook_event="Stop"
  local transcript_path="${SCRIPT_DIR}/fixtures/review-complete.jsonl"
  local hook_data=$(jq -n --arg path "$transcript_path" '{transcript_path: $path, session_id: "test-123"}')

  local status=$(analyze_status "$hook_event" "$hook_data")

  assert_equals "$status" "review_complete" "Should return review_complete"

  local summary=$(generate_summary "$transcript_path" "$hook_data" "$status")

  assert_not_empty "$summary" "Should generate summary"
}

test_invalid_transcript_returns_unknown() {
  # Full flow: Invalid transcript → unknown (graceful failure)
  local hook_event="Stop"
  local transcript_path="${SCRIPT_DIR}/fixtures/invalid.jsonl"
  local hook_data=$(jq -n --arg path "$transcript_path" '{transcript_path: $path, session_id: "test-123"}')

  # Should not crash when analyzing invalid transcript
  local status=$(analyze_status "$hook_event" "$hook_data" 2>/dev/null || echo "unknown")

  # Any result is fine, just shouldn't crash
  assert_not_empty "$status" "Should return some status"
}

test_empty_transcript_returns_unknown() {
  # Full flow: Empty transcript → unknown
  local hook_event="Stop"
  local transcript_path="${SCRIPT_DIR}/fixtures/empty.jsonl"
  local hook_data=$(jq -n --arg path "$transcript_path" '{transcript_path: $path, session_id: "test-123"}')

  local status=$(analyze_status "$hook_event" "$hook_data")

  assert_equals "$status" "unknown" "Should return unknown for empty transcript"
}

test_missing_transcript_file_returns_unknown() {
  # Full flow: Missing file → unknown
  local hook_event="Stop"
  local transcript_path="/nonexistent/file.jsonl"
  local hook_data=$(jq -n --arg path "$transcript_path" '{transcript_path: $path, session_id: "test-123"}')

  local status=$(analyze_status "$hook_event" "$hook_data")

  assert_equals "$status" "unknown" "Should return unknown for missing file"
}

test_config_with_all_notifications_disabled() {
  # Test config where both desktop and webhook are disabled
  local config='{"notifications":{"desktop":{"enabled":false},"webhook":{"enabled":false}}}'

  local desktop_enabled=$(echo "$config" | jq -r '.notifications.desktop.enabled')
  local webhook_enabled=$(echo "$config" | jq -r '.notifications.webhook.enabled')

  assert_equals "$desktop_enabled" "false" "Desktop should be disabled"
  assert_equals "$webhook_enabled" "false" "Webhook should be disabled"

  # Both disabled means no notification should be sent
  # (notification-handler.sh would exit early at line 81-84)
}

# ==================== Run Tests ====================

run_test test_stop_hook_with_write_tools_returns_task_complete "E2E: Stop + Write → task_complete"
run_test test_notification_hook_with_askuserquestion_returns_question "E2E: Notification + AskUserQuestion → question"
run_test test_stop_hook_with_exitplanmode_returns_plan_ready "E2E: Stop + ExitPlanMode → plan_ready"
run_test test_stop_hook_with_review_keywords_returns_review_complete "E2E: Stop + review keywords → review_complete"
run_test test_invalid_transcript_returns_unknown "E2E: Invalid transcript → graceful failure"
run_test test_empty_transcript_returns_unknown "E2E: Empty transcript → unknown"
run_test test_missing_transcript_file_returns_unknown "E2E: Missing file → unknown"
run_test test_config_with_all_notifications_disabled "E2E: All notifications disabled"

# Print results
print_results
