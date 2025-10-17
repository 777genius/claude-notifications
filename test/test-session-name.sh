#!/bin/bash
# test-session-name.sh - Test session name generation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test-helpers.sh"

# Source the session-name library
PLUGIN_DIR="${SCRIPT_DIR}/.."
source "${PLUGIN_DIR}/lib/session-name.sh"

# Test suite name
TEST_SUITE="Session Name Generation"

# ==================== Basic Functionality Tests ====================

test_generate_session_name_with_valid_uuid() {
  # Test with a valid UUID
  local uuid="550e8400-e29b-41d4-a716-446655440000"
  local name=$(generate_session_name "$uuid")

  assert_not_empty "$name" "Should generate name for valid UUID"
  assert_matches "$name" "^[a-z]+-[a-z]+$" "Should match format: adjective-noun"
}

test_generate_session_name_deterministic() {
  # Same UUID should always produce same name
  local uuid="550e8400-e29b-41d4-a716-446655440000"

  local name1=$(generate_session_name "$uuid")
  local name2=$(generate_session_name "$uuid")

  assert_equals "$name1" "$name2" "Same UUID should produce same name"
}

test_generate_session_name_different_uuids() {
  # Different UUIDs should (likely) produce different names
  local uuid1="550e8400-e29b-41d4-a716-446655440000"
  local uuid2="6ba7b810-9dad-11d1-80b4-00c04fd430c8"

  local name1=$(generate_session_name "$uuid1")
  local name2=$(generate_session_name "$uuid2")

  assert_not_equals "$name1" "$name2" "Different UUIDs should produce different names"
}

test_generate_session_name_format_validation() {
  local uuid="550e8400-e29b-41d4-a716-446655440000"
  local name=$(generate_session_name "$uuid")

  # Should contain exactly one hyphen
  local hyphen_count=$(echo "$name" | tr -cd '-' | wc -c | tr -d ' ')
  assert_equals "$hyphen_count" "1" "Should have exactly one hyphen"

  # Split and check parts
  local adjective=$(echo "$name" | cut -d'-' -f1)
  local noun=$(echo "$name" | cut -d'-' -f2)

  assert_not_empty "$adjective" "Should have adjective part"
  assert_not_empty "$noun" "Should have noun part"

  # Both parts should be lowercase letters only
  assert_matches "$adjective" "^[a-z]+$" "Adjective should be lowercase letters"
  assert_matches "$noun" "^[a-z]+$" "Noun should be lowercase letters"
}

# ==================== Edge Cases Tests ====================

test_generate_session_name_with_empty_string() {
  local name=$(generate_session_name "")

  assert_equals "$name" "unknown-session" "Empty string should return unknown-session"
}

test_generate_session_name_with_unknown() {
  local name=$(generate_session_name "unknown")

  assert_equals "$name" "unknown-session" "Unknown should return unknown-session"
}

test_generate_session_name_with_uppercase_uuid() {
  # UUIDs might be uppercase
  local uuid="550E8400-E29B-41D4-A716-446655440000"
  local name=$(generate_session_name "$uuid")

  assert_not_empty "$name" "Should handle uppercase UUID"
  assert_matches "$name" "^[a-z]+-[a-z]+$" "Should still be lowercase output"
}

test_generate_session_name_consistency_with_dashes() {
  # UUID with dashes
  local uuid1="550e8400-e29b-41d4-a716-446655440000"
  # Same UUID without dashes
  local uuid2="550e8400e29b41d4a716446655440000"

  local name1=$(generate_session_name "$uuid1")
  local name2=$(generate_session_name "$uuid2")

  # Both should work (dashes are stripped internally)
  assert_not_empty "$name1" "UUID with dashes should work"
  assert_not_empty "$name2" "UUID without dashes should work"
}

test_generate_session_name_length_reasonable() {
  local uuid="550e8400-e29b-41d4-a716-446655440000"
  local name=$(generate_session_name "$uuid")

  local length=${#name}

  # Should be reasonably short (adjective + dash + noun)
  # Typical: 4-6 chars + 1 + 4-8 chars = 9-15 chars
  assert_less_than "$length" "30" "Name should be reasonably short (<30 chars)"

  # Should have minimum length (at least 3 chars + dash + 3 chars = 7)
  if [[ $length -ge 7 ]]; then
    assert_true "true" "Name should have minimum length (>=7 chars)"
  else
    assert_true "false" "Name too short: $length chars"
  fi
}

# ==================== Variety Tests ====================

test_generate_session_name_variety() {
  # Generate names for different UUIDs to test variety
  local uuids=(
    "550e8400-e29b-41d4-a716-446655440000"
    "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
    "12345678-1234-1234-1234-123456789012"
    "abcdefab-cdef-abcd-efab-cdefabcdefab"
    "11111111-2222-3333-4444-555555555555"
  )

  local names=()
  for uuid in "${uuids[@]}"; do
    local name=$(generate_session_name "$uuid")
    names+=("$name")
  done

  # Check that we got some variety (at least 3 different names from 5 UUIDs)
  local unique_count=$(printf '%s\n' "${names[@]}" | sort -u | wc -l | tr -d ' ')

  if [[ $unique_count -ge 3 ]]; then
    assert_true "true" "Got variety in generated names: $unique_count unique out of ${#uuids[@]}"
  else
    assert_true "false" "Not enough variety: $unique_count unique names from ${#uuids[@]} UUIDs"
  fi
}

# ==================== Run Tests ====================

run_test test_generate_session_name_with_valid_uuid "Generate name: valid UUID"
run_test test_generate_session_name_deterministic "Generate name: deterministic (same UUID)"
run_test test_generate_session_name_different_uuids "Generate name: different UUIDs"
run_test test_generate_session_name_format_validation "Generate name: format validation"

run_test test_generate_session_name_with_empty_string "Edge case: empty string"
run_test test_generate_session_name_with_unknown "Edge case: 'unknown'"
run_test test_generate_session_name_with_uppercase_uuid "Edge case: uppercase UUID"
run_test test_generate_session_name_consistency_with_dashes "Edge case: with/without dashes"
run_test test_generate_session_name_length_reasonable "Edge case: reasonable length"

run_test test_generate_session_name_variety "Variety: multiple UUIDs"

# Print results
print_results
