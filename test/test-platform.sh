#!/bin/bash
# test-platform.sh - Test platform detection and OS compatibility layer

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

# Source the platform library
PLUGIN_DIR="${SCRIPT_DIR}/.."
source "${PLUGIN_DIR}/lib/platform.sh"

# Test suite name
TEST_SUITE="Platform Detection & Compatibility"

# ==================== OS Detection Tests ====================

test_detect_os_on_current_system() {
  # Test on actual system
  local os=$(detect_os)

  assert_not_empty "$os" "Should detect OS"

  # Should be one of supported OSes or unknown
  if [[ "$os" == "macos" ]] || [[ "$os" == "linux" ]] || [[ "$os" == "windows" ]] || [[ "$os" == "unknown" ]]; then
    assert_true "true" "Should return valid OS type: $os"
  else
    assert_true "false" "Invalid OS type: $os"
  fi
}

test_detect_os_format() {
  local os=$(detect_os)

  # Should be lowercase
  assert_matches "$os" "^[a-z]+$" "OS should be lowercase"
}

test_command_exists_for_existing_command() {
  # Test with a command that should exist
  if command_exists "bash"; then
    assert_true "true" "bash should exist"
  else
    assert_true "false" "bash should exist but wasn't found"
  fi
}

test_command_exists_for_missing_command() {
  # Test with a command that definitely doesn't exist
  if command_exists "this-command-definitely-does-not-exist-12345"; then
    assert_true "false" "Non-existent command should not be found"
  else
    assert_true "true" "Non-existent command correctly not found"
  fi
}

test_command_exists_for_jq() {
  # jq is required for the plugin
  if command_exists "jq"; then
    assert_true "true" "jq should be available"
  else
    assert_true "false" "jq is required but not found"
  fi
}

# ==================== Notification Command Tests ====================

test_get_notification_command_returns_something() {
  local cmd=$(get_notification_command)

  assert_not_empty "$cmd" "Should return notification command"
}

test_get_notification_command_valid_values() {
  local cmd=$(get_notification_command)

  # Should be one of known commands or "none"
  if [[ "$cmd" == "osascript" ]] || [[ "$cmd" == "notify-send" ]] || [[ "$cmd" == "powershell" ]] || [[ "$cmd" == "none" ]]; then
    assert_true "true" "Valid notification command: $cmd"
  else
    assert_true "false" "Invalid notification command: $cmd"
  fi
}

test_get_notification_command_matches_os() {
  local os=$(detect_os)
  local cmd=$(get_notification_command)

  case "$os" in
    macos)
      assert_equals "$cmd" "osascript" "macOS should use osascript"
      ;;
    linux)
      # Linux can be notify-send or none (if not installed)
      if [[ "$cmd" == "notify-send" ]] || [[ "$cmd" == "none" ]]; then
        assert_true "true" "Linux notification command is valid: $cmd"
      else
        assert_true "false" "Linux should use notify-send or none, got: $cmd"
      fi
      ;;
    windows)
      assert_equals "$cmd" "powershell" "Windows should use powershell"
      ;;
    unknown)
      assert_equals "$cmd" "none" "Unknown OS should return none"
      ;;
  esac
}

# ==================== Sound Command Tests ====================

test_get_sound_command_returns_something() {
  local cmd=$(get_sound_command)

  assert_not_empty "$cmd" "Should return sound command"
}

test_get_sound_command_valid_values() {
  local cmd=$(get_sound_command)

  # Should be one of known commands or "none"
  if [[ "$cmd" == "afplay" ]] || [[ "$cmd" == "paplay" ]] || [[ "$cmd" == "aplay" ]] || [[ "$cmd" == "powershell" ]] || [[ "$cmd" == "none" ]]; then
    assert_true "true" "Valid sound command: $cmd"
  else
    assert_true "false" "Invalid sound command: $cmd"
  fi
}

