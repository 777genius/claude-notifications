# Slack Webhook Integration

Send Claude Code notifications to Slack channels.

## Official Documentation

- **[Slack Incoming Webhooks](https://docs.slack.dev/messaging/sending-messages-using-incoming-webhooks)** - Official Slack API documentation

## Setup Steps

### 1. Create Incoming Webhook in Slack

1. Go to **https://api.slack.com/apps**
2. Click **"Create New App"** → **"From scratch"**
3. Name your app (e.g., "Claude Notifications")
4. Select your workspace
5. Navigate to **"Incoming Webhooks"** in the left sidebar
6. Toggle **"Activate Incoming Webhooks"** to **On**
7. Click **"Add New Webhook to Workspace"**
8. Select a channel to post notifications
9. Click **"Allow"**
10. Copy the Webhook URL (starts with `https://hooks.slack.com/services/...`)

### 2. Configure Plugin

Edit `config/config.json`:

```json
{
  "notifications": {
    "webhook": {
      "enabled": true,
      "preset": "slack",
      "url": "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
    }
  }
}
```

**Required fields:**
- `enabled`: `true`
- `preset`: `"slack"`
- `url`: Your Slack webhook URL

**Optional fields:** None (chat_id, headers not used for Slack)

### 3. Test Your Webhook

#### Using the test script:

```bash
./test/webhook-tester.sh --preset slack \
  --url "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
  --message "Test notification from Claude Code"
```

#### Using curl:

```bash
curl -X POST -H 'Content-Type: application/json' \
  -d '{"text":"Test notification from Claude Code"}' \
  https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

**Expected response:** `ok` (HTTP 200)

## Payload Format

The plugin sends messages in this format:

```json
{
  "text": "✅ Task Completed: Implemented new feature with 5 file changes"
}
```

**Field descriptions:**
- `text` (string, required): Message content that will appear in Slack

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

### Using Block Kit (Optional)

For richer formatting, you can modify `lib/webhook.sh` to use [Block Kit](https://api.slack.com/block-kit):

```json
{
  "text": "Task Completed",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*✅ Task Completed*\nImplemented new feature"
      }
    }
  ]
}
```

**Note:** This requires modifying the webhook.sh source code. The default implementation uses simple text messages.

## Limitations

- **Maximum attachments:** 100 per message
- **Customization:** Cannot override channel, username, or icon via webhook (configured in Slack App settings)
- **Deletion:** Cannot delete messages after posting
- **Rate limits:** Slack enforces rate limits on incoming webhooks (typically 1 message per second)

## Troubleshooting

### Error: `no_text`

**Cause:** The `text` field is missing from the payload.

**Solution:** Ensure your webhook.sh has the Slack preset correctly configured:
```bash
json_data=$(jq -n --arg text "$message" '{text: $text}')
```

### Error: `invalid_payload`

**Cause:** JSON is malformed or special characters are not properly escaped.

**Solution:**
- Check that message text doesn't contain unescaped quotes
- Verify JSON structure with `jq` before sending
- Test with simple ASCII text first

### No message appearing in Slack

**Possible causes:**
1. **Wrong webhook URL** - Verify the URL is correct
2. **Webhook deleted** - Regenerate webhook in Slack app settings
3. **App not installed** - Reinstall the Slack app to workspace
4. **Channel archived** - Webhook won't post to archived channels

**Debug steps:**
```bash
# Check webhook response
curl -v -X POST -H 'Content-Type: application/json' \
  -d '{"text":"Test"}' \
  https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Look for HTTP 200 OK response
```

### Messages appearing in wrong channel

**Cause:** Webhook is configured to post to a specific channel.

**Solution:**
1. Go to Slack App settings
2. Remove old webhook
3. Create new webhook with desired channel

## Security Best Practices

1. **Keep webhook URL secret** - Treat it like a password
2. **Don't commit to Git** - Add `config/config.json` to `.gitignore`
3. **Regenerate if leaked** - Delete and create new webhook if URL is exposed
4. **Use environment variables** - Consider storing URL in env vars:

```bash
# In your shell
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."

# Then reference in config (requires script modification)
```

## Notification Frequency

By default, Claude Code sends notifications for these events:
- **Task completion** (Stop/SubagentStop hooks)
- **Plan ready** (when ExitPlanMode is called)
- **Questions** (when AskUserQuestion is called)

Typical frequency: 1-5 notifications per session (depending on task complexity)

## Example Workflow

1. **User:** "Refactor the authentication module"
2. **Claude:** Creates plan → **Slack notification:** "📋 Plan Ready"
3. **User:** "Approve"
4. **Claude:** Implements changes → **Slack notification:** "✅ Task Completed"

## Related Links

- [Slack Block Kit Builder](https://app.slack.com/block-kit-builder) - Design rich messages
- [Slack API Rate Limits](https://api.slack.com/docs/rate-limits) - Understanding limits
- [Message Formatting](https://api.slack.com/reference/surfaces/formatting) - Text formatting guide

## Disclaimer

⚠️ **Note:** This integration is community-contributed and not officially tested by the plugin author. Slack API may change without notice.

**Tested with:**
- Slack API version: 2025
- Incoming Webhooks: Latest

**Report issues:** [GitHub Issues](https://github.com/belief/claude-notifications/issues)

---

[← Back to Webhook Integrations](README.md)
