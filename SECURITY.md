# Security Policy

## Reporting a vulnerability

Use the repository host's private vulnerability-reporting feature. Do not open
a public issue containing exploit details, credentials, repository contents, or
OAuth material.

Include the affected version, platform, reproduction steps, impact, and any
suggested mitigation. Never include live tokens; use clearly fake placeholders.

## Security boundary

Claude GPT Launcher is a local developer tool, not an OS sandbox. It runs under
the current user's permissions and sends selected repository context through
the configured model provider. Use disposable environments for untrusted
repositories and review changes before committing them.
