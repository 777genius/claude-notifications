#!/bin/bash
# sound.sh - Cross-platform sound playback

# Source platform detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform.sh"
source "${SCRIPT_DIR}/json-parser.sh"

# Play sound file
# Args: $1 - sound file path, $2 - config JSON
play_sound() {
  local sound_file="$1"
  local config="$2"

  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] play_sound called with: $sound_file" >> "$LOG_FILE" || true

  # Check if sound is enabled in config
  local sound_enabled=$(echo "$config" | json_get ".notifications.desktop.sound" "true")
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sound enabled in config: $sound_enabled" >> "$LOG_FILE" || true
  if [[ "$sound_enabled" != "true" ]]; then
    [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sound disabled, returning" >> "$LOG_FILE" || true
    return 0
  fi

  # Check if sound file exists
  if [[ ! -f "$sound_file" ]]; then
    [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sound file does not exist: $sound_file" >> "$LOG_FILE" || true
    return 0
  fi

  local os=$(detect_os)
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Playing sound on OS: $os" >> "$LOG_FILE" || true

  case "$os" in
    macos)
      play_sound_macos "$sound_file"
      ;;
    linux)
      play_sound_linux "$sound_file"
      ;;
    windows)
      play_sound_windows "$sound_file"
      ;;
    *)
      [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Unknown OS, no sound support" >> "$LOG_FILE" || true
      # No sound support
      return 0
      ;;
  esac
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] play_sound completed" >> "$LOG_FILE" || true

  return 0
}

# macOS sound playback using afplay
play_sound_macos() {
  local sound_file="$1"
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] play_sound_macos: afplay $sound_file" >> "$LOG_FILE" || true
  afplay "$sound_file" 2>/dev/null &
  local afplay_pid=$!
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] afplay started with PID: $afplay_pid" >> "$LOG_FILE" || true

  return 0
}

# Linux sound playback using paplay or aplay
play_sound_linux() {
  local sound_file="$1"

  if command_exists paplay; then
    paplay "$sound_file" 2>/dev/null &
  elif command_exists aplay; then
    aplay "$sound_file" 2>/dev/null &
  elif command_exists ffplay; then
    ffplay -nodisp -autoexit -hide_banner -loglevel quiet "$sound_file" 2>/dev/null &
  fi

  return 0
}

# Windows sound playback using PowerShell
play_sound_windows() {
  local sound_file="$1"

  # Convert to Windows path if needed
  local windows_path=$(cygpath -w "$sound_file" 2>/dev/null || echo "$sound_file")

  powershell.exe -Command "
    \$sound = New-Object System.Media.SoundPlayer('$windows_path')
    \$sound.Play()
  " 2>/dev/null &

  return 0
}

export -f play_sound
export -f play_sound_macos
export -f play_sound_linux
export -f play_sound_windows
