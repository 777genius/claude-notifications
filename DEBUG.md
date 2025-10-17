# Инструкция по отладке плагина уведомлений

## Установка

Плагин установлен в Claude Code по пути:
- Симлинк: `~/.claude/plugins/repos/claude-notifications` → `/Users/belief/dev/projects/claude/notification_pluign`
- Конфиг: `~/.claude/plugins/config.json` (зарегистрирован как `claude-notifications@local-dev`)

## Как проверить работу плагина

### 1. Перезапустите Claude Code
После установки плагина нужно перезапустить Claude Code, чтобы изменения вступили в силу.

### 2. Проверьте логи
После выполнения любой задачи в Claude Code проверьте файл логов:

```bash
cat /Users/belief/dev/projects/claude/notification_pluign/notification-debug.log
```

Или следите за логами в реальном времени:

```bash
tail -f /Users/belief/dev/projects/claude/notification_pluign/notification-debug.log
```

### 3. Что должно быть в логах

Если плагин работает правильно, вы увидите примерно такие записи:

```
[2025-10-17 15:12:04] === Hook triggered: Stop ===
[2025-10-17 15:12:04] Hook data received: 150 bytes
[2025-10-17 15:12:04] Config loaded successfully
[2025-10-17 15:12:04] Desktop notifications enabled: true
[2025-10-17 15:12:04] Status determined: task_complete
[2025-10-17 15:12:05] Sending desktop notification...
[2025-10-17 15:12:05] Desktop notification sent
[2025-10-17 15:12:05] Playing sound: /System/Library/Sounds/Glass.aiff
[2025-10-17 15:12:05] Sound playback initiated
```

### 4. Если логов нет

Если файл логов пустой или отсутствует, это означает, что:
- Хуки не срабатывают (плагин не подключен к Claude Code)
- Нужно перезапустить Claude Code
- Возможно, есть проблема с путями в конфигурации

### 5. Ручной тест

Вы можете запустить тест вручную:

```bash
/Users/belief/dev/projects/claude/notification_pluign/test_notifications.sh
```

Это должно показать уведомление и воспроизвести звук, а также вывести подробные логи.

## Распространенные проблемы

### Уведомления не появляются

1. Проверьте системные настройки macOS: System Settings → Notifications → Script Editor или terminal-notifier
2. Убедитесь, что terminal-notifier установлен: `which terminal-notifier`
3. Проверьте логи на наличие ошибок

### Звуки не воспроизводятся

1. Проверьте, что звуковые файлы существуют: `ls -l /System/Library/Sounds/Glass.aiff`
2. Убедитесь, что звук включен в конфигурации: `config/config.json` → `notifications.desktop.sound: true`
3. Проверьте логи на наличие сообщения "Sound file does not exist"

### Хуки не срабатывают

1. Перезапустите Claude Code
2. Проверьте, что плагин зарегистрирован: `cat ~/.claude/plugins/config.json`
3. Проверьте, что симлинк существует: `ls -la ~/.claude/plugins/repos/`
4. Убедитесь, что файл hooks.json существует и правильно настроен

## Очистка логов

Чтобы очистить логи перед новым тестом:

```bash
> /Users/belief/dev/projects/claude/notification_pluign/notification-debug.log
```

## Проверка статуса плагина

Вы можете проверить, какие хуки зарегистрированы:

```bash
cat /Users/belief/dev/projects/claude/notification_pluign/hooks/hooks.json
```

Должны быть зарегистрированы хуки: `Stop`, `Notification`, `SubagentStop`
