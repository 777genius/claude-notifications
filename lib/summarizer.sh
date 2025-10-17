#!/bin/bash
# summarizer.sh - Simple logic for task summarization (no AI required)

# Source cross-platform helpers (use local variable to avoid conflicts)
_SUMMARIZER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_SUMMARIZER_DIR}/platform.sh"
source "${_SUMMARIZER_DIR}/cross-platform.sh"

# Generate a summary from transcript data
# Args: $1 - transcript path, $2 - hook data JSON, $3 - status type
generate_summary() {
  local transcript_path="$1"
  local hook_data="$2"
  local status="${3:-task_complete}"
  local max_length=150

  # If transcript doesn't exist, return basic summary
  if [[ ! -f "$transcript_path" ]]; then
    echo "$(get_default_message "$status")"
    return
  fi

  # Read transcript
  local transcript=$(cat "$transcript_path" 2>/dev/null || echo "[]")

  # Generate status-specific summary
  case "$status" in
    question)
      generate_question_summary "$transcript" "$hook_data"
      ;;
    plan_ready)
      generate_plan_summary "$transcript" "$hook_data"
      ;;
    review_complete)
      generate_review_summary "$transcript" "$hook_data"
      ;;
    task_complete)
      generate_task_summary "$transcript" "$hook_data"
      ;;
    *)
      generate_task_summary "$transcript" "$hook_data"
      ;;
  esac
}

