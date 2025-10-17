# Discord Webhook Integration

Send Claude Code notifications to Discord channels.

## Official Documentation

- **[Discord Webhooks Guide](https://birdie0.github.io/discord-webhooks-guide/)** - Comprehensive community guide
- **[Discord Developer Docs](https://discord.com/developers/docs/resources/webhook)** - Official Discord API documentation

## Setup Steps

### 1. Create Webhook in Discord

1. Open Discord and navigate to your server
2. Right-click on the channel you want notifications in
3. Select **"Edit Channel"**
4. Go to **"Integrations"** tab
5. Click **"Create Webhook"** (or **"View Webhooks"** if webhooks already exist)
6. Click **"New Webhook"**
7. Customize the name and avatar (optional)
   - Name example: "Claude Code"
   - Upload custom avatar if desired
8. Click **"Copy Webhook URL"**
9. Click **"Save Changes"**

### 2. Configure Plugin

Edit `config/config.json`:

```json
{
  "notifications": {
    "webhook": {
      "enabled": true,
      "preset": "discord",
      "url": "https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN"
    }
  }
}
```

**Required fields:**
- `enabled`: `true`
- `preset`: `"discord"`
- `url`: Your Discord webhook URL

**Optional fields:** None (chat_id, headers not used for Discord)

### 3. Test Your Webhook

#### Using the test script:

```bash
./test/webhook-tester.sh --preset discord \
  --url "https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN" \
  --message "Test notification from Claude Code"
```

#### Using curl:

```bash
curl -X POST -H 'Content-Type: application/json' \
  -d '{"content":"Test notification from Claude Code","username":"Claude Code"}' \
  https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN
```

**Expected response:** JSON with message details (HTTP 200/204)

## Payload Format

The plugin sends messages in this format:

```json
{
  "content": "✅ Task Completed: Implemented new feature with 5 file changes",
  "username": "Claude Code"
}
```

**Field descriptions:**
- `content` (string, required): Message text (max 2000 characters)
- `username` (string, optional): Override webhook's default username

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

### Custom Avatar

You can override the webhook's avatar by modifying `lib/webhook.sh`:

```json
{
  "content": "Message text",
  "username": "Claude Code",
  "avatar_url": "https://example.com/claude-avatar.png"
}
```

### Rich Embeds

For richer formatting, use [Discord embeds](https://birdie0.github.io/discord-webhooks-guide/structure/embeds.html):

```json
{
  "username": "Claude Code",
  "embeds": [{
    "title": "✅ Task Completed",
    "description": "Implemented new feature",
    "color": 5763719,
    "fields": [
      {"name": "Files Changed", "value": "5", "inline": true},
      {"name": "Session", "value": "clever-wind", "inline": true}
    ],
    "timestamp": "2025-01-17T12:34:56.000Z"
  }]
}
```

**Note:** This requires modifying the webhook.sh source code. The default implementation uses simple text messages.

## Limitations

- **Content length:** Maximum 2000 characters
- **Embeds:** Can include multiple custom embeds (webhooks support this)
- **Required fields:** Must include at least one of: `content`, `embeds`, `poll`, or `attachments`
- **Color codes:** Use decimal numeral system, not hexadecimal
  - Example: `15258703` (decimal) = `#E8743B` (hex)
- **Rate limits:** Discord enforces global rate limits (typically ~5 requests per second)

## Troubleshooting

### Error: Request failed / HTTP 404

**Possible causes:**
1. **Webhook deleted** - Webhook may have been deleted in Discord
2. **Invalid URL** - Check that URL is complete and correct
3. **Wrong server** - Webhook belongs to different server

**Solution:**
- Verify webhook exists in Discord channel settings
- Create new webhook if necessary
- Copy URL carefully (should include both ID and token)

### Error: Empty message / HTTP 400

**Cause:** Neither `content`, `embeds`, `poll`, nor `attachments` are present.

**Solution:** Ensure `content` field is populated in the payload:
```bash
json_data=$(jq -n --arg content "$message" '{content: $content, username: "Claude Code"}')
```

### Message content too long

**Cause:** Discord limits message content to 2000 characters.

**Solution:**
- Truncate long messages
- Or split into multiple messages
- Or use embeds for structured content

### Webhook not posting

**Debug steps:**

```bash
# Test with minimal payload
curl -v -X POST -H 'Content-Type: application/json' \
  -d '{"content":"Test"}' \
  https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN

# Check response code:
# - 200/204: Success
# - 400: Bad request (check payload)
# - 404: Webhook not found
# - 429: Rate limited
```

## Security Best Practices

1. **Keep webhook URL secret** - Anyone with the URL can post to your channel
2. **Don't commit to Git** - Add `config/config.json` to `.gitignore`
3. **Regenerate if leaked** - Delete and create new webhook if URL is exposed
4. **Use channel permissions** - Limit who can create webhooks in channel settings
5. **Monitor usage** - Check Discord audit log for webhook activity

## Webhook URL Format

Discord webhook URLs follow this pattern:
```
https://discord.com/api/webhooks/{webhook.id}/{webhook.token}
```

- `{webhook.id}`: Numeric ID (18 digits)
- `{webhook.token}`: Secret token (alphanumeric string)

**Example:**
```
https://discord.com/api/webhooks/123456789012345678/AbCdEfGhIjKlMnOpQrStUvWxYz1234567890_AbCdEfGh
```

## Notification Frequency

By default, Claude Code sends notifications for these events:
- **Task completion** (Stop/SubagentStop hooks)
- **Plan ready** (when ExitPlanMode is called)
- **Questions** (when AskUserQuestion is called)

Typical frequency: 1-5 notifications per session (depending on task complexity)

## Example Workflow

1. **User:** "Refactor the authentication module"
2. **Claude:** Creates plan → **Discord notification:** "📋 Plan Ready"
3. **User:** "Approve"
4. **Claude:** Implements changes → **Discord notification:** "✅ Task Completed"

## Related Links

- [Discord Embed Visualizer](https://leovoel.github.io/embed-visualizer/) - Design rich embeds
- [Discord Webhook Limits](https://discord.com/developers/docs/resources/webhook#execute-webhook) - API reference
- [Discord Markdown](https://support.discord.com/hc/en-us/articles/210298617-Markdown-Text-101) - Text formatting guide

## Disclaimer

⚠️ **Note:** This integration is community-contributed and not officially tested by the plugin author. Discord API may change without notice.

**Tested with:**
- Discord Webhook API version: v10
- Guide source: community documentation

**Report issues:** [GitHub Issues](https://github.com/belief/claude-notifications/issues)

---

[← Back to Webhook Integrations](README.md)
