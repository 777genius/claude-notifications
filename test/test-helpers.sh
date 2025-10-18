#!/bin/bash
# test-helpers.sh - Helper functions for testing

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Assertion functions
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Expected '$expected', got '$actual'}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ "$expected" == "$actual" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $message"
    echo -e "  Expected: ${GREEN}$expected${NC}"
    echo -e "  Actual:   ${RED}$actual${NC}"
    return 1
  fi
}

assert_file_exists() {
  local file="$1"
  local message="${2:-File should exist: $file}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ -f "$file" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $message"
    return 1
  fi
}

assert_file_not_exists() {
  local file="$1"
  local message="${2:-File should not exist: $file}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ ! -f "$file" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $message"
    return 1
  fi
}

assert_true() {
  local condition="$1"
  local message="${2:-Condition should be true}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if eval "$condition"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $message"
    return 1
  fi
}

# Test suite functions
test_suite() {
  local suite_name="$1"
  echo ""
  echo -e "${YELLOW}=== Test Suite: $suite_name ===${NC}"
  echo ""
}

test_case() {
  local test_name="$1"
  echo ""
  echo "Test: $test_name"
}

# Cleanup function
cleanup_test_locks() {
  # Source cross-platform helpers if not already loaded
  if ! command -v get_temp_dir &> /dev/null; then
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "${SCRIPT_DIR}/../lib/platform.sh"
    source "${SCRIPT_DIR}/../lib/cross-platform.sh"
  fi

  local TEMP_DIR=$(get_temp_dir)
  # Use find to avoid glob expansion issues with quotes
  find "${TEMP_DIR}" -name "claude-notification-test-*.lock" -type f -delete 2>/dev/null || true
}

# Report results
report_results() {
  echo ""
  echo -e "${YELLOW}=== Test Results ===${NC}"
  echo -e "Tests run:    $TESTS_RUN"
  echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
  echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
  echo ""

  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    return 0
  else
    echo -e "${RED}✗ Some tests failed${NC}"
    return 1
  fi
}

# Mock notification sender (for testing)
mock_send_notification() {
  local output_file="${1:-/tmp/test-notifications.log}"
  echo "$(date +%s)|$$|notification_sent" >> "$output_file"
}

# Additional assertion functions for new tests
assert_not_empty() {
  local value="$1"
  local message="${2:-Value should not be empty}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ -n "$value" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $message"
    return 1
  fi
}

assert_empty() {
  local value="$1"
  local message="${2:-Value should be empty}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ -z "$value" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $message"
    echo -e "  Value: ${RED}$value${NC}"
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-Should contain '$needle'}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if echo "$haystack" | grep -qF -- "$needle"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $message"
    echo -e "  Haystack: ${RED}$haystack${NC}"
    echo -e "  Needle:   ${GREEN}$needle${NC}"
    return 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-Should not contain '$needle'}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if echo "$haystack" | grep -qF -- "$needle"; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $message"
    echo -e "  Haystack: ${RED}$haystack${NC}"
    echo -e "  Needle:   ${GREEN}$needle${NC}"
    return 1
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $message"
    return 0
  fi
}

assert_matches() {
  local value="$1"
  local pattern="$2"
  local message="${3:-Should match pattern '$pattern'}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if echo "$value" | grep -qE "$pattern"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $message"
    echo -e "  Value:   ${RED}$value${NC}"
    echo -e "  Pattern: ${GREEN}$pattern${NC}"
    return 1
  fi
}

assert_not_matches() {
  local value="$1"
  local pattern="$2"
  local message="${3:-Should not match pattern '$pattern'}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if echo "$value" | grep -qE "$pattern"; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $message"
    echo -e "  Value:   ${RED}$value${NC}"
    echo -e "  Pattern: ${GREEN}$pattern${NC}"
    return 1
  else
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $message"
    return 0
  fi
}

assert_not_equals() {
  local value1="$1"
  local value2="$2"
  local message="${3:-Values should not be equal}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ "$value1" != "$value2" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $message"
    echo -e "  Both values: ${RED}$value1${NC}"
    return 1
  fi
}

assert_less_than() {
  local value="$1"
  local threshold="$2"
  local message="${3:-$value should be < $threshold}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [[ $value -lt $threshold ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓${NC} $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗${NC} $message"
    echo -e "  Value:     ${RED}$value${NC}"
    echo -e "  Threshold: ${GREEN}$threshold${NC}"
    return 1
  fi
}

# Helper to run a test function with descriptive output
run_test() {
  local test_func="$1"
  local test_name="$2"

  echo ""
  echo "Test: $test_name"
  $test_func || true  # Don't exit on failure
}

# Alias for backward compatibility
print_results() {
  report_results
}

# Stub log_debug for testing (analyzer.sh uses this)
log_debug() {
  : # No-op for tests, can be enabled for debugging
  # echo "[TEST DEBUG] $*" >&2
}
