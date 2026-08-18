# Antigravity Low-End Optimizer

A zero-dependency bash script that tunes [Antigravity IDE](https://antigravity.google) for low-end hardware — 2-core CPUs, Celeron/Pentium/Atom chips, 4–8 GB RAM, and integrated graphics — then launches it.

It patches `settings.json` to cut down on:

- Editor rendering overhead (minimap, smooth scrolling, bracket colorization, etc.)
- File-change storms from `node_modules`, `.git`, `dist`, `build`, and similar directories
- Git background polling
- Search/indexing workload
- Agent-output rendering pressure while an AI agent is actively editing files

## Install

**One-liner (CachyOS, Arch, and most other Linux distros):**

```bash
curl -fsSL https://raw.githubusercontent.com/jankennet/Antigravity-Optimizer/main/antigravity-lowend.sh -o ~/.local/bin/antigravity-lowend && chmod +x ~/.local/bin/antigravity-lowend
```

Make sure `~/.local/bin` is in your `PATH`, then run `antigravity-lowend`.

**Manual:**

```bash
git clone https://github.com/jankennet/Antigravity-Optimizer.git
cd Antigravity-Optimizer
chmod +x antigravity-lowend.sh
./antigravity-lowend.sh
```

## Requirements

- `bash`, `python3` (used to safely rewrite `settings.json`)
- Antigravity IDE installed at `/usr/bin/antigravity-ide`

## Usage

```bash
antigravity-lowend                     # detect hardware, optimize, and launch
antigravity-lowend --optimize          # apply settings only, don't launch
antigravity-lowend --profile <name>    # auto | normal | low | extreme
antigravity-lowend --safe              # disable GPU acceleration (max compatibility)
antigravity-lowend --status            # show detected hardware and current profile
antigravity-lowend --reset             # restore the most recent settings backup
```

Any extra arguments are passed straight through to the Antigravity binary.

## Profiles

| Profile   | Chosen automatically when...            | Notes                                   |
|-----------|------------------------------------------|------------------------------------------|
| `normal`  | ≥5 threads and >8 GB RAM                 | Conservative tuning only                 |
| `low`     | ≤4 threads or ≤8 GB RAM                  | Trims more editor/terminal overhead      |
| `extreme` | ≤2 threads, ≤4 GB RAM, or known low-power CPU (Celeron N/Atom/Pentium Silver/etc.) | Aggressive tuning for agent responsiveness |
| `safe`    | Set manually via `--safe`                | Same as `extreme`, plus `--disable-gpu`  |

`auto` (the default) picks a profile from detected CPU thread count, RAM, and CPU model.

## Backups & reset

Every run backs up your existing `settings.json` to `~/.local/state/antigravity-lowend/backups/` before making changes. Run `antigravity-lowend --reset` to restore the most recent backup.

## License

MIT