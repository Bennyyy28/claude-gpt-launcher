# Claude GPT Launcher

A native macOS project picker that opens the normal Claude Code terminal
interface with subscription-backed GPT routing through the local
`raine/claude-code-proxy` backend.

## Requirements

- Apple silicon Mac running macOS 14 or newer
- Claude Code available as `claude`
- `claude-code-proxy` installed and authenticated through its supported login
- Swift 5.9 or newer for source builds

No OAuth token or API key belongs in this repository or in an environment file.

## Install

```zsh
./script/install_backend.sh
./script/build_and_run.sh --install
```

The first command installs the reviewed launcher helper at
`~/.local/bin/claude-gpt`. The second builds and installs the macOS app under
`~/Applications`.

## Use

1. Open `~/Applications/Claude GPT.app`.
2. Choose or drop a Git project folder.
3. Select GPT-5.6 Sol, Terra, or Luna.
4. Click **Open Claude GPT**.

The Terminal session owns the localhost proxy lifecycle. Closing Claude Code
stops the proxy and clears its session-scoped environment variables.

## Codex MCP bridge

The installed app bundles a stdio MCP server with two tools:

- `claude_code_plan`: read-only Claude Code harness consultation.
- `claude_code_edit`: edits through Claude Code without shell or network tools;
  callers must explicitly set `confirmEdits: true`.

Both tools require a Git working tree inside the home directory. Users can set
`CLAUDE_GPT_PROTECTED_REMOTES` to a comma-separated list of remote substrings.
Matching repositories are denied unless a caller explicitly supplies
`allowProtectedRepository: true`.

## Build

```zsh
./script/build_and_run.sh --verify
./script/build_and_run.sh --install
node ./script/mcp_acceptance.mjs "$(swift build --show-bin-path)/ClaudeGPTMCP"
```

Register the optional Codex MCP bridge:

```zsh
codex mcp add claude-gpt-harness -- \
  "$HOME/Applications/Claude GPT.app/Contents/Resources/mcp-bin/claude-gpt-mcp"
```

## Security boundary

The app never stores repository content or OAuth tokens. The proxy stores its
credential in macOS Keychain and listens on `127.0.0.1:18765` only. This remains
a third-party, unsupported OpenAI client configuration.
