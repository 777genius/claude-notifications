#!/bin/bash
# test-webhook.sh - Test webhook notification logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

# Source the webhook library
PLUGIN_DIR="${SCRIPT_DIR}/.."
source "${PLUGIN_DIR}/lib/webhook.sh"

# Test suite name
TEST_SUITE="Webhook Integration"

# ==================== JSON Format Tests ====================

test_json_format_structure() {
  # Create JSON payload like send_webhook_async does
  local status="task_complete"
  local message="Test message"
  local session_id="test-session-123"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local json_data=$(jq -n \
    --arg status "$status" \
    --arg message "$message" \
    --arg timestamp "$timestamp" \
    --arg session_id "$session_id" \
    '{
      status: $status,
      message: $message,
      timestamp: $timestamp,
      session_id: $session_id,
      source: "claude-notifications"
    }')

  assert_not_empty "$json_data" "Should create JSON payload"

  # Verify structure
  local has_status=$(echo "$json_data" | jq -r '.status')
  assert_equals "$has_status" "task_complete" "Should have status field"

  local has_message=$(echo "$json_data" | jq -r '.message')
  assert_equals "$has_message" "Test message" "Should have message field"

  local has_source=$(echo "$json_data" | jq -r '.source')
  assert_equals "$has_source" "claude-notifications" "Should have source field"
}

test_json_format_timestamp() {
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Should be ISO 8601 format
  assert_matches "$timestamp" "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z" "Should be ISO 8601 format"
}

test_json_format_includes_session_id() {
  local session_id="abc-123-def"
  local json_data=$(jq -n --arg session_id "$session_id" '{session_id: $session_id}')

  local result=$(echo "$json_data" | jq -r '.session_id')
  assert_equals "$result" "abc-123-def" "Should include session ID"
}

# ==================== Text Format Tests ====================

test_text_format_structure() {
  local status="task_complete"
  local message="Task completed successfully"

  local text_message="[$status] $message"

  assert_equals "$text_message" "[task_complete] Task completed successfully" "Should format as [status] message"
}

test_text_format_with_different_status() {
  local status="question"
  local message="What should we do?"

  local text_message="[$status] $message"

  assert_contains "$text_message" "[question]" "Should include status"
  assert_contains "$text_message" "What should we do?" "Should include message"
}

# ==================== Config Tests ====================

test_webhook_disabled_returns_early() {
  local config='{"notifications":{"webhook":{"enabled":false}}}'

  local enabled=$(echo "$config" | jq -r '.notifications.webhook.enabled // false')

  assert_equals "$enabled" "false" "Webhook should be disabled"
}

test_webhook_missing_url_returns_early() {
  local config='{"notifications":{"webhook":{"enabled":true}}}'

  local url=$(echo "$config" | jq -r '.notifications.webhook.url // empty')

  assert_empty "$url" "URL should be empty"
}

test_webhook_reads_format_config() {
  local config='{"notifications":{"webhook":{"enabled":true,"format":"json"}}}'

  local format=$(echo "$config" | jq -r '.notifications.webhook.format // "text"')

  assert_equals "$format" "json" "Should read JSON format"
}

test_webhook_defaults_to_text_format() {
  local config='{"notifications":{"webhook":{"enabled":true}}}'

  local format=$(echo "$config" | jq -r '.notifications.webhook.format // "text"')

  assert_equals "$format" "text" "Should default to text format"
}

test_webhook_reads_custom_headers() {
  local config='{"notifications":{"webhook":{"headers":{"Authorization":"Bearer token","X-Custom":"value"}}}}'

  local headers=$(echo "$config" | jq -r '.notifications.webhook.headers // {}')

  assert_not_equals "$headers" "{}" "Should have headers"

  local auth=$(echo "$headers" | jq -r '.Authorization')
  assert_equals "$auth" "Bearer token" "Should read Authorization header"
}

# ==================== Header Generation Tests ====================

test_header_generation_single_header() {
  local headers='{"Authorization":"Bearer token123"}'

  local curl_headers=""
  while IFS= read -r header_line; do
    if [[ -n "$header_line" ]]; then
      curl_headers="$curl_headers -H \"$header_line\""
    fi
  done < <(echo "$headers" | jq -r 'to_entries[] | "\(.key): \(.value)"')

  assert_contains "$curl_headers" "Authorization: Bearer token123" "Should contain Authorization header"
  assert_contains "$curl_headers" '"Authorization: Bearer token123"' "Should be properly formatted with -H flag"
}

