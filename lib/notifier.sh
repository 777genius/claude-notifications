#!/bin/bash
# notifier.sh - Cross-platform desktop notifications

# Source platform detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform.sh"

# Send desktop notification
# Args: $1 - title, $2 - message, $3 - working directory (optional)
send_notification() {
  local title="$1"
  local message="$2"
  local cwd="${3:-}"
  local os=$(detect_os)

  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] send_notification called for OS: $os" >> "$LOG_FILE"

  # Escape special characters for shell
  title=$(echo "$title" | sed 's/"/\\"/g')
  message=$(echo "$message" | sed 's/"/\\"/g')

  case "$os" in
    macos)
      [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Calling send_notification_macos" >> "$LOG_FILE"
      send_notification_macos "$title" "$message" "$cwd"
      ;;
    linux)
      [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Calling send_notification_linux" >> "$LOG_FILE"
      send_notification_linux "$title" "$message"
      ;;
    windows)
      [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Calling send_notification_windows" >> "$LOG_FILE"
      send_notification_windows "$title" "$message"
      ;;
    *)
      [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Unknown OS, using fallback" >> "$LOG_FILE"
      echo "[Notification] $title: $message" >&2
      ;;
  esac
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] send_notification completed" >> "$LOG_FILE"
}

# Ensure notifier is set up (runs once)
ensure_notifier_setup() {
  local os=$(detect_os)

  if [[ "$os" != "macos" ]]; then
    return 0
  fi

  # Check if setup has been run
  local setup_marker="${SCRIPT_DIR}/../.notifier_setup_done"
  if [[ -f "$setup_marker" ]]; then
    return 0
  fi

  # Run setup script
  local setup_script="${SCRIPT_DIR}/../bin/setup-notifier.sh"
  if [[ -x "$setup_script" ]]; then
    "$setup_script" > /dev/null 2>&1 || true
  fi

  # Mark as done
  touch "$setup_marker"
}

# macOS notification using terminal-notifier or osascript
send_notification_macos() {
  local title="$1"
  local message="$2"
  local cwd="${3:-}"

  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] send_notification_macos: title='$title'" >> "$LOG_FILE"

  # Ensure setup has been run (only once)
  ensure_notifier_setup

  # Validate title and message to prevent empty notifications
  if [[ -z "$title" ]] || [[ "$title" =~ ^[[:space:]]*$ ]]; then
    title="Claude Code"
    [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Empty title detected, using fallback: $title" >> "$LOG_FILE"
  fi

  if [[ -z "$message" ]] || [[ "$message" =~ ^[[:space:]]*$ ]]; then
    message="Notification"
    [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Empty message detected, using fallback: $message" >> "$LOG_FILE"
  fi

  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Final title: '$title' (length: ${#title})" >> "$LOG_FILE"
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Final message: '$message' (length: ${#message})" >> "$LOG_FILE"

  # Detect terminal bundle ID for click action
  local terminal_bundle=$(detect_terminal)
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Terminal bundle: $terminal_bundle" >> "$LOG_FILE"

  # Try system terminal-notifier first
  if command -v terminal-notifier &> /dev/null; then
    [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Using system terminal-notifier" >> "$LOG_FILE"
    if [[ -n "$terminal_bundle" ]] && [[ "$terminal_bundle" != "none" ]]; then
      local activate_script="${SCRIPT_DIR}/../bin/activate-terminal.sh"
      [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Executing: terminal-notifier -title '$title' -message '$message' -execute '$activate_script $terminal_bundle'" >> "$LOG_FILE"
      terminal-notifier -title "$title" -message "$message" -execute "$activate_script $terminal_bundle" 2>/dev/null &
    else
      [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Executing: terminal-notifier -title '$title' -message '$message'" >> "$LOG_FILE"
      terminal-notifier -title "$title" -message "$message" 2>/dev/null &
    fi
    [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] System terminal-notifier command executed" >> "$LOG_FILE"
    return 0
  fi

  # Try bundled terminal-notifier
  local bundled_notifier="${SCRIPT_DIR}/../bin/terminal-notifier.app/Contents/MacOS/terminal-notifier"
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking bundled notifier: $bundled_notifier" >> "$LOG_FILE"
  if [[ -x "$bundled_notifier" ]]; then
    [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Using bundled terminal-notifier" >> "$LOG_FILE"
    if [[ -n "$terminal_bundle" ]] && [[ "$terminal_bundle" != "none" ]]; then
      local activate_script="${SCRIPT_DIR}/../bin/activate-terminal.sh"
      [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Executing: $bundled_notifier -title '$title' -message '$message' -execute '$activate_script $terminal_bundle'" >> "$LOG_FILE"
      "$bundled_notifier" -title "$title" -message "$message" -execute "$activate_script $terminal_bundle" 2>/dev/null &
    else
      [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Executing: $bundled_notifier -title '$title' -message '$message'" >> "$LOG_FILE"
      "$bundled_notifier" -title "$title" -message "$message" 2>/dev/null &
    fi
    [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Bundled terminal-notifier command executed" >> "$LOG_FILE"
    return 0
  fi

  # Fallback to osascript (may not work in some terminals like Warp)
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Using osascript fallback" >> "$LOG_FILE"
  osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null &
  [[ -n "${LOG_FILE:-}" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] osascript command executed" >> "$LOG_FILE"
}

# Linux notification using notify-send
send_notification_linux() {
  local title="$1"
  local message="$2"
  local icon="$3"

  if command_exists notify-send; then
    if [[ -n "$icon" ]] && [[ -f "$icon" ]]; then
      notify-send -i "$icon" -u normal "$title" "$message" 2>/dev/null &
    else
      notify-send -u normal "$title" "$message" 2>/dev/null &
    fi
  else
    echo "[Notification] $title: $message" >&2
  fi
}

# Windows notification using PowerShell
send_notification_windows() {
  local title="$1"
  local message="$2"

  # Use PowerShell to create a Windows toast notification
  powershell.exe -Command "
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

    \$template = @\"
    <toast>
      <visual>
        <binding template='ToastText02'>
          <text id='1'>$title</text>
          <text id='2'>$message</text>
        </binding>
      </visual>
    </toast>
\"@

    \$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    \$xml.LoadXml(\$template)
    \$toast = New-Object Windows.UI.Notifications.ToastNotification \$xml
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show(\$toast)
  " 2>/dev/null &
}

export -f send_notification
export -f send_notification_macos
export -f send_notification_linux
export -f send_notification_windows
