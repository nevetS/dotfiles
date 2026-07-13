# kube

| Platform | Status    | Version (kubectl) |
|----------|-----------|-------------------|
| Linux    | ✅ Full    | —                 |
| macOS    | ✅ Full    | —                 |
| Windows  | ✅ Full    | —                 |

## What's tracked (public repo)

This directory contains only this README. No kubeconfig is public.

## What's private (Google Drive)

`config` — full kubeconfig with cluster endpoints, credentials, contexts.
Stored at `dotfiles-private/kube/config`.

## Local overrides

Per-machine kubeconfigs: `dotfiles-private/machines/<hostname>/kube/`

## Install path

| Platform | Path |
|----------|------|
| Linux    | `~/.kube/` |
| macOS    | `~/.kube/` |
| Windows  | `%USERPROFILE%/.kube/` |

## TODO

- [ ] Document context naming convention
- [ ] Consider KUBECONFIG env var to merge multiple config files per machine
