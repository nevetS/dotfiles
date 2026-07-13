# ssh

| Platform | Status           | Version |
|----------|------------------|---------|
| Linux    | ✅ Full           | —       |
| macOS    | ✅ Full           | —       |
| Windows  | ❌ Not supported  | —       |

## What's tracked (public repo)

`config.pub` — non-sensitive SSH settings: ControlMaster, multiplexing, keep-alives,
default identity file names, algorithm preferences.

## What's private (Google Drive)

`config.private` — hostnames, jump hosts, work servers, bastion IPs.
Stored at `dotfiles-private/ssh/config.private`.

## Setup

Your `~/.ssh/config` (not tracked) should contain:

```
Include ~/.dotfiles/ssh/config.pub
Include ~/.ssh/config.private
```

The install script symlinks the `ssh/` repo directory to `~/.ssh/` — if you already
have `~/.ssh/config`, resolve the conflict interactively during install.

## TODO

- [ ] Add `config.pub` with ControlMaster defaults
- [ ] Test Include directive ordering on macOS
