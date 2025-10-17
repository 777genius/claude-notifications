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

# Export functions
export -f get_temp_dir
export -f get_file_mtime
export -f get_current_timestamp
export -f cleanup_old_files
export -f is_file_older_than
export -f create_lock_file
