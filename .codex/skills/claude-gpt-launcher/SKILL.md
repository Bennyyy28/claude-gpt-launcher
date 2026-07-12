---
name: claude-gpt-launcher
description: Install, diagnose, open, unregister, or remove Claude GPT Launcher and its Codex MCP bridge. Use when a user asks to set up the launcher, verify prerequisites, manage the claude-gpt-harness MCP, or troubleshoot installation state on an Apple silicon Mac.
---

# Claude GPT Launcher

Start with a read-only diagnostic:

```zsh
claude-gpt-launcher doctor --json
```

If the command is missing, install it from npm:

```zsh
npm install --global claude-gpt-launcher
```

Install the backend helper and native app explicitly:

```zsh
claude-gpt-launcher install
```

Register the optional Codex bridge only when requested:

```zsh
claude-gpt-launcher mcp install --enable-edits
claude-gpt-launcher mcp status --json
```

For sensitive repositories, pass comma-separated remote substrings:

```zsh
claude-gpt-launcher mcp install --enable-edits --protected-remotes "company/production,example/private-app"
```

Use `claude-gpt-launcher open` to open the installed app. Use
`claude-gpt-launcher mcp remove` to remove only the MCP registration. Run
`claude-gpt-launcher uninstall` only when the user explicitly asks to remove
the app, backend helper, and MCP registration.

Never request, print, extract, or pass OAuth tokens through CLI flags. Report
missing provider authentication and direct the user to the provider-supported
login flow.
