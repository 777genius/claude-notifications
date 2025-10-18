## Claude Notifications - Documentation

### Notification cooldown: suppressing questions after task completion

This plugin can temporarily suppress the "Claude Has Questions" notification when it happens immediately after a "Task Completed" event. This prevents noisy back-to-back alerts at the end of a task.

#### Configuration

- Key: `notifications.suppressQuestionAfterTaskCompleteSeconds`
- Type: integer (seconds)
- Default: `7`
- Special values:
  - `0` → disables cooldown (no suppression)
  - Any positive integer → cooldown window in seconds

Example:

```json
{
  "notifications": {
    "desktop": { "enabled": true, "sound": true },
    "webhook": { "enabled": false, "url": "", "format": "json", "headers": {} },
    "suppressQuestionAfterTaskCompleteSeconds": 7
  }
}
```

#### Behavior

- When a `task_complete` status is produced, the handler records a per-session timestamp.
- If a `question` status would be sent and the last `task_complete` for the same session happened within the configured window, the `question` notification is suppressed.
- Applies to both sources of `question`:
  - PreToolUse with `tool_name = "AskUserQuestion"`
  - Generic `Notification` hook classified as `question`
- Other statuses are unaffected (e.g., `plan_ready`, `review_complete`, `task_complete`).

#### Notes and lifecycle

- The cooldown is session-scoped. The plugin stores per-session state in the OS temp directory and checks it before emitting `question`.
- The configuration is read on every hook invocation; changing the value takes effect immediately (no restart required).
- Duplicate hook executions are already mitigated by lock-based deduplication; the cooldown check runs after status resolution and before sending notifications.

#### Troubleshooting

- "Question still appears immediately":
  - Verify the key is present and non-zero in `config/config.json`.
  - Check `notification-debug.log` for lines like:
    - `Recorded last_task_complete_ts=...`
    - `Question suppressed: task_complete Xs ago (< Ys)`
  - Ensure the events belong to the same session (session IDs must match).

- "Too aggressive suppression":
  - Reduce the window or set to `0` to disable.

#### Logging examples

```
[2025-10-18 12:00:00] Recorded last_task_complete_ts=1697620800 in /var/.../claude-session-state-<session>.json
[2025-10-18 12:00:04] Question suppressed: task_complete 4s ago (< 7s)
```

---

### Other docs

- Webhooks: `docs/webhooks/README.md`
- Test guides: `docs/testing.md`
- Coverage setup: `docs/coverage-setup.md`


