# Testing Documentation

This project has comprehensive test coverage with automated testing across multiple platforms.

## Test Statistics

Current test coverage:

- **12 test suites** - Separate test files covering different components
- **148 test cases** - Individual test functions across all suites
- **10 source files** - Main plugin code in `lib/` and `hooks/`
- **1,319 lines of code** - Non-comment, non-blank lines
- **11.2 tests per 100 LOC** - Test density metric

### Generate Statistics

```bash
./test/generate-test-stats.sh
```

Output:
```json
{
  "test_suites": 12,
  "test_functions": 148,
  "source_files": 10,
  "lines_of_code": 1319,
  "coverage_ratio": 11.2
}
```

## Test Suites

### Core Functionality Tests

| Suite | Test Count | Description |
|-------|-----------|-------------|
| `test-lock-deduplication.sh` | 17 | Lock-based duplicate prevention |
| `test-status-detection.sh` | 22 | Status detection state machine |
| `test-pretooluse.sh` | 16 | PreToolUse hook handling |
| `test-summary-generation.sh` | 37 | Summary text generation |

### Platform & Integration Tests

| Suite | Test Count | Description |
|-------|-----------|-------------|
| `test-platform.sh` | 19 | Cross-platform compatibility |
| `test-jsonl-parsing.sh` | 19 | JSONL transcript parsing |
| `test-webhook.sh` | 26 | Webhook integration |
| `test-notifier.sh` | 21 | Desktop notification sending |

### Configuration & Session Tests

| Suite | Test Count | Description |
|-------|-----------|-------------|
| `test-config-parsing.sh` | 18 | Configuration validation |
| `test-session-name.sh` | 18 | Session name extraction |
| `test-integration.sh` | 15 | End-to-end workflows |

## Running Tests

### Run All Tests

```bash
./test/run-tests.sh
```

### Run Specific Test Suite

```bash
./test/test-lock-deduplication.sh
```

### CI/CD Testing

Tests run automatically on:
- **macOS** (latest) - via GitHub Actions
- **Linux** (Ubuntu latest) - via GitHub Actions
- **Windows** (Git Bash) - via GitHub Actions

All test suites must pass on all platforms before merging.

## Test Output

### Successful Run

```
╔════════════════════════════════════════════════════════════╗
║  Claude Notifications Plugin - Test Suite                 ║
╚════════════════════════════════════════════════════════════╝

Found 12 test suite(s)

▶ Running: test-lock-deduplication.sh

✓ test_lock_deduplication_single_process
✓ test_lock_deduplication_duplicate_blocked
...
✓ test-lock-deduplication.sh passed

Total test suites:  12
Suites passed:      12
Suites failed:      0

✓ ALL TESTS PASSED!
```

### Failed Run

```
✗ test_example_failure
  Expected: "task_complete"
  Got:      "unknown"

✗ test-example.sh failed

Total test suites:  12
Suites passed:      11
Suites failed:      1

✗ TESTS FAILED
```

## Test Helpers

### Available Assertions

```bash
# Basic assertions
assert_equals "expected" "actual" "description"
assert_not_equals "expected" "actual" "description"
assert_contains "haystack" "needle" "description"
assert_not_contains "haystack" "needle" "description"

# File assertions
assert_file_exists "/path/to/file" "description"
assert_file_not_exists "/path/to/file" "description"

# Exit code assertions
assert_success command "description"
assert_failure command "description"
```

### Test Utilities

```bash
# Lock cleanup
cleanup_test_locks

# Temporary files
create_temp_transcript
create_temp_config

# Mock data
create_mock_hook_data "session_id" "event_type"
```

## Writing New Tests

### Test File Structure

```bash
#!/bin/bash
# test-feature.sh - Tests for feature X

set -eu

# Source test helpers
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${TEST_DIR}/test-helpers.sh"

# Test setup
setup() {
  cleanup_test_locks
}

# Test teardown
teardown() {
  cleanup_test_locks
}

# Test functions
test_feature_behavior() {
  local result=$(call_feature "input")
  assert_equals "expected" "$result" "Feature should return expected value"
}

test_feature_edge_case() {
  local result=$(call_feature "")
  assert_equals "default" "$result" "Feature should handle empty input"
}

# Run tests
run_tests() {
  setup
  test_feature_behavior
  test_feature_edge_case
  teardown
}

run_tests
```

### Best Practices

1. **Isolation** - Each test should be independent
2. **Setup/Teardown** - Clean up test artifacts
3. **Descriptive names** - Use `test_component_behavior` naming
4. **Clear assertions** - Include descriptive failure messages
5. **Edge cases** - Test boundary conditions
6. **Mock data** - Use test helpers to create fixtures

## Coverage Goals

While we don't use code coverage tools (bash coverage is unreliable), we aim for:

- ✅ **100% of public functions** tested
- ✅ **All hook events** covered
- ✅ **All status types** validated
- ✅ **Cross-platform compatibility** verified
- ✅ **Edge cases** handled

## Troubleshooting Tests

### Tests fail locally but pass in CI

- Check platform differences (macOS vs Linux)
- Verify file paths are absolute
- Ensure temp directories are cleaned up

### Tests hang or timeout

- Check for infinite loops
- Look for blocked file operations
- Verify lock files are being cleaned up

### Intermittent failures

- Check for race conditions
- Look for shared state between tests
- Verify cleanup in teardown

## Resources

- Test helpers: `test/test-helpers.sh`
- Test runner: `test/run-tests.sh`
- CI configuration: `.github/workflows/test-*.yml`
