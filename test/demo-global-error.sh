#!/bin/bash
# demo-global-error.sh - Демонстрация глобального error handler

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Global Error Handler - Format Examples                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

echo "Что изменилось:"
echo ""
echo "1. ✅ ПРАВИЛЬНОЕ имя файла и номер строки:"
echo "   ❌ Было: FAILED at line 75 (строка source в notification-handler.sh)"
echo "   ✅ Стало: FAILED in lib/platform.sh:42 (реальная строка ошибки)"
echo ""

echo "2. ✅ Глобальная защита всех файлов:"
echo "   • hooks/notification-handler.sh"
echo "   • lib/platform.sh"
echo "   • lib/cross-platform.sh"
echo "   • lib/json-parser.sh"
echo "   • lib/analyzer.sh"
echo "   • lib/summarizer.sh"
echo "   • lib/notifier.sh"
echo "   • lib/webhook.sh"
echo "   • lib/sound.sh"
echo "   • lib/session-name.sh"
echo "   • lib/activate-tab.sh"
echo ""

echo "3. ✅ Улучшенный call stack с именами файлов:"
echo "   ❌ Было: analyze_status:98 <- main:67"
echo "   ✅ Стало: analyze_status(analyzer.sh:98) <- main(notification-handler.sh:67)"
echo ""

echo "4. ✅ Единый обработчик для всего плагина:"
echo "   • Одна реализация в lib/error-handler.sh"
echo "   • Автоматическая установка trap при sourcing"
echo "   • Защита от двойной загрузки"
echo ""

echo "─────────────────────────────────────────────────────────────"
echo ""
echo "Пример нового формата ошибки:"
echo ""
echo "STDERR (что видит пользователь в Claude Code):"
echo "─────────────────────────────────────────────────────────────"
cat <<'EOF'
[claude-notifications] FAILED in lib/platform.sh:42
Function: detect_os
Command: uname -s (exit code: 127)
Platform: windows | JSON: powershell | Session: abc-123-
Call stack: detect_os(platform.sh:42) <- analyze_status(analyzer.sh:98) <- main(notification-handler.sh:67)
See /path/to/notification-debug.log for full diagnostics
EOF

echo ""
echo "LOG (notification-debug.log):"
echo "─────────────────────────────────────────────────────────────"
cat <<'EOF'
[2025-10-18 23:30:15] ╔════════════════════════════════════════════════════════════╗
[2025-10-18 23:30:15] ║                    ERROR REPORT                            ║
[2025-10-18 23:30:15] ╚════════════════════════════════════════════════════════════╝
[2025-10-18 23:30:15] Timestamp:        2025-10-18 23:30:15
[2025-10-18 23:30:15] File:             lib/platform.sh
[2025-10-18 23:30:15] Line:             42
[2025-10-18 23:30:15] Function:         detect_os
[2025-10-18 23:30:15] Command:          uname -s
[2025-10-18 23:30:15] Exit code:        127
[2025-10-18 23:30:15] Platform:         windows
[2025-10-18 23:30:15] JSON Backend:     powershell
[2025-10-18 23:30:15] Hook:             Stop
[2025-10-18 23:30:15] Session ID:       abc-123-def-456
[2025-10-18 23:30:15] Working Dir:      C:\Users\User\dev\project
[2025-10-18 23:30:15] Call stack:       detect_os(platform.sh:42) <- analyze_status(analyzer.sh:98) <- main(notification-handler.sh:67)
[2025-10-18 23:30:15] ════════════════════════════════════════════════════════════
EOF

echo ""
echo "─────────────────────────────────────────────────────────────"
echo ""
echo "Преимущества:"
echo ""
echo "✅ Точное место ошибки (файл + строка)"
echo "✅ Функция где произошла ошибка"
echo "✅ Команда которая упала"
echo "✅ Exit code"
echo "✅ Полный call stack с именами файлов"
echo "✅ Платформа, JSON backend, Session ID"
echo "✅ Рабочая директория"
echo "✅ Временная метка"
echo "✅ Единая реализация для всего плагина"
echo "✅ Защита от дублирования"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✓ Глобальный error handler готов!                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
