#!/bin/bash
# run-coverage.sh - Wrapper to run all tests and collect coverage

# Get directories
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$TEST_DIR/.." && pwd)"

# Export variables so bashcov can find them
export BASHCOV_COMMAND_NAME="claude-notifications-tests"
export RUBYOPT="-W0"  # Suppress Ruby warnings

# Find all test files
TEST_FILES=($(find "$TEST_DIR" -name "test-*.sh" -type f | sort))

echo "Running ${#TEST_FILES[@]} test suites with coverage..."
echo ""

# Execute each test file (bashcov will track sourced files)
for test_file in "${TEST_FILES[@]}"; do
  test_name=$(basename "$test_file" .sh)
  echo "▶ Running: $test_name"

  # Run the test (bashcov tracks sourced files from lib/ and hooks/)
  bash "$test_file" > /dev/null 2>&1 || echo "  ⚠ $test_name had errors (expected in coverage mode)"
done

echo ""
echo "Coverage collection complete!"
exit 0
