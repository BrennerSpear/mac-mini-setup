# Discord — OpenClaw Integration Notes

## Setup
- Create a Discord bot at https://discord.com/developers/applications
- Add bot to your server with appropriate permissions
- Configure in openclaw.json under `channels.discord`
- Set `groupPolicy: "allowlist"` to control which channels the bot responds in

## Key Settings
- `requireMention: false` — bot responds to all messages in allowed channels
- `dmPolicy: "pairing"` — DMs require device pairing
- `ackReactionScope: "all"` — bot reacts to acknowledge messages

## Platform Formatting
- No markdown tables (use bullet lists instead)
- Wrap links in `<>` to suppress embeds
- Max message length: 2000 chars (auto-splits longer messages)
- Use `filePath` for sending files (any readable path works)

## Channel-Level System Prompts
Each Discord channel/thread can have its own system prompt that gets injected into every message in that channel. Set this in the guild config under `channels`:

```json
"guilds": {
  "YOUR_GUILD_ID": {
    "channels": {
      "CHANNEL_ID": {
        "systemPrompt": "This channel is for project X. Focus on..."
      }
    }
  }
}
```

Use this to give the agent persistent context about what a channel is for — project details, rules, goals, relevant repos, etc. The prompt appears as system context on every message in that channel without anyone needing to repeat it.

## Channel Organization Tips
- Use categories to group channels by function
- Forum channels work well for project-specific discussions
- Thread channels keep conversations organized
- Pair each channel with a system prompt for best results
