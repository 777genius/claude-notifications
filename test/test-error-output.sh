#!/bin/bash
# test-error-output.sh - Демонстрация нового формата вывода ошибок

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Error Output Format Test                                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Test 1: Simulate error with missing file
echo "Test 1: Missing file error"
echo "─────────────────────────────────────────────────────────────"

cat <<'EOF' | bash "${PLUGIN_DIR}/hooks/notification-handler.sh" Stop 2>&1 | head -20 || true
{
  "session_id": "test-error-123",
  "transcript_path": "/nonexistent/path/to/transcript.jsonl",
  "cwd": "/Users/test/project"
}
EOF

echo ""
echo "Log output:"
tail -25 "${PLUGIN_DIR}/notification-debug.log"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✓ Error format demonstration complete                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
