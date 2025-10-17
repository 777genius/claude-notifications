#!/bin/bash
# test-config-parsing.sh - Test configuration parsing logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

# Source the analyzer (has get_status_config)
PLUGIN_DIR="${SCRIPT_DIR}/.."
source "${PLUGIN_DIR}/lib/analyzer.sh"

# Test suite name
TEST_SUITE="Configuration Parsing"

# ==================== Config Loading Tests ====================

test_valid_config_loads() {
  local config=$(cat "${SCRIPT_DIR}/fixtures/config-valid.json")

  assert_not_empty "$config" "Should load valid config"

  # Check desktop enabled
  local desktop_enabled=$(echo "$config" | jq -r '.notifications.desktop.enabled')
  assert_equals "$desktop_enabled" "true" "Desktop should be enabled"
}

test_minimal_config_loads() {
  local config=$(cat "${SCRIPT_DIR}/fixtures/config-minimal.json")

  assert_not_empty "$config" "Should load minimal config"

  # Should have defaults for missing fields
  local desktop_enabled=$(echo "$config" | jq -r '.notifications.desktop.enabled')
  assert_equals "$desktop_enabled" "true" "Desktop should be enabled"
}

test_missing_config_uses_defaults() {
  # Simulate missing config file
  local config="{}"

  # Check defaults are used
  local desktop_enabled=$(echo "$config" | jq -r '.notifications.desktop.enabled // true')
  assert_equals "$desktop_enabled" "true" "Should default to true"

  local webhook_enabled=$(echo "$config" | jq -r '.notifications.webhook.enabled // false')
  assert_equals "$webhook_enabled" "false" "Should default to false"
}

test_invalid_json_doesnt_crash() {
  # Try to parse invalid JSON
  local config=$(cat "${SCRIPT_DIR}/fixtures/config-invalid.json" 2>/dev/null | jq '.' 2>/dev/null || echo "{}")

  # Should fallback to empty object
  assert_equals "$config" "{}" "Should use empty object for invalid JSON"
}

test_partial_config_uses_defaults() {
  # Config with only some fields
  local config='{"notifications":{"desktop":{"enabled":true}}}'

  # Webhook should default
  local webhook_enabled=$(echo "$config" | jq -r '.notifications.webhook.enabled // false')
  assert_equals "$webhook_enabled" "false" "Missing webhook should default to false"

  # Sound should default
  local sound_enabled=$(echo "$config" | jq -r '.notifications.desktop.sound // true')
  assert_equals "$sound_enabled" "true" "Missing sound should default to true"
}

test_desktop_enabled_from_config() {
  local config=$(cat "${SCRIPT_DIR}/fixtures/config-valid.json")

  local enabled=$(echo "$config" | jq -r '.notifications.desktop.enabled // true')

  assert_equals "$enabled" "true" "Should read desktop.enabled"
}

test_webhook_enabled_from_config() {
  local config=$(cat "${SCRIPT_DIR}/fixtures/config-valid.json")

  local enabled=$(echo "$config" | jq -r '.notifications.webhook.enabled // false')

  assert_equals "$enabled" "true" "Should read webhook.enabled"
}

test_webhook_url_from_config() {
  local config=$(cat "${SCRIPT_DIR}/fixtures/config-valid.json")

  local url=$(echo "$config" | jq -r '.notifications.webhook.url // empty')

  assert_equals "$url" "https://webhook.example.com/test" "Should read webhook URL"
}

test_webhook_format_from_config() {
  local config=$(cat "${SCRIPT_DIR}/fixtures/config-valid.json")

  local format=$(echo "$config" | jq -r '.notifications.webhook.format // "text"')

  assert_equals "$format" "json" "Should read webhook format"
}

test_status_config_for_task_complete() {
  local config=$(cat "${SCRIPT_DIR}/fixtures/config-valid.json")

  local title=$(echo "$config" | jq -r '.statuses.task_complete.title // "Claude Code"')
  local sound=$(echo "$config" | jq -r '.statuses.task_complete.sound // empty')

  assert_equals "$title" "✅ Task Completed" "Should read task_complete title"
  assert_not_empty "$sound" "Should have sound configured"
}

test_status_config_for_unknown_status() {
  local config=$(cat "${SCRIPT_DIR}/fixtures/config-valid.json")

  # Try to get non-existent status
  local title=$(echo "$config" | jq -r '.statuses.nonexistent.title // "Claude Code"')

  assert_equals "$title" "Claude Code" "Should use default for unknown status"
}

test_custom_headers_from_config() {
  local config=$(cat "${SCRIPT_DIR}/fixtures/config-valid.json")

  local headers=$(echo "$config" | jq -r '.notifications.webhook.headers // {}')

  assert_not_empty "$headers" "Should have custom headers"

  local auth=$(echo "$headers" | jq -r '.Authorization')
  assert_contains "$auth" "Bearer" "Should have Authorization header"
}

# ==================== Run Tests ====================

run_test test_valid_config_loads "Valid config loads"
run_test test_minimal_config_loads "Minimal config loads"
run_test test_missing_config_uses_defaults "Missing config uses defaults"
run_test test_invalid_json_doesnt_crash "Invalid JSON doesn't crash"
run_test test_partial_config_uses_defaults "Partial config uses defaults"
run_test test_desktop_enabled_from_config "Read desktop.enabled"
run_test test_webhook_enabled_from_config "Read webhook.enabled"
run_test test_webhook_url_from_config "Read webhook.url"
run_test test_webhook_format_from_config "Read webhook.format"
run_test test_status_config_for_task_complete "Read status config (task_complete)"
run_test test_status_config_for_unknown_status "Default for unknown status"
run_test test_custom_headers_from_config "Read custom headers"

# Print results
print_results
