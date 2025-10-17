# Custom Webhook Format

Use the generic JSON format for custom webhook endpoints or third-party services.

## Overview

The `custom` preset sends a standardized JSON payload that includes:
- Task status
- Summary message
- Timestamp
- Session ID
- Source identifier

This format is ideal for:
- Custom backend services
- Automation platforms (Zapier, Make.com, n8n)
- Monitoring tools (Datadog, New Relic, Prometheus)
- Custom integrations with internal tools

## Configuration

Edit `config/config.json`:

```json
{
  "notifications": {
    "webhook": {
      "enabled": true,
      "preset": "custom",
      "url": "https://your-webhook-endpoint.com/notify",
      "format": "json",
      "headers": {
        "Authorization": "Bearer YOUR_API_TOKEN",
        "X-Custom-Header": "value"
      }
    }
  }
}
```

**Required fields:**
- `enabled`: `true`
- `preset`: `"custom"` (or omit this field - defaults to custom)
- `url`: Your webhook endpoint URL

**Optional fields:**
- `format`: `"json"` (default) or `"text"`
- `headers`: Object with custom HTTP headers

## Payload Format

### JSON Format (default)

When `format` is `"json"` or unspecified:

```json
{
  "status": "task_complete",
  "message": "Fixed bug in authentication module with 3 file changes",
  "timestamp": "2025-01-17T12:34:56Z",
  "session_id": "abc123-def456-ghi789",
  "source": "claude-notifications"
}
```

**Field descriptions:**
- `status` (string): Task status identifier
- `message` (string): Human-readable summary
- `timestamp` (string): ISO 8601 timestamp in UTC
- `session_id` (string): Unique session identifier
- `source` (string): Always `"claude-notifications"`

### Text Format

When `format` is `"text"`:

```
[task_complete] Fixed bug in authentication module with 3 file changes
```

Format: `[status] message`

## Status Values

The `status` field can be one of:

| Status | Description | When it fires |
|--------|-------------|---------------|
| `task_complete` | Task finished successfully | Work completed, tests pass |
| `plan_ready` | Plan created, awaiting approval | ExitPlanMode called |
| `question` | Claude has questions | AskUserQuestion called |
| `review_complete` | Code review completed | Review keywords detected |

## Custom Headers

Add authentication or custom headers for your endpoint:

```json
{
  "headers": {
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIs...",
    "X-API-Key": "your-api-key-here",
    "X-Service": "claude-code",
    "Content-Type": "application/json"
  }
}
```

**Note:** `Content-Type` is automatically set based on `format` field, but you can override it if needed.

## Testing

### Using the test script:

```bash
./test/test-webhook.sh --preset custom \
  --url "https://your-endpoint.com/notify" \
  --message "Test notification"
```

### Using curl (JSON):

```bash
curl -X POST -H 'Content-Type: application/json' \
  -d '{
    "status": "test",
    "message": "Test notification",
    "timestamp": "2025-01-17T12:34:56Z",
    "session_id": "test-session",
    "source": "claude-notifications"
  }' \
  https://your-endpoint.com/notify
```

### Using curl (Text):

```bash
curl -X POST -H 'Content-Type: text/plain' \
  -d '[test] Test notification' \
  https://your-endpoint.com/notify
```

## Use Cases

### 1. Zapier/Make.com/n8n Integration

**Setup:**
1. Create a "Webhook" trigger in your automation platform
2. Copy the webhook URL
3. Configure plugin with that URL
4. Map JSON fields to your workflow actions

