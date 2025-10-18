# Claude Notifications Plugin

[![macOS Tests](https://github.com/777genius/claude-notifications/actions/workflows/test-macos.yml/badge.svg)](https://github.com/777genius/claude-notifications/actions/workflows/test-macos.yml)
[![Linux Tests](https://github.com/777genius/claude-notifications/actions/workflows/test-linux.yml/badge.svg)](https://github.com/777genius/claude-notifications/actions/workflows/test-linux.yml)
[![Windows Tests](https://github.com/777genius/claude-notifications/actions/workflows/test-windows.yml/badge.svg)](https://github.com/777genius/claude-notifications/actions/workflows/test-windows.yml)
[![Coverage](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/777genius/claude-notifications/gh-pages/coverage-badge.json)](https://codecov.io/gh/777genius/claude-notifications)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)


<img width="350" height="239" alt="image" src="https://github.com/user-attachments/assets/42b7a306-f56f-4499-94cf-f3d573416b6d" />


## Table of Contents

- [Claude Notifications Plugin](#claude-notifications-plugin)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Test Coverage](#test-coverage)
  - [Notification Statuses](#notification-statuses)
  - [Installation](#installation)
    - [Quick Install from GitHub](#quick-install-from-github)
    - [Local Installation (for development)](#local-installation-for-development)
  - [Quick Setup (Recommended)](#quick-setup-recommended)
    - [Interactive Setup Wizard](#interactive-setup-wizard)
  - [Manual Setup (Advanced)](#manual-setup-advanced)
    - [1. Copy Configuration File](#1-copy-configuration-file)
    - [2. Configure Notifications](#2-configure-notifications)
    - [3. Configure Sound Files (Optional)](#3-configure-sound-files-optional)
      - [Option A: Use System Sounds (Easiest - Works Immediately)](#option-a-use-system-sounds-easiest---works-immediately)
      - [Option B: Add Custom Sound Files](#option-b-add-custom-sound-files)
      - [Option C: Disable Sounds](#option-c-disable-sounds)
  - [Configuration Options](#configuration-options)
    - [Desktop Notifications](#desktop-notifications)
    - [Webhook Notifications](#webhook-notifications)
      - [Text Format](#text-format)
      - [JSON Format](#json-format)
    - [Status Customization](#status-customization)
  - [How It Works](#how-it-works)
    - [Status Detection Logic](#status-detection-logic)
      - [1. Instant Detection (PreToolUse Hook)](#1-instant-detection-pretooluse-hook)
      - [2. Post-Completion Detection (Stop/SubagentStop Hooks)](#2-post-completion-detection-stopsubagentstop-hooks)
    - [Summarization](#summarization)
  - [Limitations](#limitations)
    - [What Can Be Tracked](#what-can-be-tracked)
    - [What Cannot Be Tracked](#what-cannot-be-tracked)
      - [Why This Happens](#why-this-happens)
      - [Workaround](#workaround)
  - [Platform Support](#platform-support)
    - [Fully Supported Platforms](#fully-supported-platforms)
    - [Cross-Platform Implementation](#cross-platform-implementation)
    - [macOS-Only Features](#macos-only-features)
    - [Requirements](#requirements)
  - [🔔 Webhook Integrations](#-webhook-integrations)
    - [Quick Start](#quick-start)
    - [Available Presets](#available-presets)
  - [Known Issues](#known-issues)
    - [Duplicate Notifications (Claude Code Bug)](#duplicate-notifications-claude-code-bug)
    - [Summary Text Robustness](#summary-text-robustness)
  - [Troubleshooting](#troubleshooting)
    - [Notifications not appearing](#notifications-not-appearing)
    - [Sounds not playing](#sounds-not-playing)
    - [Webhook not working](#webhook-not-working)
  - [Contributing](#contributing)
  - [License](#license)
  - [Support](#support)
  - [Roadmap](#roadmap)

Smart notifications for Claude Code task statuses with desktop notifications, webhooks, and sound alerts.

## Features

- ✅ **Desktop Notifications** - Native notifications on macOS, Linux, and Windows
- 🔔 **Sound Alerts** - Customizable sounds for different status types
- 🌐 **Webhook Integration** - Send notifications to external services (text or JSON)
- 🎯 **Smart Status Detection** - Automatically detects task completion, reviews, questions, and plan readiness
- 📝 **Auto Summarization** - Generates concise summaries of completed tasks
- 🔧 **Highly Configurable** - Customize everything through a simple JSON config

## Test Coverage

This plugin has comprehensive test coverage:

| Metric | Value | Description |
|--------|-------|-------------|
| **Coverage/Tests** | See badge above | Code coverage % or test count |
| **Test Suites** | 12 | Independent test files |
| **Test Cases** | 148 | Individual test functions |
| **Source Files** | 10 | Main plugin files (`lib/` + `hooks/`) |
| **Lines of Code** | 1,319 | Non-comment, non-blank lines |

**About Coverage:**
We attempt to measure bash code coverage using [bashcov](https://github.com/infertux/bashcov) on macOS. However, bash coverage is technically challenging due to sourcing, subshells, and helper functions. If coverage measurement succeeds, the badge shows the percentage (e.g., "73.5% | 148 tests"). If not, it shows test count only (e.g., "148 tests").

All tests run on **macOS**, **Linux**, and **Windows**. For detailed reports (when coverage works), visit [Codecov Dashboard](https://codecov.io/gh/777genius/claude-notifications). See [Testing Documentation](docs/testing.md) for details.

## Notification Statuses

The plugin detects and notifies about the following statuses:

| Status | Icon | Description | Trigger |
|--------|------|-------------|---------|
| Task Complete | ✅ | Main task completed | Stop/SubagentStop hooks (state machine analysis) |
| Review Complete | 🔍 | Code review finished | Stop/SubagentStop hooks (review keywords detected) |
| Question | ❓ | Claude has a question | PreToolUse hook (AskUserQuestion) OR Notification hook |
| Plan Ready | 📋 | Plan ready for approval | PreToolUse hook (ExitPlanMode) |

## Installation

### Quick Install from GitHub

```bash
# Add the marketplace
/plugin marketplace add 777genius/claude-notifications

# Install the plugin
/plugin install claude-notifications@claude-notifications
```

### Local Installation (for development)

```bash
# Add local marketplace
/plugin marketplace add /path/to/claude-notifications

# Install from local
/plugin install claude-notifications@local-dev
```

**Updating local plugin:**
Changes to a locally installed plugin are reflected immediately - just edit the files and they'll take effect on the next hook trigger. No need to reinstall!

## Quick Setup (Recommended)

### Interactive Setup Wizard

Run the interactive setup command to configure your plugin with ease:

```bash
/setup-notifications
```

**What it does:**
1. 🎵 **Plays system sounds** so you can hear each one before choosing
2. ❓ **Asks interactive questions** with easy-to-use selection UI
3. ⚙️ **Auto-generates config.json** with your preferences
4. ✅ **Tests your setup** to confirm everything works

**Benefits:**
- No manual file editing required
- Hear sounds before selecting them
- Visual selection interface
- Takes 2-3 minutes to complete

You can re-run `/setup-notifications` anytime to reconfigure.

---

## Manual Setup (Advanced)

If you prefer to configure manually:

### 1. Copy Configuration File

```bash
cp config/config.json.example config/config.json
```

### 2. Configure Notifications

Edit `config/config.json` to customize your notifications:

```json
{
  "notifications": {
    "desktop": {
      "enabled": true,
      "sound": true
    },
    "webhook": {
      "enabled": false,
      "url": "https://your-webhook-url.com",
      "format": "json",
      "headers": {
        "Authorization": "Bearer YOUR_TOKEN"
      }
    }
  },
  "statuses": {
    "task_complete": {
      "title": "✅ Task Completed",
      "sound": "sounds/task-complete.mp3"
    }
  }
}
```

### 3. Configure Sound Files (Optional)

You have three options for sound notifications:

#### Option A: Use System Sounds (Easiest - Works Immediately)

The default config uses macOS system sounds that work out of the box:

```json
{
  "statuses": {
    "task_complete": {
      "sound": "/System/Library/Sounds/Glass.aiff"
    }
  }
}
```

**Available macOS System Sounds:**
- Glass.aiff, Ping.aiff, Pop.aiff, Purr.aiff (subtle)
- Funk.aiff, Hero.aiff, Sosumi.aiff (distinctive)
- Basso.aiff, Blow.aiff, Frog.aiff, Submarine.aiff (unique)

**Linux System Sounds:** `/usr/share/sounds/` (varies by distribution)

#### Option B: Add Custom Sound Files

```bash
# Copy config template for custom sounds
cp config/config.json.example-custom-sounds config/config.json

# Add your MP3/WAV/OGG files to sounds/ directory
```

See [sounds/README.md](sounds/README.md) for free sound resources.

#### Option C: Disable Sounds

```json
{
  "notifications": {
    "desktop": {
      "sound": false
    }
  }
}
```

## Configuration Options

### Desktop Notifications

```json
{
  "notifications": {
    "desktop": {
      "enabled": true,    // Enable/disable desktop notifications
      "sound": true       // Enable/disable sound playback
    }
  }
}
```

### Webhook Notifications

#### Text Format

```json
{
  "webhook": {
    "enabled": true,
    "url": "https://webhook.example.com",
    "format": "text"
  }
}
```

Sends: `[task_complete] Created authentication form. Edited 3 files.`

#### JSON Format

```json
{
  "webhook": {
    "enabled": true,
    "url": "https://webhook.example.com",
    "format": "json",
    "headers": {
      "Content-Type": "application/json",
      "Authorization": "Bearer YOUR_TOKEN"
    }
  }
}
```

Sends:
```json
{
  "status": "task_complete",
  "message": "Created authentication form. Edited 3 files.",
  "timestamp": "2025-10-17T10:30:00Z",
  "session_id": "abc123",
  "source": "claude-notifications"
}
```

### Status Customization

Customize the title and sound for each status:

```json
{
  "statuses": {
    "task_complete": {
      "title": "✅ Task Completed",
      "sound": "sounds/task-complete.mp3",
      "keywords": ["completed", "done", "finished"]
    },
    "review_complete": {
      "title": "🔍 Review Completed",
      "sound": "sounds/review-complete.mp3",
      "keywords": ["review", "analyzed", "проверка"]
    }
  }
}
```

## How It Works

1. **Hook Events** - The plugin listens to Claude Code hooks (`Stop`, `Notification`, `SubagentStop`)
2. **Status Analysis** - Analyzes transcript and tool usage to determine task status
3. **Summarization** - Generates a concise summary using simple logic
4. **Multi-Channel Delivery** - Sends notifications via desktop and/or webhook

### Status Detection Logic

The plugin uses **two different detection methods** depending on the type of notification:

#### 1. Instant Detection (PreToolUse Hook)

These statuses are detected **in real-time** as Claude calls the tool, **BEFORE** any UI prompts appear:

- **Plan Ready** (`ExitPlanMode`)
  - Fires when: Claude creates a plan using ExitPlanMode tool
  - Detection: Direct tool_name check (no transcript analysis needed)
  - Timing: Notification sent → then UI shows "Would you like to proceed?"

- **Question** (`AskUserQuestion`)
  - Fires when: Claude asks explicit questions using AskUserQuestion tool
  - Detection: Direct tool_name check (no transcript analysis needed)
  - Timing: Notification sent → then UI shows question prompt

- **Question** (`Notification hook`)
  - Fires when: Claude Code sends system notification events
  - Detection: Always treated as "question" status
  - Timing: Instant (no analysis)

#### 2. Post-Completion Detection (Stop/SubagentStop Hooks)

These statuses are detected **after task completion** using smart analysis:

**State Machine Algorithm:**

The plugin analyzes the **last 15 assistant messages** to determine what work was completed:

1. **Tool Categories:**
   - **Active Tools**: Write, Edit, Bash, NotebookEdit, SlashCommand (makes changes)
   - **Planning Tools**: ExitPlanMode, TodoWrite (creates plans)
   - **Passive Tools**: Read, Grep, Glob, WebFetch, WebSearch, Task (reads only)

2. **Decision Logic:**
   - Last tool is active (Write/Edit/Bash) → **Task Complete**
   - Last tool is passive (Read/Grep) → Check keywords
   - Review keywords found → **Review Complete**
   - At least 1 tool used + completion keywords → **Task Complete**

3. **Temporal Analysis:**
   - Only recent activity (last 15 messages) considered
   - Old tool usage outside window is ignored
   - Prevents false positives from stale data

**Examples:**

```
Scenario 1: Code Written
Tools: [Read, Write, Edit, Bash]
Last tool: Bash (active)
Status: task_complete ✅

Scenario 2: Code Review
Tools: [Read, Read, Grep]
Keywords: "analyzed the code structure"
Status: review_complete ✅

Scenario 3: Just Researching
Tools: [Read, Grep, Read]
Last tool: Read (passive)
Keywords: No completion words
Status: unknown (no notification) ✅
```

**Prevents false notifications during:**
- Idle sessions (no tools used)
- Research/reading sessions (only passive tools, no completion keywords)
- When state machine returns "unknown"

### Summarization

The plugin creates summaries by:
1. Extracting the first sentence from Claude's last message
2. Adding context from tool usage (e.g., "Edited 3 files")
3. Truncating to ~150 characters for readability

## Limitations

### What Can Be Tracked

The plugin can send notifications for:

- ✅ **Plan Ready** - When Claude creates a plan (PreToolUse hook detects `ExitPlanMode`)
- ✅ **Questions** - When Claude asks questions (PreToolUse hook detects `AskUserQuestion` OR Notification hook fires)
- ✅ **Task Complete** - When Claude finishes work (Stop/SubagentStop hooks analyze completion)
- ✅ **Review Complete** - When Claude finishes code review (Stop/SubagentStop hooks detect review keywords)

### What Cannot Be Tracked

**Important:** The plugin **cannot** detect Claude Code's built-in UI confirmation dialogs.

When you see this prompt:
```
❯ 1. Yes
  2. Yes, allow all edits during this session
  3. No, and tell Claude what to do differently
```

This is a **UI confirmation dialog** shown by Claude Code itself, not an `AskUserQuestion` tool. The plugin has no way to detect when these dialogs appear.

#### Why This Happens

**Event Sequence:**
```
1. Claude decides to use Write/Edit/Bash tool
2. Claude Code shows UI confirmation dialog ← NO HOOK FIRES HERE
3. User approves
4. Tool executes
5. Hook fires (too late for "action required" notification)
```

**Technical Explanation:**

- `AskUserQuestion` = Claude explicitly asking a question (trackable via PreToolUse hook)
- UI Confirmation = Claude Code security feature for file operations (not exposed to hooks)

The difference:
- **AskUserQuestion tool** - Fired when Claude needs information from you (e.g., "Which API should I use?")
- **UI Confirmation** - Fired when Claude Code asks permission for potentially dangerous operations (Write, Edit, Bash)

Since UI confirmations are handled internally by Claude Code **before** any hooks fire, there is no event the plugin can intercept.

#### Workaround

If you want notifications when Claude is waiting for approval:
1. Enable notifications for **Plan Ready** status - you'll be notified when Claude presents a plan
2. Configure auto-approve for trusted operations in Claude Code settings (reduces confirmation dialogs)
3. Wait for Claude Code to add a dedicated hook for UI confirmations (feature request)

## Platform Support

### Fully Supported Platforms

The plugin is fully cross-platform and works on:

| Platform | Status | Desktop Notifications | Sound Playback | Webhooks | Terminal Activation |
|----------|--------|----------------------|----------------|----------|-------------------|
| **macOS** (10.12+) | ✅ Full | osascript/terminal-notifier | afplay | ✅ | ✅ Warp/iTerm/Terminal.app |
| **Linux** | ✅ Full | notify-send | paplay/aplay | ✅ | ❌ Not supported |
| **Windows** (Git Bash/WSL) | ✅ Full | PowerShell Toast | PowerShell | ✅ | ❌ Not supported |

### Cross-Platform Implementation

All critical features work across platforms:
- ✅ Desktop notifications
- ✅ Sound playback
- ✅ Webhook integration
- ✅ Status detection
- ✅ Auto-summarization
- ✅ Lock-based deduplication

The plugin automatically detects your OS and uses the appropriate commands:
- **Temp directories**: Respects `$TMPDIR` (macOS/Linux) and `$TEMP` (Windows)
- **File timestamps**: Uses `stat -f` (macOS) or `stat -c` (Linux/Windows)
- **Notification commands**: Uses `osascript` (macOS), `notify-send` (Linux), or PowerShell (Windows)

### macOS-Only Features

These features only work on macOS but don't affect core functionality on other platforms:
- **Terminal tab activation**: Clicking notifications activates the terminal tab (Warp, iTerm, Terminal.app)
- **Advanced notifications**: Integration with terminal-notifier for richer notifications

### Requirements

**All Platforms:**
- **jq** - Required for JSON parsing
  - macOS: `brew install jq`
  - Linux: `apt install jq` or `yum install jq`
  - Windows: Download from [jqlang.github.io](https://jqlang.github.io/jq/)
  - Verify: `jq --version`

**Linux-Specific:**
- **notify-send** (usually pre-installed with desktop environments)
  - Ubuntu/Debian: `apt install libnotify-bin`
  - Fedora: `dnf install libnotify`

**Windows-Specific:**
- **Git Bash** or **WSL** (Windows Subsystem for Linux)
- PowerShell 5.0+ (pre-installed on Windows 10+)

## 🔔 Webhook Integrations

Send notifications to your favorite messaging platform!

| Platform | Status | Documentation |
|----------|--------|---------------|
| **Slack** | ✅ Supported | [Setup Guide](docs/webhooks/slack.md) |
| **Discord** | ✅ Supported | [Setup Guide](docs/webhooks/discord.md) |
| **Telegram** | ✅ Supported | [Setup Guide](docs/webhooks/telegram.md) |
| **Custom** | ✅ Supported | [Setup Guide](docs/webhooks/custom.md) |

### Quick Start

1. Choose your platform from the table above
2. Follow the setup guide for detailed instructions
3. Update `config/config.json`:

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

**Test your webhook:**
```bash
./test/webhook-tester.sh --preset slack --url "YOUR_WEBHOOK_URL" --message "Test"
```

### Available Presets

- **`slack`** - Slack Incoming Webhooks (send to Slack channels)
- **`discord`** - Discord Webhooks (send to Discord channels)
- **`telegram`** - Telegram Bot API (send to Telegram chats/groups)
- **`custom`** - Generic JSON/text format (for custom endpoints)

For detailed setup instructions, examples, and troubleshooting, see [Webhook Documentation](docs/webhooks/README.md).

⚠️ **Note:** Webhook integrations are community-contributed and not officially tested by the plugin author.

## Known Issues

### Duplicate Notifications (Claude Code Bug)

**Problem:** You may occasionally receive 2-4 duplicate notifications for the same event.

**Affected Versions:** Claude Code v2.0.17 - v2.0.21
**Working Versions:** v2.0.15 and earlier ✅

This is a known bug in Claude Code where hooks are executed multiple times for single events. The plugin includes automatic deduplication using an atomic lock to minimize duplicates. In practice, it guarantees at least one notification and eliminates race windows where two processes could both send.

**Why this happens:**
- Claude Code bug ([#9602](https://github.com/anthropics/claude-code/issues/9602), [#3465](https://github.com/anthropics/claude-code/issues/3465), [#3523](https://github.com/anthropics/claude-code/issues/3523))
- Multiple processes execute simultaneously with different PIDs
- Duplication increases during long sessions (2x → 4x → 10x+)

**Plugin Protection:**
The plugin uses an early duplicate check plus an atomic lock acquisition right before sending:
- ✅ Early duplicate detection without creating a lock (allows retries if a process exits early)
- ✅ Atomic lock via noclobber to prevent simultaneous send
- ✅ Stale locks (>2s) are ignored and safely replaced
- ✅ Guarantees at least 1 notification is sent

**What you'll see:**
```
[2025-XX-XX XX:XX:XX] === Hook triggered: Stop [PID: 12345] ===
[2025-XX-XX XX:XX:XX] Duplicate hook detected early (age: 0s), skipping [PID: 12346]
[2025-XX-XX XX:XX:XX] Desktop notification sent
```

**Workaround:**
- Update to Claude Code v2.0.15 (or wait for fix in future versions)
- Accept occasional duplicates as a trade-off for reliable notifications

### Summary Text Robustness

Notifications now use improved summary cleaning:
- Removes markdown headers, list markers, and backticks
- Flattens newlines, trims, collapses spaces
- If cleaned summary becomes empty, a status-specific default message is used

## Troubleshooting

### Notifications not appearing

1. Check if desktop notifications are enabled in OS settings
2. Verify `config/config.json` has `"enabled": true`
3. Ensure `jq` is installed: `jq --version`

### Sounds not playing

1. Check if sound files exist in `sounds/` directory
2. Verify `"sound": true` in config
3. Test sound command manually:
   - macOS: `afplay sounds/task-complete.mp3`
   - Linux: `paplay sounds/task-complete.mp3`

### Webhook not working

1. Test webhook URL with curl:
   ```bash
   curl -X POST https://your-webhook-url.com -d "test"
   ```
2. Check webhook logs for errors
3. Verify headers are correct

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

GNU General Public License v3.0 (GPL-3.0)

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

**Key points:**
- ✅ Free to use, modify, and distribute
- ✅ Must keep the same GPL-3.0 license
- ✅ Must publish source code of any modifications
- ✅ Must credit original author (777genius)

See [LICENSE](LICENSE) file for full details.

## Support

- Report issues: [GitHub Issues](https://github.com/your-username/claude-notifications/issues)
- Documentation: [Claude Code Docs](https://docs.claude.com/en/docs/claude-code)

## Roadmap

- [ ] Add more notification channels (email, SMS)
- [ ] Support for custom AI summarization (optional)
- [ ] Priority levels for different statuses
- [ ] Notification history/log
- [ ] Web dashboard for notification management
