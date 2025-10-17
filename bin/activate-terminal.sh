#!/bin/bash
# activate-terminal.sh - Activate terminal application by bundle ID

BUNDLE_ID="${1:-}"

if [[ -z "$BUNDLE_ID" ]] || [[ "$BUNDLE_ID" == "none" ]]; then
  exit 0
fi

# Activate the application
osascript -e "tell application id \"${BUNDLE_ID}\" to activate" 2>/dev/null || true
