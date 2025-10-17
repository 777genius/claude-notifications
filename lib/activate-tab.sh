#!/bin/bash
# activate-tab.sh - Activate terminal tab/window by working directory

activate_warp_tab() {
  local target_dir="$1"

  if [[ -z "$target_dir" ]]; then
    # Just activate Warp if no directory specified
    open -a "Warp"
    return
  fi

  # AppleScript to find and activate Warp window with target directory
  osascript <<EOF
    tell application "System Events"
      tell process "Warp"
        set frontmost to true

        -- Try to find window with matching path in title
        set foundWindow to false
        repeat with w in windows
          set windowTitle to name of w as string
          if windowTitle contains "$target_dir" then
            perform action "AXRaise" of w
            set foundWindow to true
            exit repeat
          end if
        end repeat

        -- If not found, just bring Warp to front
        if not foundWindow then
          set frontmost to true
        end if
      end tell
    end tell
EOF
}

activate_iterm_tab() {
  local target_dir="$1"

  if [[ -z "$target_dir" ]]; then
    open -a "iTerm"
    return
  fi

  osascript <<EOF
    tell application "iTerm"
      activate

      -- Try to find tab with target directory
      repeat with w in windows
        repeat with t in tabs of w
          repeat with s in sessions of t
            set currentDir to variable named "PWD" of s
            if currentDir contains "$target_dir" then
              tell w
                set index to 1
              end tell
              tell t
                select
              end tell
              return
            end if
          end repeat
        end repeat
      end repeat
    end tell
EOF
}

activate_terminal_tab() {
  local target_dir="$1"

  if [[ -z "$target_dir" ]]; then
    open -a "Terminal"
    return
  fi

  osascript <<EOF
    tell application "Terminal"
      activate

      -- Try to find window with target directory
      repeat with w in windows
        if (custom title of w contains "$target_dir") or (name of w contains "$target_dir") then
          set index of w to 1
          do script "" in w
          return
        end if
      end repeat
    end tell
EOF
}

# Main function
main() {
  local terminal_type="$1"
  local target_dir="$2"

  case "$terminal_type" in
    *Warp*)
      activate_warp_tab "$target_dir"
      ;;
    *iTerm*)
      activate_iterm_tab "$target_dir"
      ;;
    *Terminal*)
      activate_terminal_tab "$target_dir"
      ;;
    *)
      # Default: just activate the terminal
      osascript -e "tell application id \"$terminal_type\" to activate" 2>/dev/null || true
      ;;
  esac
}

# If called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
