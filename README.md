# dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io). The primary
target is **Windows** (PowerShell 7); **Linux** is supported best-effort.

Setting up a machine is one command: it installs chezmoi, applies this config,
clones a couple of upstream config repos, installs the base toolset, and restores
VS Code extensions.

## What is managed

| Area | Target | Notes |
| --- | --- | --- |
| PowerShell 7 profile | `~/.config/powershell/` | Restructured out of `Documents\PowerShell`; a loader stub is written to the real `$PROFILE` on Windows. Includes the first-party `CompletionManager` module. |
| Git | `~/.config/git/config` | Portable settings only. Identity and machine/work-specific bits live in `~/.config/git/config.local` (never versioned). |
| oh-my-posh | `~/.config/oh-my-posh/` | Custom `kanagawa-wave` theme, moved out of the install dir (which is wiped on upgrade). |
| delta | `~/.config/delta/` | kanagawa diff themes. |
| Script Manager (`sm`) | `~/.config/sm/` | Config + templates. |
| gitui | `~/.config/gitui` · `%APPDATA%\gitui` | Key bindings + theme. |
| bat | `~/.config/bat` · `%APPDATA%\bat` | kanagawa themes; cache rebuilt on bootstrap. |
| VS Code | `~/.config/Code/User` · `%APPDATA%\Code\User` | `settings.json`, `keybindings.json`; extensions reinstalled from a list. |
| Neovim | `~/.config/nvim` · `%LOCALAPPDATA%\nvim` | External clone of [`sravioli/nvim`](https://github.com/sravioli/nvim). |
| WezTerm | `~/.config/wezterm` | External clone of [`sravioli/wezterm`](https://github.com/sravioli/wezterm). |
| Tabliss | `~/.config/tabliss/tablissng.json` | Browser new-tab page config. Import manually via the extension's **Settings → Import** (work links stripped). |

OS-divergent configs (bat, gitui, VS Code) are stored **once** under
`~/.config`. On Windows a `run_onchange` script links them into `%APPDATA%`:
gitui and bat get directory junctions (live link, no admin required), while VS
Code's `settings.json`/`keybindings.json` are copied in (its `User` folder also
holds machine state that must not be redirected).

## Bootstrap a new machine

### Windows

```powershell
# One command: installs chezmoi into ~/bin, then clones + applies your dotfiles.
# chezmoi clones with its built-in git, so no prerequisites are required first;
# the bootstrap scripts then install Git, a PATH-managed chezmoi, and the toolset.
iex "&{$(irm 'https://get.chezmoi.io/ps1')} -b '~/bin' -- init --apply https://github.com/Simone-Fidanza_wkl/dotfiles.git"
```

Prefer winget? Install chezmoi first, then init in a new terminal:

```powershell
winget install --id twpayne.chezmoi --source winget
chezmoi init --apply https://github.com/Simone-Fidanza_wkl/dotfiles.git
```

### Linux

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply https://github.com/Simone-Fidanza_wkl/dotfiles.git
```

### First-run prompts

chezmoi asks a few questions and stores the answers in its local config (never
committed):

- **Git author name / email** — written to `~/.config/git/config.local`.
- **Git signing key** — optional; leave blank if you don't sign commits.
- **Machine type** — `work` or `personal`.
- **Install work-laptop apps** — DBeaver, Rancher Desktop, Codex, and the Copilot
  app; defaults to yes on a `work` machine.

## Work vs. personal

Nothing machine- or employer-specific is versioned. In particular the committed
git config contains **no** identity, signing key, internal Azure DevOps orgs/feeds,
`safe.directory` entries, or local repo paths. All of that belongs in the
per-machine, non-versioned `~/.config/git/config.local`, which chezmoi seeds once
from the init prompts and then never overwrites. Edit it freely:

```sh
notepad $HOME\.config\git\config.local   # Windows
$EDITOR ~/.config/git/config.local        # Linux
```

`config.local` ships with commented examples for a work-only clone alias,
`[safe]`, and `[maintenance]`.

## Not versioned

A couple of things are deliberately excluded and set up per machine:

- **`~/.npmrc`** — contains a live Azure DevOps PAT. Recreate it per machine with a
  fresh token (e.g. `vsts-npm-auth` or the feed's "Connect to feed" snippet).
  **Never commit it.**
- **Start-page / wallpaper images** (`met-museum`, `tabliss`; ~370 MB) — already
  synced through OneDrive. Use a dedicated asset repo if you want them in Git.

## Day-to-day

```sh
chezmoi edit <file>     # edit a managed file in the source repo
chezmoi diff            # preview what apply would change
chezmoi apply           # apply pending changes to the machine
chezmoi update          # pull the repo and apply
chezmoi apply --refresh-externals   # force-refresh nvim/wezterm clones
```

## Layout

```
.chezmoi.toml.tmpl              # init prompts + script interpreter config
.chezmoiexternal.toml.tmpl      # nvim + wezterm upstream clones
.chezmoiignore                  # repo metadata kept out of $HOME
.chezmoidata/packages.yaml      # winget / apt / cargo + VS Code extension lists
.chezmoiscripts/                # install / mirror / cache / extensions / loader scripts
dot_config/                     # ~/.config tree (powershell, git, delta, sm, bat, gitui, Code, tabliss, ...)
```
