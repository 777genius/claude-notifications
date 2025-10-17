# Webhook Integrations

Send Claude Code notifications to your favorite messaging platform.

## Supported Platforms

- [Slack](slack.md) ✅
- [Discord](discord.md) ✅
- [Telegram](telegram.md) ✅
- [Custom Format](custom.md) ✅

## Quick Start

1. Choose your platform from the list above
2. Follow the setup guide
3. Update `config/config.json` with webhook settings
4. Enable webhooks: `"enabled": true`

## Testing

Use the test script to verify your webhook:

```bash
./test/webhook-tester.sh --preset slack --url "YOUR_WEBHOOK_URL" --message "Test"
```

## Configuration Example

Edit `config/config.json`:

```json
{
  "notifications": {
    "webhook": {
      "enabled": true,
      "preset": "slack",
      "url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL",
      "chat_id": "",
      "format": "json"
    }
  }
}
```

### Configuration Fields

| Field | Required | Description | Example |
|-------|----------|-------------|---------|
| `enabled` | Yes | Enable/disable webhook notifications | `true` or `false` |
| `preset` | Yes | Webhook format preset | `"slack"`, `"discord"`, `"telegram"`, `"custom"` |
| `url` | Yes | Webhook endpoint URL | `"https://hooks.slack.com/..."` |
| `chat_id` | Telegram only | Telegram chat ID | `"123456789"` |
| `format` | Custom only | Payload format | `"json"` or `"text"` |
| `headers` | Custom only | Custom HTTP headers | `{"Authorization": "Bearer ..."}` |

## Preset Formats

### Slack
```json
{
  "text": "✅ Task Completed: Summary..."
}
```

### Discord
```json
{
  "content": "✅ Task Completed: Summary...",
  "username": "Claude Code"
}
```

### Telegram
```json
{
  "chat_id": "123456789",
  "text": "✅ Task Completed: Summary..."
}
```

### Custom
```json
{
  "status": "task_complete",
  "message": "Summary...",
  "timestamp": "2025-01-17T12:34:56Z",
  "session_id": "abc123...",
  "source": "claude-notifications"
}
```

## Troubleshooting

### Webhook not firing

1. Check `"enabled": true` in config
2. Verify webhook URL is correct
3. Check logs: `tail -f notification-debug.log`

### Wrong format received

1. Verify `preset` field matches your platform
2. For Telegram, ensure `chat_id` is set
3. Test with `test/test-webhook.sh`

### Custom headers not working

Custom headers are only supported with `preset: "custom"`. For platform-specific webhooks (Slack/Discord/Telegram), headers are managed by the platform.

## Disclaimer

⚠️ **Note:** Webhook integrations are community-contributed and not officially tested by the plugin author. Please report issues on [GitHub](https://github.com/belief/claude-notifications/issues).

## Contributing

Found a bug or want to add support for another platform? Contributions are welcome!

1. Test your integration
2. Document the setup process
3. Submit a pull request

See the [custom webhook guide](custom.md) for examples of how to add new platforms.