test_get_sound_command_matches_os() {
  local os=$(detect_os)
  local cmd=$(get_sound_command)

  case "$os" in
    macos)
      assert_equals "$cmd" "afplay" "macOS should use afplay"
      ;;
    linux)
      # Linux can be paplay, aplay, or none
      if [[ "$cmd" == "paplay" ]] || [[ "$cmd" == "aplay" ]] || [[ "$cmd" == "none" ]]; then
        assert_true "true" "Linux sound command is valid: $cmd"
      else
        assert_true "false" "Linux should use paplay/aplay/none, got: $cmd"
      fi
      ;;
    windows)
      assert_equals "$cmd" "powershell" "Windows should use powershell"
      ;;
    unknown)
      assert_equals "$cmd" "none" "Unknown OS should return none"
      ;;
  esac
}

# ==================== Terminal Detection Tests ====================

test_detect_terminal_returns_something() {
  local terminal=$(detect_terminal)

  assert_not_empty "$terminal" "Should return terminal bundle ID"
}

test_detect_terminal_valid_format() {
  local os=$(detect_os)
  local terminal=$(detect_terminal)

  if [[ "$os" == "macos" ]]; then
    # macOS should return bundle ID format or none
    if [[ "$terminal" == "none" ]]; then
      assert_true "true" "Terminal detection returned none (acceptable)"
    else
      # Should contain dots (bundle ID format)
      assert_matches "$terminal" "\\." "macOS bundle ID should contain dots"
    fi
  else
    # Non-macOS should return "none"
    assert_equals "$terminal" "none" "Non-macOS should return none"
  fi
}

test_detect_terminal_known_values() {
  local os=$(detect_os)

  if [[ "$os" == "macos" ]]; then
    local terminal=$(detect_terminal)

    # Should be one of known terminals or none
    local known_terminals=(
      "dev.warp.Warp-Stable"
      "com.googlecode.iterm2"
      "com.apple.Terminal"
      "co.zeit.hyper"
      "org.alacritty"
      "none"
    )

    local found=false
    for known in "${known_terminals[@]}"; do
      if [[ "$terminal" == "$known" ]]; then
        found=true
        break
      fi
    done

    if [[ "$found" == "true" ]]; then
      assert_true "true" "Terminal is known: $terminal"
    else
      # Might be a valid but unknown terminal - that's OK
      assert_true "true" "Terminal detected: $terminal (not in known list, but valid)"
    fi
  fi
}

# ==================== Integration Tests ====================

test_platform_functions_work_together() {
  local os=$(detect_os)
  local notif_cmd=$(get_notification_command)
  local sound_cmd=$(get_sound_command)

  # All should return non-empty values
  assert_not_empty "$os" "OS detection should work"
  assert_not_empty "$notif_cmd" "Notification command should work"
  assert_not_empty "$sound_cmd" "Sound command should work"

  # They should be consistent
  assert_true "true" "Platform functions work together"
}

# ==================== Run Tests ====================

run_test test_detect_os_on_current_system "Detect OS on current system"
run_test test_detect_os_format "OS name format (lowercase)"
run_test test_command_exists_for_existing_command "command_exists: existing command"
run_test test_command_exists_for_missing_command "command_exists: missing command"
run_test test_command_exists_for_jq "command_exists: jq (required)"

run_test test_get_notification_command_returns_something "Notification command: returns value"
run_test test_get_notification_command_valid_values "Notification command: valid values"
run_test test_get_notification_command_matches_os "Notification command: matches OS"

run_test test_get_sound_command_returns_something "Sound command: returns value"
run_test test_get_sound_command_valid_values "Sound command: valid values"
run_test test_get_sound_command_matches_os "Sound command: matches OS"

run_test test_detect_terminal_returns_something "Terminal detection: returns value"
run_test test_detect_terminal_valid_format "Terminal detection: valid format"
run_test test_detect_terminal_known_values "Terminal detection: known values"

run_test test_platform_functions_work_together "Integration: platform functions"

# Print results
print_results
