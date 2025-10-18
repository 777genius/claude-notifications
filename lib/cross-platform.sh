#!/bin/bash
# cross-platform.sh - Cross-platform compatibility helpers for macOS/Linux/Windows

# Source platform detection (use local variable to avoid conflicts)
_CROSS_PLATFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_CROSS_PLATFORM_DIR}/platform.sh"

# Get cross-platform temp directory
# Returns: Absolute path to temp directory (without trailing slash)
get_temp_dir() {
  local os=$(detect_os)
  local temp_dir

  case "$os" in
    windows)
      # Windows: try TEMP, TMP, then fallback to /tmp
      temp_dir="${TEMP:-${TMP:-/tmp}}"
      ;;
    *)
      # Linux/macOS: try TMPDIR, then /tmp
      temp_dir="${TMPDIR:-/tmp}"
      ;;
  esac

  # Remove trailing slash if present
  echo "${temp_dir%/}"
}

# Get file modification time (Unix timestamp)
# Args: $1 - file path
# Returns: Unix timestamp of last modification, or 0 if file doesn't exist
get_file_mtime() {
  local file="$1"
  local os=$(detect_os)

  if [[ ! -f "$file" ]]; then
    echo 0
    return
  fi

  case "$os" in
    macos)
      # macOS: use stat -f %m
      stat -f %m "$file" 2>/dev/null || echo 0
      ;;
    linux)
      # Linux: use stat -c %Y
      stat -c %Y "$file" 2>/dev/null || echo 0
      ;;
    windows)
      # Windows (Git Bash/MSYS): try both formats
      stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo 0
      ;;
    *)
      # Unknown: fallback to current time (conservative approach)
      echo 0
      ;;
  esac
}

# Get current Unix timestamp
# Returns: Current Unix timestamp
get_current_timestamp() {
  date +%s
}

# Cleanup old files matching pattern
# Args: $1 - directory, $2 - pattern, $3 - age in seconds
# Example: cleanup_old_files "/tmp" "claude-notification-*.lock" 60
cleanup_old_files() {
  local dir="$1"
  local pattern="$2"
  local max_age="${3:-60}"  # Default: 60 seconds

  if [[ ! -d "$dir" ]]; then
    return
  fi

  local os=$(detect_os)
  local current_time=$(get_current_timestamp)

  # Find files matching pattern
  for file in "$dir"/$pattern; do
    # Skip if glob didn't match any files (bash expands to literal string)
    [[ -e "$file" ]] || continue

    if [[ -f "$file" ]]; then
      local file_mtime=$(get_file_mtime "$file")
      local age=$((current_time - file_mtime))

      if [[ $age -gt $max_age ]]; then
        rm -f "$file" 2>/dev/null || true
      fi
    fi
  done
}

# Check if file is older than N seconds
# Args: $1 - file path, $2 - age threshold in seconds
# Returns: 0 if file is older than threshold, 1 otherwise
is_file_older_than() {
  local file="$1"
  local threshold="${2:-2}"

  if [[ ! -f "$file" ]]; then
    return 1  # File doesn't exist, consider it "not old"
  fi

  local file_mtime=$(get_file_mtime "$file")
  local current_time=$(get_current_timestamp)
  local age=$((current_time - file_mtime))

  if [[ $age -gt $threshold ]]; then
    return 0  # File is older
  else
    return 1  # File is not old enough
  fi
}

# Create lock file with current timestamp
# Args: $1 - lock file path
create_lock_file() {
  local lock_file="$1"
  touch "$lock_file" 2>/dev/null || true
}

# Try to acquire an exclusive lock atomically
# Args: $1 - lock file path
# Returns: 0 if lock acquired, 1 otherwise
try_acquire_lock() {
  local lock_file="$1"
  # Use bash noclobber to create file exclusively (atomic across processes)
  ( set -o noclobber; > "$lock_file" ) 2>/dev/null && return 0 || return 1
}

# Set file modification time to N seconds in the past
# Args: $1 - file path, $2 - seconds in the past (default: 3)
# Returns: 0 on success, 1 on failure
set_file_mtime_past() {
  local file="$1"
  local seconds_ago="${2:-3}"
  local os=$(detect_os)

  if [[ ! -f "$file" ]]; then
    return 1
  fi

  case "$os" in
    macos)
      # macOS: use touch -A (adjust access/modification time)
      # Format: -MMDDhhmm for minutes, or -A for adjusting by seconds
      # touch -A -SSSS adjusts by seconds (negative = past)
      local adjustment=$(printf "%02d%04d" 0 $((seconds_ago * 100)))
      touch -A -"$adjustment" "$file" 2>/dev/null && return 0
      # Fallback to sleep if touch -A fails
      ;;
    linux)
      # Linux: use touch -d
      touch -d "$seconds_ago seconds ago" "$file" 2>/dev/null && return 0
      # Fallback to sleep if touch -d fails
      ;;
    windows)
      # Windows: touch -d might work in Git Bash, try it
      touch -d "$seconds_ago seconds ago" "$file" 2>/dev/null && return 0
      # Fallback to sleep
      ;;
  esac

  # Fallback: sleep (less ideal for tests but works everywhere)
  return 1
}

# Export functions
export -f get_temp_dir
export -f get_file_mtime
export -f get_current_timestamp
export -f cleanup_old_files
export -f is_file_older_than
export -f create_lock_file
export -f try_acquire_lock
export -f set_file_mtime_past

# Convert ISO8601 datetime to Unix epoch seconds (best-effort, cross-platform)
# Args: $1 - ISO8601 string (e.g., 2025-10-18T10:11:50.275Z)
# Echoes epoch seconds or empty on failure
iso_to_epoch() {
  local iso="$1"
  local os=$(detect_os)

  if [[ -z "$iso" ]]; then
    echo ""
    return
  fi

  case "$os" in
    macos)
      # macOS BSD date supports -j -f with %Y-%m-%dT%H:%M:%S%z but 'Z' is UTC; handle both
      # Try with milliseconds and Z
      local epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S.%NZ" "$iso" "+%s" 2>/dev/null || true)
      if [[ -z "$epoch" ]]; then
        # Try without milliseconds
        epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$iso" "+%s" 2>/dev/null || true)
      fi
      echo "$epoch"
      ;;
    linux|windows)
      # GNU date usually supports -d
      # Normalize: replace Z with UTC to help some shells
      local normalized="${iso/Z/+00:00}"
      date -d "$normalized" +%s 2>/dev/null || echo ""
      ;;
    *)
      echo ""
      ;;
  esac
}

export -f iso_to_epoch
