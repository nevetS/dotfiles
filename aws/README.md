# aws

| Platform | Status    | Version (CLI) |
|----------|-----------|---------------|
| Linux    | ✅ Full    | —             |
| macOS    | ✅ Full    | —             |
| Windows  | ✅ Full    | —             |

## What's tracked (public repo)

`config` — profiles, regions, output format, SSO configuration. **No credentials.**

## What's private (Google Drive)

`credentials` — access keys. Stored at `dotfiles-private/aws/credentials`.

## Local overrides

Machine-specific profile overrides: `dotfiles-private/machines/<hostname>/aws/config.local`

## Install path

| Platform | Path |
|----------|------|
| Linux    | `~/.aws/` |
| macOS    | `~/.aws/` |
| Windows  | `%USERPROFILE%/.aws/` |

## TODO

- [ ] Document SSO setup steps per environment
- [ ] Document profile naming convention
