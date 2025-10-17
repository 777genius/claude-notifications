# Sound Files

This directory contains sound files for different notification statuses.

## Quick Start: Use System Sounds

**The easiest option is to use system sounds** - they work immediately without downloading anything!

The default `config.json.example` uses macOS system sounds:
- `Glass.aiff` - Task completed (crisp, clean)
- `Ping.aiff` - Review completed (subtle ping)
- `Funk.aiff` - Question (distinctive)
- `Hero.aiff` - Plan ready (triumphant)

All available macOS system sounds are in `/System/Library/Sounds/`.

## Optional: Custom Sound Files

If you prefer custom sounds, place them in this directory:

- `task-complete.mp3` - Played when a task is completed
- `review-complete.mp3` - Played when a review is completed
- `question.mp3` - Played when Claude has a question
- `plan-ready.mp3` - Played when a plan is ready

Then use `config.json.example-custom-sounds` as your config template.

### Adding Your Own Sounds

1. Place your sound files in this directory
2. Update `config/config.json` to reference your sound files
3. Supported formats: MP3, WAV, OGG, AIFF

## Free Sound Resources

You can find free notification sounds at:

- [Freesound](https://freesound.org/)
- [Zapsplat](https://www.zapsplat.com/)
- [Notification Sounds](https://notificationsounds.com/)

## Disabling Sounds

To disable sounds, set `"sound": false` in your `config/config.json`:

```json
{
  "notifications": {
    "desktop": {
      "enabled": true,
      "sound": false
    }
  }
}
```

## Note

Sound files are optional. The plugin will work without them, but you won't hear audio notifications.
