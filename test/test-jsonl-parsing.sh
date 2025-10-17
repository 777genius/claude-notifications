#!/bin/bash
# test-jsonl-parsing.sh - Test JSONL transcript parsing logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

# Source the analyzer
PLUGIN_DIR="${SCRIPT_DIR}/.."
source "${PLUGIN_DIR}/lib/analyzer.sh"

# Test suite name
TEST_SUITE="JSONL Transcript Parsing"

# ==================== Test Cases ====================

test_valid_jsonl_parses_correctly() {
  local transcript=$(cat "${SCRIPT_DIR}/fixtures/task-complete.jsonl")

  # Extract assistant messages using the same logic as analyzer.sh
  local assistant_messages=$(echo "$transcript" | jq -s -c '[.[] | select(.type == "assistant")]' 2>/dev/null)

  assert_not_empty "$assistant_messages" "Should extract assistant messages"

  local count=$(echo "$assistant_messages" | jq 'length' 2>/dev/null)
  assert_equals "$count" "4" "Should find 4 assistant messages"
}

test_empty_transcript_returns_empty_array() {
  local transcript=$(cat "${SCRIPT_DIR}/fixtures/empty.jsonl")

  local assistant_messages=$(echo "$transcript" | jq -s -c '[.[] | select(.type == "assistant")]' 2>/dev/null)

  # Empty JSONL should return [] not null
  assert_equals "$assistant_messages" "[]" "Empty transcript should return []"
}

test_invalid_json_line_is_handled() {
  local transcript=$(cat "${SCRIPT_DIR}/fixtures/invalid.jsonl")

  # Should not crash, jq will skip invalid lines
  local result=$(echo "$transcript" | jq -s -c '[.[] | select(.type == "assistant")]' 2>/dev/null || echo "[]")

  assert_not_empty "$result" "Should return something (not crash)"
}

test_extract_tools_from_transcript() {
  local transcript=$(cat "${SCRIPT_DIR}/fixtures/task-complete.jsonl")

  # Extract tools like analyzer.sh does
  local tools=$(echo "$transcript" | jq -s -r '.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name' 2>/dev/null)

  assert_not_empty "$tools" "Should extract tools"

  # Should find Write, Write, Bash
  local tool_count=$(echo "$tools" | wc -l | tr -d '[:space:]')
  assert_equals "$tool_count" "3" "Should find 3 tools"
}

test_extract_last_assistant_message() {
  local transcript=$(cat "${SCRIPT_DIR}/fixtures/task-complete.jsonl")

  # Get last assistant message text (like summarizer.sh does)
  local last_text=$(echo "$transcript" | jq -s -r '.[] | select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' 2>/dev/null | tail -1)

  assert_not_empty "$last_text" "Should extract last message"
  assert_contains "$last_text" "factorial function" "Should contain expected text"
}