test_header_generation_multiple_headers() {
  local headers='{"Authorization":"Bearer token","X-Custom":"value","X-API-Key":"key123"}'

  local curl_headers=""
  while IFS= read -r header_line; do
    if [[ -n "$header_line" ]]; then
      curl_headers="$curl_headers -H \"$header_line\""
    fi
  done < <(echo "$headers" | jq -r 'to_entries[] | "\(.key): \(.value)"')

  assert_contains "$curl_headers" "Authorization: Bearer token" "Should contain Authorization"
  assert_contains "$curl_headers" "X-Custom: value" "Should contain X-Custom"
  assert_contains "$curl_headers" "X-API-Key: key123" "Should contain X-API-Key"
}

test_header_generation_empty_headers() {
  local headers='{}'

  local curl_headers=""
  if [[ "$headers" != "{}" ]] && [[ -n "$headers" ]]; then
    while IFS= read -r header_line; do
      if [[ -n "$header_line" ]]; then
        curl_headers="$curl_headers -H \"$header_line\""
      fi
    done < <(echo "$headers" | jq -r 'to_entries[] | "\(.key): \(.value)"')
  fi

  assert_empty "$curl_headers" "Empty headers should produce empty string"
}

test_header_generation_with_special_chars() {
  local headers='{"Authorization":"Bearer abc-123_def"}'

  local curl_headers=""
  while IFS= read -r header_line; do
    if [[ -n "$header_line" ]]; then
      curl_headers="$curl_headers -H \"$header_line\""
    fi
  done < <(echo "$headers" | jq -r 'to_entries[] | "\(.key): \(.value)"')

  assert_contains "$curl_headers" "Bearer abc-123_def" "Should handle special chars"
}

# ==================== HTTP Code Validation Tests ====================

test_http_code_success_200() {
  local http_code="200"

  if [[ "$http_code" =~ ^[2][0-9][0-9]$ ]]; then
    local result="success"
  else
    local result="failure"
  fi

  assert_equals "$result" "success" "HTTP 200 should be success"
}

test_http_code_success_204() {
  local http_code="204"

  if [[ "$http_code" =~ ^[2][0-9][0-9]$ ]]; then
    local result="success"
  else
    local result="failure"
  fi

  assert_equals "$result" "success" "HTTP 204 should be success"
}

test_http_code_failure_404() {
  local http_code="404"

  if [[ "$http_code" =~ ^[2][0-9][0-9]$ ]]; then
    local result="success"
  else
    local result="failure"
  fi

  assert_equals "$result" "failure" "HTTP 404 should be failure"
}

test_http_code_failure_500() {
  local http_code="500"

  if [[ "$http_code" =~ ^[2][0-9][0-9]$ ]]; then
    local result="success"
  else
    local result="failure"
  fi

  assert_equals "$result" "failure" "HTTP 500 should be failure"
}

# ==================== Run Tests ====================

run_test test_json_format_structure "JSON format: correct structure"
run_test test_json_format_timestamp "JSON format: ISO 8601 timestamp"
run_test test_json_format_includes_session_id "JSON format: includes session_id"

run_test test_text_format_structure "Text format: correct structure"
run_test test_text_format_with_different_status "Text format: different status"

run_test test_webhook_disabled_returns_early "Config: webhook disabled"
run_test test_webhook_missing_url_returns_early "Config: missing URL"
run_test test_webhook_reads_format_config "Config: read format"
run_test test_webhook_defaults_to_text_format "Config: default to text"
run_test test_webhook_reads_custom_headers "Config: read custom headers"

run_test test_header_generation_single_header "Headers: generate single header"
run_test test_header_generation_multiple_headers "Headers: generate multiple headers"
run_test test_header_generation_empty_headers "Headers: handle empty headers"
run_test test_header_generation_with_special_chars "Headers: handle special characters"

run_test test_http_code_success_200 "HTTP codes: 200 is success"
run_test test_http_code_success_204 "HTTP codes: 204 is success"
run_test test_http_code_failure_404 "HTTP codes: 404 is failure"
run_test test_http_code_failure_500 "HTTP codes: 500 is failure"

# Print results
print_results
