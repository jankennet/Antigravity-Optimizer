# Antigravity Low-End Optimizer

A zero-dependency script (bash for Linux, PowerShell for Windows) that tunes [Antigravity IDE](https://antigravity.google) for low-end hardware — 2-core CPUs, Celeron/Pentium/Atom chips, 4–8 GB RAM, and integrated graphics — then launches it.

It patches `settings.json` to cut down on:

- Editor rendering overhead (minimap, smooth scrolling, bracket colorization, etc.)
- File-change storms from `node_modules`, `.git`, `dist`, `build`, and similar directories
- Git background polling
- Search/indexing workload

## Install

### Linux (CachyOS, Arch, and most other distros)

```bash
curl -fsSL https://raw.githubusercontent.com/jankennet/Antigravity-Optimizer/main/antigravity-optimizer.sh -o ~/.local/bin/antigravity-lowend && chmod +x ~/.local/bin/antigravity-lowend
```

Make sure `~/.local/bin` is in your `PATH`, then run `antigravity-lowend`.

**Manual:**

```bash
git clone https://github.com/jankennet/Antigravity-Optimizer.git
cd Antigravity-Optimizer
chmod +x antigravity-lowend.sh
./antigravity-lowend.sh
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/jankennet/Antigravity-Optimizer/main/install.ps1 | iex
```

This downloads the script to `%LOCALAPPDATA%\antigravity-lowend\bin`, adds it to your PATH, and registers `antigravity-lowend` as a command. Restart your terminal, then run `antigravity-lowend`.

If script execution is blocked, run PowerShell as your normal user (not elevated) and either use the one-liner above (which pipes into `iex` and isn't affected by execution policy) or, for manual use:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
git clone https://github.com/jankennet/Antigravity-Optimizer.git
cd Antigravity-Optimizer
.\antigravity-optimizer.ps1
```

## Requirements

**Linux:** `bash`, `python3` (used to safely rewrite `settings.json`), Antigravity installed at `/usr/bin/antigravity-ide`.

**Windows:** PowerShell 5.1+ (ships with Windows 10/11), Antigravity installed via the standard installer (auto-detected under Program Files / LocalAppData\Programs, or on PATH).

## Usage

**Linux:**

```bash
antigravity-lowend                     # detect hardware, optimize, and launch
antigravity-lowend --optimize          # apply settings only, don't launch
antigravity-lowend --profile <name>    # auto | normal | low | extreme
antigravity-lowend --safe              # disable GPU acceleration (max compatibility)
antigravity-lowend --status            # show detected hardware and current profile
antigravity-lowend --reset             # restore the most recent settings backup
```

**Windows:**

```powershell
antigravity-lowend                     # detect hardware, optimize, and launch
antigravity-lowend -Optimize           # apply settings only, don't launch
antigravity-lowend -Profile <name>     # auto | normal | low | extreme
antigravity-lowend -Safe               # disable GPU acceleration (max compatibility)
antigravity-lowend -Status             # show detected hardware and current profile
antigravity-lowend -Reset              # restore the most recent settings backup
```

Any extra arguments are passed straight through to the Antigravity binary.

## Profiles

| Profile   | Chosen automatically when...            | Notes                                   |
|-----------|------------------------------------------|------------------------------------------|
| `normal`  | ≥5 threads and >8 GB RAM                 | Conservative tuning only                 |
| `low`     | ≤4 threads or ≤8 GB RAM                  | Trims more editor/terminal overhead      |
| `extreme` | ≤2 threads, ≤4 GB RAM, or known low-power CPU (Celeron N/Atom/Pentium Silver/etc.) | Aggressive tuning for agent responsiveness |
| `safe`    | Set manually via `--safe` / `-Safe`      | Same as `extreme`, plus `--disable-gpu`  |

`auto` (the default) picks a profile from detected CPU thread count, RAM, and CPU model — same logic on both platforms.

## Backups & reset

Every run backs up your existing `settings.json` before making changes.

- Linux: `~/.local/state/antigravity-lowend/backups/`
- Windows: `%LOCALAPPDATA%\antigravity-lowend\backups\`

Run `antigravity-lowend --reset` (Linux) or `antigravity-lowend -Reset` (Windows) to restore the most recent backup.

## Known limitations

This script optimizes editor/IDE-level overhead (rendering, file watching, git polling, indexing). It does **not** fix UI freezes that occur specifically during agent output — this appears to be an upstream Antigravity bug reported across various hardware, not scoped to low-end machines. Try `Antigravity: Restart Agent Service` (Ctrl+Shift+P) or clearing the app's GPU cache folder if you hit this; it's unrelated to what this script configures.

