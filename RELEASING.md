# Releasing

Releases have two independent artifacts: the npm source package and a notarized
Apple-silicon app archive. Never put npm, Apple ID, or App Store Connect secrets
in this repository or in command-line arguments.

## npm

Run the full validation, then publish from a clean release commit:

```zsh
npm test
npm run pack:check
npm publish --access public --provenance
```

For later releases, configure npm trusted publishing for
`Bennyyy28/claude-gpt-launcher` and workflow `publish-npm.yml`. The release
workflow then publishes without a long-lived npm token. Trusted publishing
requires npm 11.5.1 or newer; the workflow pins a compatible npm release.

## Notarized macOS archive

Create a Keychain-backed `notarytool` profile once. Enter the app-specific
password only at the interactive prompt:

```zsh
xcrun notarytool store-credentials claude-gpt-launcher-notary \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID"
```

Build, sign, submit, staple, assess, and checksum the archive:

```zsh
DEVELOPER_ID_APPLICATION="Developer ID Application: YOUR NAME (YOUR_TEAM_ID)" \
NOTARYTOOL_PROFILE="claude-gpt-launcher-notary" \
npm run release:macos
```

The distributable ZIP and its SHA-256 file are written to `dist/release/`.
Upload both to the matching GitHub release. The script fails closed unless
Apple accepts the submission and Gatekeeper accepts the stapled app.
