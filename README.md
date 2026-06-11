# dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io). Primary target
is **Windows** (PowerShell 7); **Linux** is supported on a best-effort basis.

A new machine is set up by installing chezmoi and running a single command, which
applies the configuration, clones a couple of upstream config repos, installs the
base toolset, and reinstalls VS Code extensions.

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

On first run chezmoi prompts for:

- **Git author name / email** — written to `~/.config/git/config.local`.
- **Git signing key** — optional; leave blank if you don't sign commits.
- **Machine type** — `work` or `personal`; stored for future per-machine templating.

These answers are saved in chezmoi's local config and **never committed**.

## Work vs. personal (read this on a work laptop)

Nothing machine- or employer-specific is versioned. In particular the committed
git config contains **no** identity, signing key, internal Azure DevOps orgs/feeds,
`safe.directory` entries, or local repo paths. All of that belongs in the
per-machine, non-versioned `~/.config/git/config.local`, which chezmoi seeds once
from the init prompts and then never overwrites. Edit it freely:

```sh
chezmoi cd            # jump to the source repo (optional)
notepad $HOME\.config\git\config.local   # Windows
$EDITOR ~/.config/git/config.local        # Linux
```

`config.local` ships with commented examples for a work-only clone alias,
`[safe]`, and `[maintenance]`.

## Manual steps (intentionally not automated)

- **`~/.npmrc`** — contains a live Azure DevOps PAT, so it is **not** versioned.
  Recreate it per machine with your feed registry and a fresh token (e.g. via
  `vsts-npm-auth` or by pasting the feed's "Connect to feed" snippet). Never
  commit this file.
- **VPN auto-run task** — a PowerShell task that auto-connected a corporate VPN on
  a specific home network was deliberately excluded; it is machine/employer
  specific.
- **Windows PowerShell 5.1** — the loader stub only wires up PowerShell 7 (`pwsh`),
  which is what these dotfiles target. 5.1 is left untouched.
- **Linux extras** — WezTerm and PowerShell 7 are not in the apt list; install them
  from their official repos if needed. `gitui` and `delta` are installed via
  `cargo`, and `oh-my-posh` via its install script.
- **Wallpaper / start-page images** — the `met-museum` and `tabliss` picture folders
  (~370 MB) are intentionally **not** versioned here; they already sync through
  OneDrive. Use a dedicated Git LFS or asset repo to version them if needed.

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
