# Contributing

Thanks for helping improve Claude GPT Launcher.

## Before opening a pull request

1. Keep the change focused and avoid unrelated refactors.
2. Never commit OAuth material, API keys, private repository content, personal
   paths, or real account identifiers.
3. Preserve localhost-only networking and explicit edit authorization.
4. Run the complete validation suite:

```zsh
npm test
npm run pack:check
```

5. Explain the user-facing effect and any security-boundary change.

## Reporting security problems

Follow [SECURITY.md](SECURITY.md). Do not open a public issue containing exploit
details or credentials.
