#!/bin/bash
# generate-test-stats.sh - Generate test statistics for the plugin

set -eu

# Get test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$TEST_DIR/.." && pwd)"

# Count test suites (test-*.sh files)
test_suites=$(find "$TEST_DIR" -name "test-*.sh" -type f | wc -l | tr -d ' ')

# Count individual test functions (test_* functions)
test_functions=$(grep -h "^test_" "$TEST_DIR"/test-*.sh 2>/dev/null | wc -l | tr -d ' ')

# Count source files in lib/ and hooks/
lib_files=$(find "$PLUGIN_DIR/lib" -name "*.sh" -type f 2>/dev/null | wc -l | tr -d ' ')
hook_files=$(find "$PLUGIN_DIR/hooks" -name "*.sh" -type f 2>/dev/null | wc -l | tr -d ' ')
total_source_files=$((lib_files + hook_files))

# Count lines of code in source files
loc_lib=$(find "$PLUGIN_DIR/lib" -name "*.sh" -type f -exec cat {} \; 2>/dev/null | grep -v '^\s*#' | grep -v '^\s*$' | wc -l | tr -d ' ')
loc_hooks=$(find "$PLUGIN_DIR/hooks" -name "*.sh" -type f -exec cat {} \; 2>/dev/null | grep -v '^\s*#' | grep -v '^\s*$' | wc -l | tr -d ' ')
total_loc=$((loc_lib + loc_hooks))

# Calculate test coverage estimate (test functions per 100 LOC)
if [ "$total_loc" -gt 0 ]; then
  coverage_ratio=$(echo "scale=1; ($test_functions * 100) / $total_loc" | bc 2>/dev/null || echo "0")
else
  coverage_ratio="0"
fi

# Output JSON
cat <<EOF
{
  "test_suites": $test_suites,
  "test_functions": $test_functions,
  "source_files": $total_source_files,
  "lines_of_code": $total_loc,
  "coverage_ratio": $coverage_ratio
}
EOF
