#!/bin/bash
# run-tests.sh - Test runner for claude-notifications plugin

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$TEST_DIR/.." && pwd)"

# Banner
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  Claude Notifications Plugin - Test Suite                 ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Find all test files
TEST_FILES=($(find "$TEST_DIR" -name "test-*.sh" -type f | sort))

if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
  echo -e "${RED}✗ No test files found in $TEST_DIR${NC}"
  exit 1
fi

echo -e "${YELLOW}Found ${#TEST_FILES[@]} test suite(s)${NC}"
echo ""

# Run each test file
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

for test_file in "${TEST_FILES[@]}"; do
  TOTAL_SUITES=$((TOTAL_SUITES + 1))

  test_name=$(basename "$test_file")
  echo -e "${BLUE}▶ Running: $test_name${NC}"
  echo ""

  if bash "$test_file"; then
    PASSED_SUITES=$((PASSED_SUITES + 1))
    echo -e "${GREEN}✓ $test_name passed${NC}"
  else
    FAILED_SUITES=$((FAILED_SUITES + 1))
    echo -e "${RED}✗ $test_name failed${NC}"
  fi

  echo ""
  echo "────────────────────────────────────────────────────────────"
  echo ""
done

# Final report
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  Final Test Results                                        ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Total test suites:  $TOTAL_SUITES"
echo -e "Suites passed:      ${GREEN}$PASSED_SUITES${NC}"
echo -e "Suites failed:      ${RED}$FAILED_SUITES${NC}"
echo ""

if [[ $FAILED_SUITES -eq 0 ]]; then
  echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║${NC}  ✓ ALL TESTS PASSED!                                      ${GREEN}║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  exit 0
else
  echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║${NC}  ✗ SOME TESTS FAILED                                       ${RED}║${NC}"
  echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  exit 1
fi
