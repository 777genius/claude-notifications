#!/bin/bash
# demo-error-format.sh - Показывает примеры нового формата ошибок

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Enhanced Error Handler Format Examples                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

echo "1. STDERR Output (что видит пользователь в Claude Code):"
echo "─────────────────────────────────────────────────────────────"
cat <<'EOF'
[claude-notifications] FAILED: Hook 'Stop' at line 125
Command: cat /invalid/path/transcript.jsonl (exit code: 1)
Platform: windows | JSON: powershell | Session: abc-123-
Call stack: analyze_status:98 <- main:67
See /tmp/notification-debug.log for full diagnostics
EOF

echo ""
echo "2. LOG Output (детальная диагностика в notification-debug.log):"
echo "─────────────────────────────────────────────────────────────"
cat <<'EOF'
[2025-10-18 14:23:45] ╔════════════════════════════════════════════════════════════╗
[2025-10-18 14:23:45] ║                    ERROR REPORT                            ║
[2025-10-18 14:23:45] ╚════════════════════════════════════════════════════════════╝
[2025-10-18 14:23:45] Timestamp:        2025-10-18 14:23:45
[2025-10-18 14:23:45] Platform:         windows
[2025-10-18 14:23:45] JSON Backend:     powershell
[2025-10-18 14:23:45] Hook:             Stop
[2025-10-18 14:23:45] Session ID:       abc-123-def-456
[2025-10-18 14:23:45] Working Dir:      C:\Users\User\dev\project
[2025-10-18 14:23:45] Failed at line:   125
[2025-10-18 14:23:45] Command:          cat /invalid/path/transcript.jsonl
[2025-10-18 14:23:45] Exit code:        1
[2025-10-18 14:23:45] Call stack:       analyze_status:98 <- main:67
[2025-10-18 14:23:45] ════════════════════════════════════════════════════════════
EOF

echo ""
echo "─────────────────────────────────────────────────────────────"
echo ""
echo "Преимущества нового формата:"
echo ""
echo "✓ Пользователь сразу видит:"
echo "  • Где произошла ошибка (строка 125)"
echo "  • Что именно упало (cat /invalid/path/transcript.jsonl)"
echo "  • Код ошибки (exit code: 1)"
echo "  • Платформа и JSON backend"
echo "  • Session ID для поиска в логах"
echo ""
echo "✓ В логах есть полная диагностика:"
echo "  • Временная метка"
echo "  • Весь контекст выполнения"
echo "  • Call stack для понимания иерархии вызовов"
echo "  • Рабочая директория"
echo ""
echo "✓ Больше НЕТ пустых 'Plugin hook error:'"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✓ Информативный вывод ошибок готов!                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
