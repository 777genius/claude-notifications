#!/bin/bash
# Quick status check for notification plugin

echo "==================================================="
echo "Notification Plugin Status Check"
echo "==================================================="
echo ""

# Check if plugin is registered
echo "1. Plugin Registration:"
if grep -q "claude-notifications" ~/.claude/plugins/config.json 2>/dev/null; then
  echo "   ✅ Plugin registered in Claude Code"
  echo "      $(cat ~/.claude/plugins/config.json | grep -A3 "claude-notifications")"
else
  echo "   ❌ Plugin NOT registered in Claude Code"
fi
echo ""

# Check symlink
echo "2. Plugin Symlink:"
if [ -L ~/.claude/plugins/repos/claude-notifications ]; then
  echo "   ✅ Symlink exists:"
  ls -l ~/.claude/plugins/repos/claude-notifications
else
  echo "   ❌ Symlink does NOT exist"
fi
echo ""

# Check plugin files
echo "3. Plugin Files:"
PLUGIN_DIR="/Users/belief/dev/projects/claude/notification_pluign"
if [ -f "$PLUGIN_DIR/.claude-plugin/plugin.json" ]; then
  echo "   ✅ plugin.json exists"
else
  echo "   ❌ plugin.json missing"
fi

if [ -f "$PLUGIN_DIR/hooks/hooks.json" ]; then
  echo "   ✅ hooks.json exists"
else
  echo "   ❌ hooks.json missing"
fi

if [ -f "$PLUGIN_DIR/hooks/notification-handler.sh" ]; then
  echo "   ✅ notification-handler.sh exists"
else
  echo "   ❌ notification-handler.sh missing"
fi
echo ""

# Check terminal-notifier
echo "4. Notification Tools:"
if command -v terminal-notifier &> /dev/null; then
  echo "   ✅ terminal-notifier installed: $(which terminal-notifier)"
else
  echo "   ⚠️  terminal-notifier not in PATH (will use bundled or osascript)"
fi

if command -v afplay &> /dev/null; then
  echo "   ✅ afplay available: $(which afplay)"
else
  echo "   ❌ afplay not available (sound won't work)"
fi
echo ""

# Check sound files
echo "5. Sound Files:"
SOUND_FILE="/System/Library/Sounds/Glass.aiff"
if [ -f "$SOUND_FILE" ]; then
  echo "   ✅ Default sound file exists: $SOUND_FILE"
else
  echo "   ❌ Default sound file missing: $SOUND_FILE"
fi
echo ""

# Check log file
echo "6. Log File:"
LOG_FILE="$PLUGIN_DIR/notification-debug.log"
if [ -f "$LOG_FILE" ]; then
  LINE_COUNT=$(wc -l < "$LOG_FILE")
  echo "   ✅ Log file exists: $LOG_FILE"
  echo "      Lines: $LINE_COUNT"
  if [ $LINE_COUNT -gt 0 ]; then
    echo "      Last hook triggered:"
    grep "=== Hook triggered:" "$LOG_FILE" | tail -1 | sed 's/^/      /'
  else
    echo "      ⚠️  Log file is empty (hooks may not be firing)"
  fi
else
  echo "   ⚠️  Log file does not exist yet (no hooks triggered)"
fi
echo ""

# Check config
echo "7. Plugin Configuration:"
if [ -f "$PLUGIN_DIR/config/config.json" ]; then
  echo "   ✅ config.json exists"
  DESKTOP_ENABLED=$(cat "$PLUGIN_DIR/config/config.json" | jq -r '.notifications.desktop.enabled')
  SOUND_ENABLED=$(cat "$PLUGIN_DIR/config/config.json" | jq -r '.notifications.desktop.sound')
  echo "      Desktop notifications: $DESKTOP_ENABLED"
  echo "      Sound enabled: $SOUND_ENABLED"
else
  echo "   ❌ config.json missing"
fi
echo ""

echo "==================================================="
echo "Summary:"
echo "==================================================="
echo ""
echo "To test the plugin manually, run:"
echo "  $PLUGIN_DIR/test_notifications.sh"
echo ""
echo "To view logs in real-time:"
echo "  tail -f $LOG_FILE"
echo ""
echo "To clear logs:"
echo "  > $LOG_FILE"
echo ""
echo "⚠️  Remember to RESTART Claude Code after making changes!"
echo ""
