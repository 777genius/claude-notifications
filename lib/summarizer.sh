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

  # Prefer ONLY a recent AskUserQuestion (avoid stale questions for UI confirmations)
  # 1) Find the last AskUserQuestion with its assistant timestamp within the recent window
  local ask_json=$(printf "%s\n" "$transcript" | jq -s -c '
    [ .[]
      | select(.type == "assistant")
      | . as $m
      | $m.message.content[]?
      | select(.type == "tool_use" and .name == "AskUserQuestion")
      | {question: .input.questions[0].question, ts: ($m.timestamp // empty)}
    ] | last // {}' 2>/dev/null || echo "{}")

  local ask_question=$(echo "$ask_json" | jq -r '.question // empty' 2>/dev/null || echo "")
  local ask_ts=$(echo "$ask_json" | jq -r '.ts // empty' 2>/dev/null || echo "")
  local last_assistant_ts=$(printf "%s\n" "$transcript" | jq -s -r '[.[] | select(.type == "assistant")] | last | .timestamp // empty' 2>/dev/null || echo "")

  local use_ask_question="false"
  if [[ -n "$ask_question" ]] && [[ -n "$ask_ts" ]] && [[ -n "$last_assistant_ts" ]]; then
    local ask_epoch=$(iso_to_epoch "$ask_ts")
    local last_epoch=$(iso_to_epoch "$last_assistant_ts")
    if [[ -n "$ask_epoch" ]] && [[ -n "$last_epoch" ]] && [[ $last_epoch -ge $ask_epoch ]]; then
      local diff=$((last_epoch - ask_epoch))
      # Consider AskUserQuestion valid only if it happened within the last 60 seconds
      if [[ $diff -le 60 ]]; then
        use_ask_question="true"
      fi
    fi
  fi

  if [[ "$use_ask_question" == "true" ]]; then
    if [[ ${#ask_question} -gt 150 ]]; then
      local truncated=$(echo "$ask_question" | head -c 147 | sed 's/[^ ]*$//')
      echo "${truncated}..."
    else
      echo "$ask_question"
    fi
    return
  fi

  # If recency check didn't pass (timestamps missing/old), do NOT try to guess:
  # fall back to textual search (below) or a generic message.

  # 2) Fallback: look for a recent textual question in the last few assistant messages
  local recent_text=$(printf "%s\n" "$transcript" | jq -s -r '.[-8:] | .[] | select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' 2>/dev/null | tail -5 | grep "?" | tail -1)
  if [[ -n "$recent_text" ]]; then
    if [[ ${#recent_text} -gt 150 ]]; then
      local truncated=$(echo "$recent_text" | head -c 147 | sed 's/[^ ]*$//')
      echo "${truncated}..."
    else
      echo "$recent_text"
    fi
    return
  fi

  # 3) Final fallback: generic prompt (covers UI confirmation dialogs not exposed to hooks)
  echo "Claude needs your input to continue"
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
      local noun="file"
      if [[ $read_count -ne 1 ]]; then noun="files"; fi
      echo "Reviewed $read_count $noun"
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

  # Determine time window: from last user message to last assistant message
  # Last user message where content is a plain string (ignore tool_result arrays)
  local last_user_ts=$(echo "$transcript" | jq -s -r '
    [ .[]
      | select(.type == "user")
      | select(.message.content? | type == "string")
    ] | last | .timestamp // empty' 2>/dev/null || echo "")
  local last_assistant_ts=$(echo "$transcript" | jq -s -r '[.[] | select(.type == "assistant")] | last | .timestamp // empty' 2>/dev/null || echo "")
  echo "Last user ts: $last_user_ts, last assistant ts: $last_assistant_ts" >> "$debug_log"

  # Compute duration between last user and last assistant
  local duration_label=""
  if [[ -n "$last_user_ts" ]] && [[ -n "$last_assistant_ts" ]]; then
    local user_epoch=$(iso_to_epoch "$last_user_ts")
    local assistant_epoch=$(iso_to_epoch "$last_assistant_ts")
    if [[ -n "$user_epoch" ]] && [[ -n "$assistant_epoch" ]] && [[ $assistant_epoch -ge $user_epoch ]]; then
      local diff=$((assistant_epoch - user_epoch))
      # Format duration into friendly string
      if [[ $diff -lt 60 ]]; then
        duration_label="Took ${diff}s"
      elif [[ $diff -lt 3600 ]]; then
        local mins=$((diff / 60))
        local secs=$((diff % 60))
        if [[ $secs -gt 0 ]]; then
          duration_label="Took ${mins}m ${secs}s"
        else
          duration_label="Took ${mins}m"
        fi
      else
        local hours=$((diff / 3600))
        local rem=$((diff % 3600))
        local mins=$((rem / 60))
        if [[ $mins -gt 0 ]]; then
          duration_label="Took ${hours}h ${mins}m"
        else
          duration_label="Took ${hours}h"
        fi
      fi
    fi
  fi

  # If we have a message, extract first sentence
  if [[ -n "$last_message" ]]; then
    # Get first sentence (up to . ! or ?)
    local first_sentence=$(echo "$last_message" | sed -n '1,/[.!?]/p' | head -1)
    first_sentence=$(echo "$first_sentence" | sed 's/[.!?]$//' | head -c 100)

    # Add tool context if available (Claude Code format)
    # JSONL format: each line is a separate JSON, use -s to slurp into array
    # Count tools SINCE the last user message to reflect the current response window
    local tools_used
    if [[ -n "$last_user_ts" ]]; then
      tools_used=$(echo "$transcript" | jq -s -r --arg ts "$last_user_ts" '
        .[]
        | select(.type == "assistant")
        | select(.timestamp >= $ts)
        | .message.content[]?
        | select(.type == "tool_use")
        | .name
      ' 2>/dev/null)
    else
      tools_used=$(echo "$transcript" | jq -s -r '.[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name' 2>/dev/null)
    fi

    local edit_count=$(echo "$tools_used" | grep -c "Edit" 2>/dev/null | tr -d '\n' || echo "0")
    local write_count=$(echo "$tools_used" | grep -c "Write" 2>/dev/null | tr -d '\n' || echo "0")
    local bash_count=$(echo "$tools_used" | grep -c "Bash" 2>/dev/null | tr -d '\n' || echo "0")
    local read_count=$(echo "$tools_used" | grep -c "Read" 2>/dev/null | tr -d '\n' || echo "0")

    local actions=""
    if [[ $write_count -gt 0 ]]; then
      local n="file"; if [[ $write_count -ne 1 ]]; then n="files"; fi
      actions="${actions}Created $write_count $n. "
    fi
    if [[ $edit_count -gt 0 ]]; then
      local n="file"; if [[ $edit_count -ne 1 ]]; then n="files"; fi
      actions="${actions}Edited $edit_count $n. "
    fi
    if [[ $bash_count -gt 0 ]]; then
      local n="command"; if [[ $bash_count -ne 1 ]]; then n="commands"; fi
      actions="${actions}Ran $bash_count $n. "
    fi
    # Duration appended at the end
    if [[ -n "$duration_label" ]]; then
      actions="${actions}${duration_label}. "
    fi

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
  # Drop leading markdown headers and list markers
  text=$(echo "$text" | sed 's/^\s*#\+\s*//;s/^\s*[-*•]\s*//')

  # Replace newlines with spaces to avoid empty-looking notifications
  text=$(echo "$text" | tr '\n' ' ')

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