**Example workflow:**
- **Trigger:** Webhook receives notification
- **Filter:** Only process `status == "task_complete"`
- **Action 1:** Send email summary
- **Action 2:** Log to Google Sheets
- **Action 3:** Post to Slack (#dev-updates channel)

### 2. Custom Backend Service

**Example Node.js endpoint:**

```javascript
app.post('/claude-notifications', (req, res) => {
  const { status, message, timestamp, session_id } = req.body;

  // Store in database
  await db.notifications.create({
    status,
    message,
    timestamp: new Date(timestamp),
    session_id
  });

  // Trigger other actions
  if (status === 'task_complete') {
    await notifyTeam(message);
    await updateDashboard(session_id);
  }

  res.status(200).send('OK');
});
```

### 3. Monitoring/Observability

**Example with Datadog:**

```json
{
  "headers": {
    "DD-API-KEY": "your-datadog-api-key"
  },
  "url": "https://http-intake.logs.datadoghq.com/v1/input"
}
```

**Transform payload for Datadog:**

Modify `lib/webhook.sh` to send:
```json
{
  "ddsource": "claude-code",
  "ddtags": "env:production,service:ai-assistant",
  "message": "Task completed: ...",
  "status": "info"
}
```

### 4. CI/CD Integration

Trigger builds or deployments when tasks complete:

```bash
# GitHub Actions webhook
url: "https://api.github.com/repos/owner/repo/dispatches"

# Headers with auth token
headers: {
  "Authorization": "Bearer ghp_...",
  "Accept": "application/vnd.github+json"
}
```

## Security Best Practices

1. **Use HTTPS** - Always use `https://` URLs, never `http://`
2. **Authenticate requests** - Use `Authorization` headers or API keys
3. **Validate payloads** - On your endpoint, verify the `source` field
4. **Rate limiting** - Implement rate limiting on your endpoint
5. **Don't log secrets** - Avoid logging full config/headers

**Example validation (server-side):**
```javascript
if (req.body.source !== 'claude-notifications') {
  return res.status(403).send('Invalid source');
}
```

## Troubleshooting

### Webhook not received

**Debug steps:**

```bash
# Test endpoint is reachable
curl -I https://your-endpoint.com/notify

# Test with minimal payload
curl -X POST -H 'Content-Type: application/json' \
  -d '{"test":"value"}' \
  https://your-endpoint.com/notify

# Check server logs for errors
```

### Authentication failures

**Solutions:**
- Verify `Authorization` header is correct
- Check API key hasn't expired
- Ensure header format matches API requirements
  - Bearer tokens: `"Bearer TOKEN"`
  - API keys: May vary by service

### Wrong Content-Type

**Cause:** Some APIs require specific Content-Type headers.

**Solution:** Override in headers:
```json
{
  "headers": {
    "Content-Type": "application/vnd.api+json"
  }
}
```

### Payload too large

**Cause:** Some services have payload size limits.

**Solution:**
- Modify `lib/summarizer.sh` to generate shorter summaries
- Truncate message field in webhook.sh before sending

## Advanced Customization

### Modify Payload Structure

To add custom fields, edit `lib/webhook.sh` around line 80:

```bash
# Add custom fields
json_data=$(jq -n \
  --arg status "$status" \
  --arg message "$message" \
  --arg timestamp "$timestamp" \
  --arg session_id "$session_id" \
  --arg hostname "$(hostname)" \
  --arg user "$(whoami)" \
  '{
    status: $status,
    message: $message,
    timestamp: $timestamp,
    session_id: $session_id,
    source: "claude-notifications",
    metadata: {
      hostname: $hostname,
      user: $user
    }
  }')
```

### Transform for Specific API

Create a preset for your service:

```bash
case "$preset" in
  # ... existing presets ...

  "datadog")
    json_data=$(jq -n \
      --arg message "$message" \
      --arg timestamp "$timestamp" \
      '{
        ddsource: "claude-code",
        message: $message,
        date: $timestamp,
        status: "info"
      }')
    ;;
esac
```

## Example Integrations

### Webhook.site (Testing)

For quick testing without a real endpoint:

1. Go to https://webhook.site
2. Copy your unique URL
3. Configure plugin with that URL
4. View requests in real-time on webhook.site

### RequestBin (Debugging)

Similar to Webhook.site:

1. Go to https://requestbin.com
2. Create a bin
3. Use bin URL in config
4. Inspect full request details

## Related Links

- [Zapier Webhooks](https://zapier.com/page/webhooks/) - Automation platform
- [Make.com Webhooks](https://www.make.com/en/help/tools/webhooks) - Integration platform
- [n8n Webhooks](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/) - Workflow automation

## Disclaimer

⚠️ **Note:** Custom webhook integration is provided as-is. The plugin author cannot provide support for third-party services or custom endpoints.

**Security:** Always validate and sanitize webhook payloads on the receiving end to prevent injection attacks.

**Report plugin issues:** [GitHub Issues](https://github.com/belief/claude-notifications/issues)

---

[← Back to Webhook Integrations](README.md)