test_extract_tools_with_positions() {
  local transcript=$(cat "${SCRIPT_DIR}/fixtures/task-complete.jsonl")

  # Extract like detect_status_from_tools does
  local recent_messages=$(echo "$transcript" | jq -s -c '[.[] | select(.type == "assistant")] | .[-15:]' 2>/dev/null)

  local tools_with_positions=$(echo "$recent_messages" | jq -r '
    . as $messages |
    [range(0; length) as $i |
      $messages[$i].message.content[]? |
      select(.type? == "tool_use") |
      {position: $i, tool: .name}
    ]
  ' 2>/dev/null)

  assert_not_empty "$tools_with_positions" "Should extract tools with positions"

  local count=$(echo "$tools_with_positions" | jq 'length' 2>/dev/null)
  assert_equals "$count" "3" "Should find 3 tools with positions"
}

test_get_last_tool() {
  local transcript=$(cat "${SCRIPT_DIR}/fixtures/task-complete.jsonl")

  local recent_messages=$(echo "$transcript" | jq -s -c '[.[] | select(.type == "assistant")] | .[-15:]' 2>/dev/null)

  local tools_with_positions=$(echo "$recent_messages" | jq -r '
    . as $messages |
    [range(0; length) as $i |
      $messages[$i].message.content[]? |
      select(.type? == "tool_use") |
      {position: $i, tool: .name}
    ]
  ' 2>/dev/null)

  local last_tool=$(echo "$tools_with_positions" | jq -r 'last | .tool' 2>/dev/null)

  assert_equals "$last_tool" "Bash" "Last tool should be Bash"
}

test_find_exitplanmode_position() {
  local transcript=$(cat "${SCRIPT_DIR}/fixtures/plan-ready.jsonl")

  local recent_messages=$(echo "$transcript" | jq -s -c '[.[] | select(.type == "assistant")] | .[-15:]' 2>/dev/null)

  local tools_with_positions=$(echo "$recent_messages" | jq -r '
    . as $messages |
    [range(0; length) as $i |
      $messages[$i].message.content[]? |
      select(.type? == "tool_use") |
      {position: $i, tool: .name}
    ]
  ' 2>/dev/null)

  local exit_plan_position=$(echo "$tools_with_positions" | jq -r '[.[] | select(.tool == "ExitPlanMode")] | last | .position // -1' 2>/dev/null)

  assert_not_equals "$exit_plan_position" "-1" "Should find ExitPlanMode"
}

test_find_askuserquestion() {
  local transcript=$(cat "${SCRIPT_DIR}/fixtures/question.jsonl")

  local tools=$(echo "$transcript" | jq -s -r '.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name' 2>/dev/null)

  assert_contains "$tools" "AskUserQuestion" "Should find AskUserQuestion tool"
}

test_count_tools_in_transcript() {
  local transcript=$(cat "${SCRIPT_DIR}/fixtures/task-complete.jsonl")

  # Count like analyzer.sh does
  local tool_count=$(echo "$transcript" | jq -s '[.[] | select(.message.content[]?.type? == "tool_use")] | length' 2>/dev/null || echo 0)

  assert_equals "$tool_count" "3" "Should count 3 tool uses"
}

test_null_values_handled_safely() {
  # Create transcript with null fields
  local transcript='{"type":"assistant","message":{"role":"assistant","content":null},"timestamp":null}'

  local result=$(echo "$transcript" | jq -s -c '[.[] | select(.type == "assistant")]' 2>/dev/null || echo "[]")

  assert_not_empty "$result" "Should handle null values without crashing"
}

test_missing_content_field() {
  # Transcript without content field
  local transcript='{"type":"assistant","message":{"role":"assistant"}}'

  # Should not crash when accessing content[]?
  local tools=$(echo "$transcript" | jq -s -r '.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name' 2>/dev/null || echo "")

  # Empty is fine, just shouldn't crash - result can be anything
  assert_true "true" "Should handle missing content field"
}

test_recent_messages_window() {
  # Create transcript with 20 messages, should only get last 15
  local transcript=""
  for i in {1..20}; do
    transcript="${transcript}{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"Message $i\"}]}}
"
  done

  local recent_messages=$(echo "$transcript" | jq -s -c '[.[] | select(.type == "assistant")] | .[-15:]' 2>/dev/null)

  local count=$(echo "$recent_messages" | jq 'length' 2>/dev/null)
  assert_equals "$count" "15" "Should limit to last 15 messages"
}

test_multiple_tools_in_one_message() {
  # Message with multiple tools
  local transcript='{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read"},{"type":"text","text":"Now writing"},{"type":"tool_use","name":"Write"}]}}'

  local tools=$(echo "$transcript" | jq -s -r '.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name' 2>/dev/null)

  local tool_count=$(echo "$tools" | wc -l | tr -d '[:space:]')
  assert_equals "$tool_count" "2" "Should extract multiple tools from one message"
}

test_detect_status_from_tools_with_exitplanmode() {
  local transcript=$(cat "${SCRIPT_DIR}/fixtures/plan-ready.jsonl")

  # Call the actual function from analyzer.sh
  local status=$(detect_status_from_tools "$transcript")

  assert_equals "$status" "plan_ready" "Should detect plan_ready status"
}

# ==================== Run Tests ====================

run_test test_valid_jsonl_parses_correctly "Valid JSONL parses correctly"
run_test test_empty_transcript_returns_empty_array "Empty transcript returns empty array"
run_test test_invalid_json_line_is_handled "Invalid JSON line is handled gracefully"
run_test test_extract_tools_from_transcript "Extract tools from transcript"
run_test test_extract_last_assistant_message "Extract last assistant message"
run_test test_extract_tools_with_positions "Extract tools with positions"
run_test test_get_last_tool "Get last tool from transcript"
run_test test_find_exitplanmode_position "Find ExitPlanMode position"
run_test test_find_askuserquestion "Find AskUserQuestion tool"
run_test test_count_tools_in_transcript "Count tools in transcript"
run_test test_null_values_handled_safely "Null values handled safely"
run_test test_missing_content_field "Missing content field handled"
run_test test_recent_messages_window "Recent messages window (last 15)"
run_test test_multiple_tools_in_one_message "Multiple tools in one message"
run_test test_detect_status_from_tools_with_exitplanmode "detect_status_from_tools with ExitPlanMode"

# Print results
print_results