# Generate summary for question status
generate_question_summary() {
  local transcript="$1"
  local hook_data="$2"

  # Try to extract the actual question from AskUserQuestion tool (Claude Code format)
  # JSONL format: each line is a separate JSON, use -s to slurp into array
  local question=$(echo "$transcript" | jq -s -r '.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | select(.name == "AskUserQuestion") | .input.questions[0].question' 2>/dev/null | tail -1)

  if [[ -n "$question" ]]; then
    if [[ ${#question} -gt 150 ]]; then
      local truncated=$(echo "$question" | head -c 147 | sed 's/[^ ]*$//')
      echo "${truncated}..."
    else
      echo "$question"
    fi
  else
    # Fallback: look for question marks in recent messages
    local recent_text=$(echo "$transcript" | jq -s -r '.[] | select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' 2>/dev/null | tail -3 | grep "?" | tail -1)
    if [[ -n "$recent_text" ]]; then
      if [[ ${#recent_text} -gt 150 ]]; then
        local truncated=$(echo "$recent_text" | head -c 147 | sed 's/[^ ]*$//')
        echo "${truncated}..."
      else
        echo "$recent_text"
      fi
    else
      echo "Claude needs your input to continue"
    fi
  fi
}

# Generate summary for plan status
generate_plan_summary() {
  local transcript="$1"
  local hook_data="$2"

  # Extract plan from ExitPlanMode tool (Claude Code format)
  # JSONL format: each line is a separate JSON, use -s to slurp into array
  local plan=$(echo "$transcript" | jq -s -r '.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | select(.name == "ExitPlanMode") | .input.plan' 2>/dev/null | tail -1)

  if [[ -n "$plan" ]]; then
    # Get first line or first sentence
    local first_line=$(echo "$plan" | head -1 | sed 's/[#*]//g')
    if [[ ${#first_line} -gt 150 ]]; then
      first_line=$(echo "$first_line" | head -c 147 | sed 's/[^ ]*$//')
      echo "${first_line}..."
    else
      echo "$first_line"
    fi
  else
    echo "Plan is ready for review"
  fi
}

# Generate summary for review status
generate_review_summary() {
  local transcript="$1"
  local hook_data="$2"

  # Look for review-related messages (Claude Code format)
  # JSONL format: each line is a separate JSON, use -s to slurp into array
  local review_msg=$(echo "$transcript" | jq -s -r '.[] | select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' 2>/dev/null | tail -5 | grep -iE "review|анализ|проверка" | tail -1)

  if [[ -n "$review_msg" ]]; then
    if [[ ${#review_msg} -gt 150 ]]; then
      review_msg=$(echo "$review_msg" | head -c 147 | sed 's/[^ ]*$//')
      echo "${review_msg}..."
    else
      echo "$review_msg"
    fi
  else
    # Count files analyzed
    local read_count=$(echo "$transcript" | jq -s -r '.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | select(.name == "Read") | .name' 2>/dev/null | wc -l | tr -d ' ')
    if [[ $read_count -gt 0 ]]; then
      echo "Reviewed $read_count file(s)"
    else
      echo "Code review completed"
    fi
  fi
}

# Generate summary for task completion
generate_task_summary() {
  local transcript="$1"
  local hook_data="$2"

  # DEBUG: Log to file for inspection
  local TEMP_DIR=$(get_temp_dir)
  local debug_log="${TEMP_DIR}/claude_notification_debug.log"
  echo "=== DEBUG $(date) ===" >> "$debug_log"
  echo "Transcript length: ${#transcript}" >> "$debug_log"
  echo "First 500 chars: ${transcript:0:500}" >> "$debug_log"

  # Show sample assistant and tool_use lines
  echo "Sample assistant line:" >> "$debug_log"
  echo "$transcript" | grep -m1 '"type":"assistant"' | jq -c '.' 2>/dev/null >> "$debug_log" || echo "No assistant line found" >> "$debug_log"
  echo "Sample tool_use line:" >> "$debug_log"
  echo "$transcript" | grep -m1 '"type":"tool_use"' | jq -c '.' 2>/dev/null >> "$debug_log" || echo "No tool_use line found" >> "$debug_log"

  # Extract last assistant message (Claude Code format: .type == "assistant", .message.content[] array)
  # JSONL format: each line is a separate JSON, use -s to slurp into array
  local last_message=$(echo "$transcript" | jq -s -r '.[] | select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' 2>/dev/null | tail -1)

  echo "Last message found: '$last_message'" >> "$debug_log"
  echo "Last message length: ${#last_message}" >> "$debug_log"

  # If we have a message, extract first sentence
  if [[ -n "$last_message" ]]; then
    # Get first sentence (up to . ! or ?)
    local first_sentence=$(echo "$last_message" | sed -n '1,/[.!?]/p' | head -1)
    first_sentence=$(echo "$first_sentence" | sed 's/[.!?]$//' | head -c 100)

    # Add tool context if available (Claude Code format)
    # JSONL format: each line is a separate JSON, use -s to slurp into array
    # Count ALL tools in transcript (not limited to last 10) to show accurate operation count
    local tools_used=$(echo "$transcript" | jq -s -r '.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name' 2>/dev/null)

    local edit_count=$(echo "$tools_used" | grep -c "Edit" 2>/dev/null | tr -d '\n' || echo "0")
    local write_count=$(echo "$tools_used" | grep -c "Write" 2>/dev/null | tr -d '\n' || echo "0")
    local bash_count=$(echo "$tools_used" | grep -c "Bash" 2>/dev/null | tr -d '\n' || echo "0")
    local read_count=$(echo "$tools_used" | grep -c "Read" 2>/dev/null | tr -d '\n' || echo "0")

    local actions=""
    [[ $write_count -gt 0 ]] && actions="${actions}Created $write_count file(s). "
    [[ $edit_count -gt 0 ]] && actions="${actions}Edited $edit_count file(s). "
    [[ $bash_count -gt 0 ]] && actions="${actions}Ran $bash_count command(s). "

    if [[ -n "$actions" ]]; then
      echo "DEBUG: Returning with actions" >> "$debug_log"
      local full_message="${first_sentence}. ${actions}"
      # Truncate to 150 chars but don't cut words, add ... if truncated
      if [[ ${#full_message} -gt 150 ]]; then
        full_message=$(echo "$full_message" | head -c 147 | sed 's/[^ ]*$//')
        full_message="${full_message}..."
      fi
      echo "$full_message"
    else
      echo "DEBUG: Returning first sentence only" >> "$debug_log"
      echo "$first_sentence"
    fi
    return
  fi

  # Fallback: count tools and provide generic summary
  echo "DEBUG: Using fallback (no last_message found)" >> "$debug_log"
  # JSONL format: each line is a separate JSON, use -s to slurp into array
  local tool_count=$(echo "$transcript" | jq -s -r '.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name' 2>/dev/null | wc -l | tr -d ' ')
  echo "DEBUG: Tool count: $tool_count" >> "$debug_log"
  if [[ $tool_count -gt 0 ]]; then
    echo "Completed task with $tool_count operations"
  else
    echo "Task completed successfully"
  fi
}

# Get default message for status
get_default_message() {
  local status="$1"

  case "$status" in
    question) echo "Claude has a question for you" ;;
    plan_ready) echo "Plan is ready for review" ;;
    review_complete) echo "Code review completed" ;;
    task_complete) echo "Task completed successfully" ;;
    *) echo "Task completed" ;;
  esac
}

# Clean and format text for notification display
# Args: $1 - text to clean
clean_text() {
  local text="$1"

  # Remove markdown formatting
  text=$(echo "$text" | sed 's/\*\*//g' | sed 's/__//g' | sed 's/`//g')

  # Remove multiple spaces
  text=$(echo "$text" | tr -s ' ')

  # Trim whitespace
  text=$(echo "$text" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  echo "$text"
}

export -f generate_summary
export -f generate_question_summary
export -f generate_plan_summary
export -f generate_review_summary
export -f generate_task_summary
export -f get_default_message
export -f clean_text
