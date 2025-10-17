#!/bin/bash
# webhook-tester.sh - Test webhook integrations with real endpoints
#
# Usage:
#   ./webhook-tester.sh --preset <slack|discord|telegram|custom> --url <URL> [options]
#
# Examples:
#   ./webhook-tester.sh --preset slack --url 'https://hooks.slack.com/...' --message 'Test'
#   ./webhook-tester.sh --preset discord --url 'https://discord.com/api/webhooks/...'
#   ./webhook-tester.sh --preset telegram --url 'https://api.telegram.org/bot.../sendMessage' --chat-id '123456'

set -eu

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
  echo "Usage: $0 --preset <slack|discord|telegram|custom> --url <URL> [OPTIONS]"
  echo ""
  echo "Required arguments:"
  echo "  --preset <PRESET>    Webhook preset: slack, discord, telegram, custom"
  echo "  --url <URL>          Webhook endpoint URL"
  echo ""
  echo "Optional arguments:"
  echo "  --chat-id <ID>       Telegram chat ID (required for telegram preset)"
  echo "  --message <TEXT>     Custom message text (default: 'Test notification from Claude Code')"
  echo "  --help               Show this help message"
  echo ""
  echo "Examples:"
  echo "  # Slack"
  echo "  $0 --preset slack --url 'https://hooks.slack.com/services/...'"
  echo ""
  echo "  # Discord"
  echo "  $0 --preset discord --url 'https://discord.com/api/webhooks/...'"
  echo ""
  echo "  # Telegram"
  echo "  $0 --preset telegram --url 'https://api.telegram.org/bot.../sendMessage' --chat-id '123456'"
  echo ""
  echo "  # Custom"
  echo "  $0 --preset custom --url 'https://your-endpoint.com/notify' --message 'Hello'"
  exit 1
}

# Parse arguments
PRESET=""
URL=""
CHAT_ID=""
MESSAGE="Test notification from Claude Code"

while [[ $# -gt 0 ]]; do
  case $1 in
    --preset)
      PRESET="$2"
      shift 2
      ;;
    --url)
      URL="$2"
      shift 2
      ;;
    --chat-id)
      CHAT_ID="$2"
      shift 2
      ;;
    --message)
      MESSAGE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo -e "${RED}Error: Unknown argument '$1'${NC}"
      echo ""
      usage
      ;;
  esac
done

# Validate required arguments
if [[ -z "$PRESET" ]] || [[ -z "$URL" ]]; then
  echo -e "${RED}Error: Missing required arguments${NC}"
  echo ""
  usage
fi

# Validate preset value
case "$PRESET" in
  slack|discord|telegram|custom)
    # Valid preset
    ;;
  *)
    echo -e "${RED}Error: Invalid preset '$PRESET'${NC}"
    echo "Valid presets: slack, discord, telegram, custom"
    exit 1
    ;;
esac

# Build JSON payload based on preset
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  Webhook Tester - Claude Notifications Plugin            ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Preset:${NC}   $PRESET"
echo -e "${YELLOW}URL:${NC}      $URL"

case "$PRESET" in
  "slack")
    echo -e "${YELLOW}Format:${NC}   Slack Incoming Webhook"
    echo ""
    JSON_DATA=$(jq -n --arg text "$MESSAGE" '{text: $text}')
    ;;

  "discord")
    echo -e "${YELLOW}Format:${NC}   Discord Webhook"
    echo ""
    JSON_DATA=$(jq -n --arg content "$MESSAGE" '{content: $content, username: "Claude Code"}')
    ;;

  "telegram")
    echo -e "${YELLOW}Format:${NC}   Telegram Bot API sendMessage"
    if [[ -z "$CHAT_ID" ]]; then
      echo ""
      echo -e "${RED}Error: --chat-id required for Telegram${NC}"
      echo "Example: $0 --preset telegram --url '...' --chat-id '123456'"
      exit 1
    fi
    echo -e "${YELLOW}Chat ID:${NC}  $CHAT_ID"
    echo ""
    JSON_DATA=$(jq -n --arg chat_id "$CHAT_ID" --arg text "$MESSAGE" '{chat_id: $chat_id, text: $text}')
    ;;

  "custom")
    echo -e "${YELLOW}Format:${NC}   Custom JSON"
    echo ""
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    JSON_DATA=$(jq -n \
      --arg message "$MESSAGE" \
      --arg timestamp "$timestamp" \
      '{
        status: "test",
        message: $message,
        timestamp: $timestamp,
        session_id: "test-session",
        source: "claude-notifications-test"
      }')
    ;;
esac

echo -e "${YELLOW}Payload:${NC}"
echo "$JSON_DATA" | jq '.'
echo ""

# Send webhook
echo -e "${BLUE}Sending webhook...${NC}"
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "$JSON_DATA" \
  "$URL")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

echo -e "${YELLOW}HTTP Status:${NC} $HTTP_CODE"

# Check if response is JSON
if echo "$BODY" | jq '.' >/dev/null 2>&1; then
  echo -e "${YELLOW}Response:${NC}"
  echo "$BODY" | jq '.'
else
  echo -e "${YELLOW}Response:${NC} $BODY"
fi

echo ""

# Evaluate result
if [[ "$HTTP_CODE" -ge 200 ]] && [[ "$HTTP_CODE" -lt 300 ]]; then
  echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║${NC}  ✓ Webhook sent successfully!                             ${GREEN}║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${YELLOW}Next steps:${NC}"
  echo "  1. Check your ${PRESET} for the test message"
  echo "  2. If received, update config/config.json with these settings"
  echo "  3. Enable webhook: \"enabled\": true"
  echo ""
  exit 0
else
  echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║${NC}  ✗ Webhook failed!                                         ${RED}║${NC}"
  echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  # Provide helpful error messages
  case "$HTTP_CODE" in
    400)
      echo -e "${YELLOW}Common causes for HTTP 400:${NC}"
      echo "  • Malformed JSON payload"
      echo "  • Missing required fields"
      echo "  • Invalid chat_id (Telegram)"
      ;;
    401)
      echo -e "${YELLOW}Common causes for HTTP 401:${NC}"
      echo "  • Invalid bot token (Telegram)"
      echo "  • Incorrect authentication"
      ;;
    403)
      echo -e "${YELLOW}Common causes for HTTP 403:${NC}"
      echo "  • Bot blocked by user (Telegram)"
      echo "  • Insufficient permissions"
      ;;
    404)
      echo -e "${YELLOW}Common causes for HTTP 404:${NC}"
      echo "  • Webhook URL not found or deleted"
      echo "  • Incorrect URL format"
      ;;
    429)
      echo -e "${YELLOW}Common causes for HTTP 429:${NC}"
      echo "  • Rate limit exceeded"
      echo "  • Too many requests"
      ;;
    500)
      echo -e "${YELLOW}Common causes for HTTP 500:${NC}"
      echo "  • Server error"
      echo "  • Check webhook service status"
      ;;
    *)
      echo -e "${YELLOW}Check the response above for error details${NC}"
      ;;
  esac

  echo ""
  echo -e "${YELLOW}Troubleshooting:${NC}"
  echo "  • Verify webhook URL is correct"
  echo "  • Check docs/webhooks/${PRESET}.md for setup instructions"
  echo "  • Test with curl manually to isolate the issue"
  echo ""
  exit 1
fi
