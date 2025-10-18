#!/bin/bash
# test-json-parser.sh - tests for lib/json-parser.sh (cross-platform JSON/JSONL parsing)

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/test-helpers.sh"
source "$PLUGIN_DIR/lib/platform.sh"
source "$PLUGIN_DIR/lib/json-parser.sh"

test_suite "json-parser"

test_jsonl_slurp_empty() {
  local out
  out="$(cat "$SCRIPT_DIR/fixtures/empty.jsonl" 2>/dev/null | jsonl_slurp)"
  # Expect []
  assert_equals "[]" "$out" "jsonl_slurp on empty file returns []"
}

test_jsonl_slurp_invalid_lines() {
  local out
  out="$(cat "$SCRIPT_DIR/fixtures/invalid.jsonl" | jsonl_slurp)"
  # Should parse only valid lines; our fixture has no fully valid lines
  local len
  if command_exists jq; then
    len="$(echo "$out" | jq 'length')"
  else
    # Fallback: rough check for []
    len=0; [[ "$out" != "[]" ]] && len=1
  fi
  assert_equals "0" "$len" "invalid JSONL lines are skipped"
}

test_jsonl_slurp_plan_ready_count_and_tool() {
  local arr
  arr="$(cat "$SCRIPT_DIR/fixtures/plan-ready.jsonl" | jsonl_slurp)"
  local len tool
  len="$(echo "$arr" | jq 'length')"
  tool="$(echo "$arr" | jq -r '.[2].message.content[1].name')"
  assert_equals "3" "$len" "plan-ready.jsonl slurped length == 3"
  assert_equals "ExitPlanMode" "$tool" "3rd line has ExitPlanMode tool"
}

test_jsonl_slurp_question_tool() {
  local arr
  arr="$(cat "$SCRIPT_DIR/fixtures/question.jsonl" | jsonl_slurp)"
  local name
  name="$(echo "$arr" | jq -r '.[1].message.content[1].name')"
  assert_equals "AskUserQuestion" "$name" "question.jsonl has AskUserQuestion tool on 2nd line"
}

test_jsonl_slurp_review_complete_length() {
  local arr len
  arr="$(cat "$SCRIPT_DIR/fixtures/review-complete.jsonl" | jsonl_slurp)"
  len="$(echo "$arr" | jq 'length')"
  assert_equals "4" "$len" "review-complete.jsonl length == 4"
}

test_jsonl_slurp_task_complete_length() {
  local arr len
  arr="$(cat "$SCRIPT_DIR/fixtures/task-complete.jsonl" | jsonl_slurp)"
  len="$(echo "$arr" | jq 'length')"
  # В фикстуре 5 непустых JSON строк, последняя пустая → ожидаем 5
  assert_equals "5" "$len" "task-complete.jsonl length == 5"
}

test_json_get_basic_strings_numbers_bools() {
  local json='{"a":"x","b":42,"c":true,"d":false}'
  local a b c d
  a="$(echo "$json" | json_get ".a" "")"
  b="$(echo "$json" | json_get ".b" "")"
  c="$(echo "$json" | json_get ".c" "")"
  d="$(echo "$json" | json_get ".d" "")"
  assert_equals "x" "$a" "json_get string"
  assert_equals "42" "$b" "json_get number"
  assert_equals "true" "$c" "json_get true"
  assert_equals "false" "$d" "json_get false"
}
test_json_get_null_returns_default() {
  local json='{"k":null}'
  local v
  v="$(echo "$json" | json_get ".k" "def")"
  assert_equals "def" "$v" "null should return default"
}

test_json_get_zero_and_float() {
  local json='{"z":0,"f":3.14}'
  local z f
  z="$(echo "$json" | json_get ".z" "")"
  f="$(echo "$json" | json_get ".f" "")"
  assert_equals "0" "$z" "zero should be preserved"
  assert_equals "3.14" "$f" "float should be preserved"
}

