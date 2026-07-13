# dotfiles

Personal dotfiles for Linux, macOS, and Windows. Public config lives here;
private config (credentials, kubeconfig, SSH hosts, machine-local overrides)
is stored in Google Drive and pulled at install time via rclone.

## Structure

```
.dotfiles/
├── manifest.yaml        # declares what goes where, per platform
├── install.sh           # Linux/macOS installer
├── install.ps1          # Windows installer
├── bin/                 # helper scripts
├── aws/                 # AWS CLI config (no credentials)
├── bash/                # bash config
├── emacs/               # Emacs config
├── git/                 # git config
├── kube/                # kubectl (README only — config is private)
├── ssh/                 # SSH public settings (no hostnames)
└── zsh/                 # zsh config
```

## Quick start

### Linux / macOS

```bash
git clone git@github.com:nevetS/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./bin/install-deps.sh   # installs python3, rclone; prompts rclone config if needed
./install.sh
```

### Windows (PowerShell, run as Administrator or with Developer Mode enabled)

```powershell
git clone git@github.com:nevetS/dotfiles.git $HOME/.dotfiles
cd $HOME\.dotfiles
.\bin\install-deps.ps1
.\install.ps1
```

## Install options

| Flag             | Shell         | Effect                                      |
|------------------|---------------|---------------------------------------------|
| `-y` / `--yes`   | bash          | Non-interactive: skip conflicts             |
| `-Yes`           | PowerShell    | Non-interactive: skip conflicts             |
| `--skip-private` | bash          | Skip rclone pull                            |
| `-SkipPrivate`   | PowerShell    | Skip rclone pull                            |
| `--dry-run`      | bash          | Show actions without executing              |
| `-DryRun`        | PowerShell    | Show actions without executing              |

## Private config (Google Drive)

Sensitive config is stored in Google Drive under `dotfiles-private/`:

```
dotfiles-private/
├── aws/credentials
├── kube/config
├── ssh/config.private
└── machines/
    ├── <hostname>/          # machine-local overrides
    └── ...
```

The install script syncs this via rclone using a remote named `gdrive`.
Set up rclone once per machine with `rclone config` (type: drive, name: gdrive).

## Machine-local overrides

	`Create a directory in Drive at `dotfiles-private/machines/<hostname>/` mirroring
the structure of `$HOME`. Files there are symlinked into place after the main
install. If no directory exists for the current hostname, a warning is logged
and the install continues.

## Updating dotfiles

Since public files are symlinked from the repo, edits are live immediately.
To push changes:

```bash
cd ~/.dotfiles
git add -p        # review changes
git commit -m "..."
git push
```

Private config is managed separately in Google Drive — no git workflow needed.

## Platform support

See the README in each config directory for per-tool platform support status.

## Dependencies

- `python3` — manifest parsing (stdlib only, no pip packages required)
- `rclone` — private config sync from Google Drive

Run `./bin/install-deps.sh` (or `.\bin\install-deps.ps1`) to install.
