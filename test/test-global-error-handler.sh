#!/bin/bash
# test-global-error-handler.sh - Test global error handler across all library files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

echo ""
echo "[1;33m=== Test Suite: Global Error Handler ===[0m"
echo ""

# Test 1: ERROR_HANDLER_LOADED is set after sourcing
test_error_handler_loaded() {
  unset ERROR_HANDLER_LOADED
  source "${PLUGIN_DIR}/lib/error-handler.sh"

  assert_not_empty "$ERROR_HANDLER_LOADED" "ERROR_HANDLER_LOADED should be set"
}

# Test 2: Error handler prevents double-loading
test_error_handler_prevents_double_load() {
  unset ERROR_HANDLER_LOADED

  # Source multiple files that all try to load error-handler.sh
  source "${PLUGIN_DIR}/lib/platform.sh"
  source "${PLUGIN_DIR}/lib/json-parser.sh"
  source "${PLUGIN_DIR}/lib/analyzer.sh"

  # ERROR_HANDLER_LOADED should still be set (loaded once)
  assert_not_empty "$ERROR_HANDLER_LOADED" "Should have ERROR_HANDLER_LOADED set"
}

# Test 3: All library files can be sourced without errors
test_all_lib_files_source_successfully() {
  local success=true

  for lib_file in "${PLUGIN_DIR}"/lib/*.sh; do
    if ! source "$lib_file" 2>/dev/null; then
      success=false
      break
    fi
  done

  assert_true "$success" "All lib files should source successfully"
}

# Test 4: get_error_call_stack function exists
test_get_error_call_stack_exists() {
  source "${PLUGIN_DIR}/lib/error-handler.sh"

  if declare -f get_error_call_stack >/dev/null 2>&1; then
    assert_true "true" "get_error_call_stack function should exist"
  else
    assert_true "false" "get_error_call_stack function should exist"
  fi
}

# Test 5: global_error_handler function exists
test_global_error_handler_exists() {
  source "${PLUGIN_DIR}/lib/error-handler.sh"

  if declare -f global_error_handler >/dev/null 2>&1; then
    assert_true "true" "global_error_handler function should exist"
  else
    assert_true "false" "global_error_handler function should exist"
  fi
}

# Run all tests
echo "Test: ERROR_HANDLER_LOADED is set"
test_error_handler_loaded

echo ""
echo "Test: Prevents double-loading"
test_error_handler_prevents_double_load

echo ""
echo "Test: All lib files source successfully"
test_all_lib_files_source_successfully

echo ""
echo "Test: get_error_call_stack function exists"
test_get_error_call_stack_exists

echo ""
echo "Test: global_error_handler function exists"
test_global_error_handler_exists

print_results
