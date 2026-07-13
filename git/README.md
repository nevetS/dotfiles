# git

| Platform | Status    | Version |
|----------|-----------|---------|
| Linux    | ✅ Full    | —       |
| macOS    | ✅ Full    | —       |
| Windows  | ✅ Full    | —       |

## What's tracked (public repo)

`config` — editor, diff tool, aliases, pull/rebase defaults, color settings.
No name, email, or signing key paths (these go in local override).

## Local overrides

`~/.gitconfig.local` — name, email, work-specific settings. Add to your `config`:

```ini
[include]
    path = ~/.gitconfig.local
```

## Install path

| Platform | Path |
|----------|------|
| Linux    | `~/` |
| macOS    | `~/` |
| Windows  | `%USERPROFILE%/` |

## TODO

- [ ] Add standard aliases
- [ ] Add difftool/mergetool config
- [ ] Document signing key setup per machine
