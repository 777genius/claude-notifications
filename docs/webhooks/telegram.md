# Telegram Webhook Integration

Send Claude Code notifications to Telegram chats.

## Official Documentation

- **[Telegram Bot API](https://core.telegram.org/bots/api)** - Official Telegram Bot API documentation
- **[sendMessage Method](https://core.telegram.org/bots/api#sendmessage)** - API method for sending messages

## Setup Steps

### 1. Create Telegram Bot

1. Open Telegram and search for **`@BotFather`**
2. Send `/newbot` command
3. Follow the prompts:
   - **Bot name:** Choose a friendly name (e.g., "Claude Notifications")
   - **Bot username:** Choose a unique username ending in `bot` (e.g., `claude_notifs_bot`)
4. **BotFather** will send you a token like: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`
5. **Save this token securely** - you'll need it for the webhook URL

### 2. Get Your Chat ID

You need to find the chat ID where you want to receive notifications.

#### Option A: Using Your Bot

1. Send any message to your bot (e.g., `/start`)
2. Visit this URL in your browser (replace `<YOUR_BOT_TOKEN>`):
   ```
   https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
   ```
3. Look for `"chat":{"id":123456789}` in the JSON response
4. Save this chat ID

**Example response:**
```json
{
  "ok": true,
  "result": [{
    "update_id": 123456,
    "message": {
      "message_id": 1,
      "from": {"id": 123456789, "first_name": "John"},
      "chat": {"id": 123456789, "type": "private"},
      "text": "/start"
    }
  }]
}
```

#### Option B: Using @userinfobot

1. Search for **`@userinfobot`** in Telegram
2. Send `/start` to the bot
3. Bot will reply with your user ID
4. This is your chat ID

### 3. Configure Plugin

Edit `config/config.json`:

```json
{
  "notifications": {
    "webhook": {
      "enabled": true,
      "preset": "telegram",
      "url": "https://api.telegram.org/bot123456789:ABCdefGHIjklMNOpqrsTUVwxyz/sendMessage",
      "chat_id": "123456789"
    }
  }
}
```

**Required fields:**
- `enabled`: `true`
- `preset`: `"telegram"`
- `url`: `https://api.telegram.org/bot<YOUR_TOKEN>/sendMessage`
- `chat_id`: Your Telegram chat ID (string)

**Important:**
- URL format: `https://api.telegram.org/bot<TOKEN>/sendMessage`
- Replace `<TOKEN>` with your bot token from BotFather
- `chat_id` can be positive (private chat) or negative (groups/channels)

### 4. Test Your Webhook

#### Using the test script:

```bash
./test/webhook-tester.sh --preset telegram \
  --url "https://api.telegram.org/bot123456789:ABC.../sendMessage" \
  --chat-id "123456789" \
  --message "Test notification from Claude Code"
```

#### Using curl:

```bash
curl -X POST -H 'Content-Type: application/json' \
  -d '{"chat_id":"123456789","text":"Test notification from Claude Code"}' \
  https://api.telegram.org/bot<YOUR_TOKEN>/sendMessage
```

**Expected response:**
```json
{
  "ok": true,
  "result": {
    "message_id": 123,
    "from": {"id": 987654321, "is_bot": true, "first_name": "Claude Notifications"},
    "chat": {"id": 123456789, "type": "private"},
    "date": 1705498234,
    "text": "Test notification from Claude Code"
  }
}
```

## Payload Format

The plugin sends messages in this format:

```json
{
  "chat_id": "123456789",
  "text": "✅ Task Completed: Implemented new feature with 5 file changes"
}
```

**Field descriptions:**
- `chat_id` (string/integer, required): Unique identifier for the target chat
- `text` (string, required): Message text (1-4096 characters)

## Message Examples

### Task Completed
```
✅ Task Completed: Fixed bug in authentication module
```

### Plan Ready
```
📋 Plan Ready for Review: Refactor database layer (3 steps)
```

### Question
```
❓ Claude Has Questions: Need clarification on API endpoint format
```

## Advanced Features

### Formatting

You can enable text formatting by modifying `lib/webhook.sh` to include `parse_mode`:

```json
{
  "chat_id": "123456789",
  "text": "*✅ Task Completed*\n\nImplemented new feature",
  "parse_mode": "Markdown"
}
```

**Supported parse modes:**
- `"Markdown"` - Classic Markdown
- `"MarkdownV2"` - New Markdown with more features
- `"HTML"` - HTML formatting

### Inline Keyboard

Add interactive buttons:

```json
{
  "chat_id": "123456789",
  "text": "✅ Task Completed",
  "reply_markup": {
    "inline_keyboard": [[
      {"text": "View Code", "url": "https://github.com/..."}
    ]]
  }
}
```

**Note:** These features require modifying webhook.sh source code.

## Group and Channel Support

### For Groups:

1. Add your bot to the group
2. Make bot an admin (if needed for posting permissions)
3. Get group chat ID:
   ```
   https://api.telegram.org/bot<TOKEN>/getUpdates
   ```
4. Group chat IDs are **negative** (e.g., `-123456789`)

**Config:**
```json
{
  "chat_id": "-123456789"
}
```

### For Channels:

1. Add bot as channel admin
2. Get channel ID (negative number) or use username
3. Use either:
   - Channel ID: `"-100123456789"`
   - Or username: `"@channelname"`

**Config:**
```json
{
  "chat_id": "@your_channel"
}
```

## Limitations

- **Text length:** 1-4096 characters
- **HTTP methods:** Both GET and POST supported (plugin uses POST)
- **Rate limits:** ~30 messages per second per bot
- **File size:** Not applicable (plugin only sends text)

## Troubleshooting

### Error: Unauthorized (401)

**Cause:** Invalid bot token.

**Solution:**
- Verify bot token from @BotFather
- Check URL format: `https://api.telegram.org/bot<TOKEN>/sendMessage`
- Ensure no extra spaces in token

### Error: Bad Request: chat not found (400)

**Cause:** Invalid or incorrect chat ID.

**Solution:**
- Verify chat_id is correct
- Ensure chat_id is a string in config.json: `"123456789"`
- For groups, chat_id should be negative: `"-123456789"`
- Send a message to the bot first, then call `/getUpdates`

### Error: Forbidden: bot was blocked by the user (403)

**Cause:** User blocked the bot.

**Solution:**
- User must unblock the bot in Telegram
- User must send `/start` to the bot first

### Error: Bad Request: message is too long (400)

**Cause:** Message text exceeds 4096 characters.

**Solution:**
- Summaries are typically under this limit
- If needed, modify summarizer.sh to truncate text

### No messages received

**Debug steps:**

```bash
# Test bot token
curl https://api.telegram.org/bot<YOUR_TOKEN>/getMe

# Expected: {"ok":true,"result":{"id":...,"is_bot":true,...}}

# Test sendMessage
curl -X POST \
  "https://api.telegram.org/bot<YOUR_TOKEN>/sendMessage" \
  -d "chat_id=YOUR_CHAT_ID&text=Test"

# Check response for errors
```

## Security Best Practices

1. **Keep bot token secret** - Treat it like a password
2. **Don't commit to Git** - Add `config/config.json` to `.gitignore`
3. **Revoke if leaked** - Use @BotFather `/revoke` command to generate new token
4. **Use private chats** - Avoid posting sensitive info to public groups
5. **Restrict bot access** - Remove bot from groups where not needed

## Notification Frequency

By default, Claude Code sends notifications for these events:
- **Task completion** (Stop/SubagentStop hooks)
- **Plan ready** (when ExitPlanMode is called)
- **Questions** (when AskUserQuestion is called)

Typical frequency: 1-5 notifications per session (depending on task complexity)

## Example Workflow

1. **User:** "Refactor the authentication module"
2. **Claude:** Creates plan → **Telegram message:** "📋 Plan Ready"
3. **User:** "Approve"
4. **Claude:** Implements changes → **Telegram message:** "✅ Task Completed"

## API Endpoint Structure

Telegram Bot API endpoint format:
```
https://api.telegram.org/bot<TOKEN>/METHOD_NAME
```

**For this integration:**
- `<TOKEN>`: Your bot token from @BotFather
- `METHOD_NAME`: `sendMessage`

**Full URL:**
```
https://api.telegram.org/bot123456789:ABCdefGHI.../sendMessage
```

## Related Links

- [Telegram Bot API Methods](https://core.telegram.org/bots/api#available-methods) - All available methods
- [Formatting Options](https://core.telegram.org/bots/api#formatting-options) - Text formatting guide
- [BotFather Commands](https://core.telegram.org/bots#botfather) - Manage your bot

## Disclaimer

⚠️ **Note:** This integration is community-contributed and not officially tested by the plugin author. Telegram Bot API may change without notice.

**Tested with:**
- Telegram Bot API version: 7.0+
- sendMessage method: Latest

**Report issues:** [GitHub Issues](https://github.com/belief/claude-notifications/issues)

---

[← Back to Webhook Integrations](README.md)