test_json_get_array_value() {
  local json='{"arr":[1,2,3]}'
  local v
  v="$(echo "$json" | json_get ".arr.2" "")"
  assert_equals "3" "$v" "array index value"
}

test_jsonl_slurp_whitespace_lines() {
  local data='\n {"a":1}\n\n {"b":2} \n\n'
  local out len
  out="$(printf "%b" "$data" | jsonl_slurp)"
  len="$(echo "$out" | jq 'length')"
  assert_equals "2" "$len" "whitespace lines should be ignored"
}

test_json_build_odd_number_of_args() {
  local out
  out="$(json_build a "1" b)"  # b без значения → пустая строка
  local a b
  a="$(echo "$out" | jq -r '.a')"
  b="$(echo "$out" | jq -r '.b')"
  assert_equals "1" "$a" "json_build a=1"
  assert_equals "" "$b" "json_build b should default to empty string"
}

test_json_get_nested_and_array_index() {
  local json='{"obj":{"arr":[{"t":"first"},{"t":"second"}]}}'
  local first second
  first="$(echo "$json" | json_get ".obj.arr.0.t" "")"
  second="$(echo "$json" | json_get ".obj.arr.1.t" "")"
  assert_equals "first" "$first" "array index 0"
  assert_equals "second" "$second" "array index 1"
}

test_json_get_missing_with_default() {
  local json='{"k":"v"}'
  local val
  val="$(echo "$json" | json_get ".missing.path" "default")"
  assert_equals "default" "$val" "missing path returns default"
}

test_json_get_object_returns_minified_json() {
  local json='{"obj":{"x":1,"y":[2,3]}}'
  local out
  out="$(echo "$json" | json_get ".obj" "")"
  # Compare via jq normalization to avoid backend diffs
  local norm
  norm="$(echo "$out" | jq -c '.')"
  assert_equals '{"x":1,"y":[2,3]}' "$norm" "object value is JSON"
}

test_json_to_entries_outputs_pairs() {
  local json='{"a":"x","b":true,"c":{"d":1}}'
  local out
  out="$(echo "$json" | json_to_entries)"
  assert_contains "$out" "a: x" "entries include a: x"
  assert_contains "$out" "b: true" "entries include b: true"
  # c is object, printed as JSON
  assert_contains "$out" 'c: {"d":1}' "entries include c JSON"
}

test_json_build_builds_object() {
  local out a b
  out="$(json_build session_id "123" status "ok")"
  a="$(echo "$out" | jq -r '.session_id')"
  b="$(echo "$out" | jq -r '.status')"
  assert_equals "123" "$a" "json_build session_id=123"
  assert_equals "ok" "$b" "json_build status=ok"
}

run_test test_jsonl_slurp_empty "jsonl_slurp: empty file"
run_test test_jsonl_slurp_invalid_lines "jsonl_slurp: invalid lines skipped"
run_test test_jsonl_slurp_plan_ready_count_and_tool "jsonl_slurp: plan-ready count & tool"
run_test test_jsonl_slurp_question_tool "jsonl_slurp: question tool"
run_test test_jsonl_slurp_review_complete_length "jsonl_slurp: review-complete length"
run_test test_jsonl_slurp_task_complete_length "jsonl_slurp: task-complete length"
run_test test_json_get_basic_strings_numbers_bools "json_get: primitives"
run_test test_json_get_null_returns_default "json_get: null→default"
run_test test_json_get_zero_and_float "json_get: zero & float"
run_test test_json_get_array_value "json_get: array value"
run_test test_json_get_nested_and_array_index "json_get: nested + array index"
run_test test_json_get_missing_with_default "json_get: default value"
run_test test_json_get_object_returns_minified_json "json_get: object value"
run_test test_json_to_entries_outputs_pairs "json_to_entries: pairs"
run_test test_json_build_builds_object "json_build: assemble object"
run_test test_json_build_odd_number_of_args "json_build: odd number of args"
run_test test_jsonl_slurp_whitespace_lines "jsonl_slurp: ignore whitespace lines"

print_results


