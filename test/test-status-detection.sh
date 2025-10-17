#!/bin/bash
# test-status-detection.sh - Unit tests for status detection state machine

set -euo pipefail

# Get test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$TEST_DIR/.." && pwd)"

source "${TEST_DIR}/test-helpers.sh"
source "${PLUGIN_DIR}/lib/platform.sh"
source "${PLUGIN_DIR}/lib/cross-platform.sh"
source "${PLUGIN_DIR}/lib/analyzer.sh"

# Get cross-platform temp directory
TEMP_DIR=$(get_temp_dir)

# Mock log_debug for testing
log_debug() {
  : # No-op in tests
}

# Create mock JSONL transcript
create_mock_transcript() {
  local output_file="$1"
  shift
  local tools=("$@")

  # Clear file
  > "$output_file"

  # Create JSONL entries for each tool
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
  for i in "${!tools[@]}"; do
    local tool="${tools[$i]}"
    cat >> "$output_file" <<EOF
{"parentUuid":"test-uuid","type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"$tool","input":{}}]},"timestamp":"$timestamp"}
EOF
  done
}

# Create mock transcript with text content
create_mock_transcript_with_text() {
  local output_file="$1"
  local text="$2"

  > "$output_file"

  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
  cat >> "$output_file" <<EOF
{"parentUuid":"test-uuid","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"$text"}]},"timestamp":"$timestamp"}
EOF
}

# ============================================================
# Test Cases
# ============================================================

test_exit_plan_mode_is_last_tool() {
  test_case "ExitPlanMode is last tool → plan_ready"

  local transcript_file="${TEMP_DIR}/test-transcript-$$.jsonl"
  create_mock_transcript "$transcript_file" "Read" "Grep" "ExitPlanMode"

  local transcript=$(cat "$transcript_file")
  local status=$(detect_status_from_tools "$transcript")

  assert_equals "plan_ready" "$status" "Should return plan_ready when ExitPlanMode is last"

  rm -f "$transcript_file"
}

test_exit_plan_mode_with_tools_after() {
  test_case "ExitPlanMode + Write after → task_complete"

  local transcript_file="${TEMP_DIR}/test-transcript-$$.jsonl"
  create_mock_transcript "$transcript_file" "Read" "ExitPlanMode" "Write" "Edit"

  local transcript=$(cat "$transcript_file")
  local status=$(detect_status_from_tools "$transcript")

  assert_equals "task_complete" "$status" "Should return task_complete when tools after ExitPlanMode"

  rm -f "$transcript_file"
}

test_ask_user_question_last() {
  test_case "AskUserQuestion is last → question"

  local transcript_file="${TEMP_DIR}/test-transcript-$$.jsonl"
  create_mock_transcript "$transcript_file" "Read" "Grep" "AskUserQuestion"

  local transcript=$(cat "$transcript_file")
  local status=$(detect_status_from_tools "$transcript")

  assert_equals "question" "$status" "Should return question when AskUserQuestion is last"

  rm -f "$transcript_file"
}

test_active_tool_last() {
  test_case "Active tool (Write) is last → task_complete"

  local transcript_file="${TEMP_DIR}/test-transcript-$$.jsonl"
  create_mock_transcript "$transcript_file" "Read" "Grep" "Write"

  local transcript=$(cat "$transcript_file")
  local status=$(detect_status_from_tools "$transcript")

  assert_equals "task_complete" "$status" "Should return task_complete when active tool is last"

  rm -f "$transcript_file"
}

test_edit_tool_last() {
  test_case "Edit tool is last → task_complete"

  local transcript_file="${TEMP_DIR}/test-transcript-$$.jsonl"
  create_mock_transcript "$transcript_file" "Read" "Edit" "Bash"

  local transcript=$(cat "$transcript_file")
  local status=$(detect_status_from_tools "$transcript")

  assert_equals "task_complete" "$status" "Should return task_complete when Edit is last"

  rm -f "$transcript_file"
}

test_passive_tool_last() {
  test_case "Passive tool (Read) is last → unknown (fallback)"

  local transcript_file="${TEMP_DIR}/test-transcript-$$.jsonl"
  create_mock_transcript "$transcript_file" "Read" "Grep" "Glob"

  local transcript=$(cat "$transcript_file")
  local status=$(detect_status_from_tools "$transcript")

  assert_equals "unknown" "$status" "Should return unknown when only passive tools"

  rm -f "$transcript_file"
}

test_exit_plan_mode_old_history() {
  test_case "ExitPlanMode in old history (>15 messages) → ignored"

  local transcript_file="${TEMP_DIR}/test-transcript-$$.jsonl"

  # Create 20 messages: ExitPlanMode at position 0, then 19 Read tools
  {
    echo '{"parentUuid":"test","type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"ExitPlanMode","input":{}}]},"timestamp":"2025-01-01T00:00:00.000Z"}'
    for i in {1..19}; do
      echo '{"parentUuid":"test","type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read","input":{}}]},"timestamp":"2025-01-01T00:00:00.000Z"}'
    done
  } > "$transcript_file"

  local transcript=$(cat "$transcript_file")
  local status=$(detect_status_from_tools "$transcript")

  # Should ignore old ExitPlanMode (outside 15-message window)
  # Only last 15 messages are Read tools → passive → unknown
  assert_equals "unknown" "$status" "Should ignore ExitPlanMode older than 15 messages"

  rm -f "$transcript_file"
}

test_multiple_exit_plan_modes() {
  test_case "Multiple ExitPlanMode → use latest"

  local transcript_file="${TEMP_DIR}/test-transcript-$$.jsonl"
  create_mock_transcript "$transcript_file" "ExitPlanMode" "Write" "Edit" "ExitPlanMode"

  local transcript=$(cat "$transcript_file")
  local status=$(detect_status_from_tools "$transcript")

  # Latest ExitPlanMode is last → plan_ready
  assert_equals "plan_ready" "$status" "Should use latest ExitPlanMode"

  rm -f "$transcript_file"
}

test_multiple_exit_plan_modes_with_work_after() {
  test_case "Multiple ExitPlanMode + work after latest → task_complete"

  local transcript_file="${TEMP_DIR}/test-transcript-$$.jsonl"
  create_mock_transcript "$transcript_file" "ExitPlanMode" "Write" "ExitPlanMode" "Edit" "Bash"

  local transcript=$(cat "$transcript_file")
  local status=$(detect_status_from_tools "$transcript")

  # Latest ExitPlanMode has tools after → task_complete
  assert_equals "task_complete" "$status" "Should detect work after latest ExitPlanMode"

  rm -f "$transcript_file"
}

test_empty_transcript() {
  test_case "Empty transcript → unknown"

  local transcript=""
  local status=$(detect_status_from_tools "$transcript")

  assert_equals "unknown" "$status" "Should return unknown for empty transcript"
}

test_no_tools_in_transcript() {
  test_case "No tools in transcript → unknown"

  local transcript_file="${TEMP_DIR}/test-transcript-$$.jsonl"
  create_mock_transcript_with_text "$transcript_file" "Just some text without tools"

  local transcript=$(cat "$transcript_file")
  local status=$(detect_status_from_tools "$transcript")

  assert_equals "unknown" "$status" "Should return unknown when no tools found"

  rm -f "$transcript_file"
}

test_tool_categories() {
  test_case "Tool category classification works"

  assert_true "is_tool_in_category 'Write' 'active'" "Write should be in active category"
  assert_true "is_tool_in_category 'Edit' 'active'" "Edit should be in active category"
  assert_true "is_tool_in_category 'Bash' 'active'" "Bash should be in active category"
  assert_true "is_tool_in_category 'AskUserQuestion' 'question'" "AskUserQuestion should be in question category"
  assert_true "is_tool_in_category 'ExitPlanMode' 'planning'" "ExitPlanMode should be in planning category"
  assert_true "is_tool_in_category 'Read' 'passive'" "Read should be in passive category"
  assert_true "is_tool_in_category 'Grep' 'passive'" "Grep should be in passive category"

  # Negative tests
  assert_true "! is_tool_in_category 'Write' 'passive'" "Write should NOT be in passive category"
  assert_true "! is_tool_in_category 'ExitPlanMode' 'active'" "ExitPlanMode should NOT be in active category"
}

# ============================================================
# Integration Tests with analyze_status
# ============================================================

test_analyze_status_stop_event() {
  test_case "analyze_status with Stop event"

  local transcript_file="${TEMP_DIR}/test-transcript-$$.jsonl"
  create_mock_transcript "$transcript_file" "Read" "Write" "Edit"

  local hook_data=$(cat <<EOF
{
  "transcript_path": "$transcript_file",
  "session_id": "test-session",
  "cwd": "${TEMP_DIR}"
}
EOF
)

  local status=$(analyze_status "Stop" "$hook_data")

  assert_equals "task_complete" "$status" "Stop event with active tools should return task_complete"

  rm -f "$transcript_file"
}

test_analyze_status_with_plan() {
  test_case "analyze_status Stop event with ExitPlanMode last"

  local transcript_file="${TEMP_DIR}/test-transcript-$$.jsonl"
  create_mock_transcript "$transcript_file" "Read" "Grep" "ExitPlanMode"

  local hook_data=$(cat <<EOF
{
  "transcript_path": "$transcript_file",
  "session_id": "test-session",
  "cwd": "${TEMP_DIR}"
}
EOF
)

  local status=$(analyze_status "Stop" "$hook_data")

  assert_equals "plan_ready" "$status" "Stop event with ExitPlanMode last should return plan_ready"

  rm -f "$transcript_file"
}

# ============================================================
# Run All Tests
# ============================================================

main() {
  test_suite "Status Detection State Machine"

  # Core state machine tests
  test_exit_plan_mode_is_last_tool
  test_exit_plan_mode_with_tools_after
  test_ask_user_question_last
  test_active_tool_last
  test_edit_tool_last
  test_passive_tool_last
  test_exit_plan_mode_old_history
  test_multiple_exit_plan_modes
  test_multiple_exit_plan_modes_with_work_after

  # Edge cases
  test_empty_transcript
  test_no_tools_in_transcript

  # Tool categorization
  test_tool_categories

  # Integration tests
  test_analyze_status_stop_event
  test_analyze_status_with_plan

  report_results
}

main "$@"
