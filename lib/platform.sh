#!/bin/bash
# platform.sh - Cross-platform OS detection and compatibility layer

# Detect operating system
detect_os() {
  case "$(uname -s)" in
    Darwin*)
      echo "macos"
      ;;
    Linux*)
      echo "linux"
      ;;
    MINGW*|MSYS*|CYGWIN*)
      echo "windows"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# Check if command exists
command_exists() {
  command -v "$1" &> /dev/null
}

# Get OS-specific notification command
get_notification_command() {
  local os=$(detect_os)

  case "$os" in
    macos)
      echo "osascript"
      ;;
    linux)
      if command_exists notify-send; then
        echo "notify-send"
      else
        echo "none"
      fi
      ;;
    windows)
      echo "powershell"
      ;;
    *)
      echo "none"
      ;;
  esac
}

# Get OS-specific sound command
get_sound_command() {
  local os=$(detect_os)

  case "$os" in
    macos)
      echo "afplay"
      ;;
    linux)
      if command_exists paplay; then
        echo "paplay"
      elif command_exists aplay; then
        echo "aplay"
      else
        echo "none"
      fi
      ;;
    windows)
      echo "powershell"
      ;;
    *)
      echo "none"
      ;;
  esac
}

# Detect current terminal application
detect_terminal() {
  local os=$(detect_os)

  if [[ "$os" == "macos" ]]; then
    # Try to detect terminal from parent process (if ps is available)
    if command_exists ps; then
      local parent_pid=$(ps -o ppid= -p $$ 2>/dev/null | tr -d ' ')
      if [[ -n "$parent_pid" ]]; then
        local parent_name=$(ps -o comm= -p $parent_pid 2>/dev/null)

        case "$parent_name" in
          *Warp*)
            echo "dev.warp.Warp-Stable"
            return
            ;;
          *iTerm*)
            echo "com.googlecode.iterm2"
            return
            ;;
          *Terminal*)
            echo "com.apple.Terminal"
            return
            ;;
          *Hyper*)
            echo "co.zeit.hyper"
            return
            ;;
          *Alacritty*)
            echo "org.alacritty"
            return
            ;;
        esac
      fi
    fi

    # Fallback: try TERM_PROGRAM env variable
    case "$TERM_PROGRAM" in
      WarpTerminal)
        echo "dev.warp.Warp-Stable"
        ;;
      iTerm.app)
        echo "com.googlecode.iterm2"
        ;;
      Apple_Terminal)
        echo "com.apple.Terminal"
        ;;
      Hyper)
        echo "co.zeit.hyper"
        ;;
      *)
        # Default to Terminal.app if can't detect
        echo "com.apple.Terminal"
        ;;
    esac
  elif [[ "$os" == "linux" ]]; then
    # Linux: try environment variables
    case "$TERM_PROGRAM" in
      vscode)
        echo "vscode"
        ;;
      *)
        # Fallback to generic linux terminal
        echo "linux-terminal"
        ;;
    esac
  else
    # Windows/Unknown: return none (terminal activation not supported)
    echo "none"
  fi
}

# Export functions for use in other scripts
export -f detect_os
export -f command_exists
export -f get_notification_command
export -f get_sound_command
export -f detect_terminal
