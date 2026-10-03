# Universal-Run-Script

A tiny, dependency-free Windows batch launcher. 

*** I did not proof read any of this slop salad. ***

This was intended to be lazy just to fire off various scripts and save some defaults / behaviors.

Basically just copy it into whatever dir you have code junks in, it will scan for whatever file types listed below and prompt to to choose one, then has some additional things, then keep it that way or edit the ini to have it always do the same thing if that is what you are into, I only judge in silence. 

## Features

- **Finds launchable files automatically** — any `.ps1`, `.py`, `.exe`, or `.bat` in the same folder (the launcher excludes itself). One match runs automatically; several give you a numbered picker.
- **Always launches in a new window**, so behavior is identical whether or not you elevate. PowerShell keeps its window open with `-NoExit`; Python and batch run under `cmd /k`; executables run directly.
- **Optional elevation** — a `y/N` prompt; "yes" just adds a UAC `-Verb RunAs` to the launch.
- **Arguments** — passed straight through to the script.
- **Post-run command** — a command run in the launcher window *after* the script is spawned (e.g. a quick `curl` test), with a configurable delay so the launched process has time to come up first.
- **Remembered defaults** — your choices are saved to `run_defaults.ini`. Later runs offer them with a single `[Y/n]`.
- **Fully unattended mode** — set `NoPrompt=true` in the ini and it runs the saved defaults with zero prompts.
- **No dependencies** — pure Windows batch. Nothing to install.

## Requirements

- Windows (uses `cmd`, `powershell`, and `ping`, all built in).
- For `.py` files: Python, launched via the `py` launcher with a fallback to `python`.
- A post-run command like the example below uses `curl.exe`, which ships with Windows 10 1803+.

## Quick start

1. Put `Run-Script.bat` in the same folder as the script(s) you want to run.
2. Double-click it.
3. Answer the prompts (script / elevated / arguments / post-run command).

That's it. Your answers are saved, so the next run is just one keypress.

## How it works

### First run

With no `run_defaults.ini` present, you're prompted in order:

1. **Which file** — skipped automatically if only one is found.
2. **Run elevated?** — `y/N`.
3. **Arguments** — anything to pass to the script; blank for none.
4. **Post-run command** — a command to run in the launcher window after the script starts; blank for none.

The file is launched in a new window, and your choices are written to `run_defaults.ini`.

### Later runs

With a `run_defaults.ini` present, it shows the saved choices and asks one thing:

```
Run with these saved defaults? [Y/n]:
```

- **Yes** (or Enter) — runs them as-is.
- **No** — drops back into the full prompts and updates the file.

### Launch targets

| Extension | How it's launched |
|-----------|-------------------|
| `.ps1`    | `powershell -NoExit -ExecutionPolicy Bypass -File ...` |
| `.py`     | `py "..."` (falls back to `python`), inside `cmd /k` |
| `.bat`    | `cmd /k "..."` |
| `.exe`    | run directly via `Start-Process` |

Elevation only adds `-Verb RunAs` to the launch (the Windows UAC prompt).

## The defaults file (`run_defaults.ini`)

Created automatically on first run. Edit it by hand to change behavior, or delete it to be prompted fresh.

```ini
# Run-Script defaults - delete this file to be prompted fresh.
# Set NoPrompt=true to always run these defaults with no prompts.
# AfterLaunch controls this launcher window when done: pause, countdown, or none.
# PostRunDelay = seconds to wait after launch before the PostRun command.
NoPrompt=false
AfterLaunch=countdown
PostRunDelay=3
Script=Toggle-IPv6.ps1
Elevated=yes
Args=-Action Disable
PostRun=
```

| Key | Values | Meaning |
|-----|--------|---------|
| `NoPrompt` | `true` / `false` | `true` runs the saved defaults with **no prompts at all**. Falls back to prompting only if the saved script can't be found. |
| `AfterLaunch` | `pause` / `countdown` / `none` | What the launcher window does when finished. `pause` waits for a keypress, `countdown` shows a 3-2-1 and closes, `none` closes immediately. Defaults to `countdown` (or `pause` when a `PostRun` command is set). |
| `PostRunDelay` | whole seconds | How long to wait after launching before the post-run command runs, giving the process time to start. Defaults to `3`. `0` fires immediately. |
| `Script` | file name | The saved file to run (resolved against what's in the folder). |
| `Elevated` | `yes` / `no` | Whether to launch elevated. |
| `Args` | any | Arguments passed to the script. |
| `PostRun` | any | Command run in the launcher window after launch. |

`NoPrompt`, `AfterLaunch`, and `PostRunDelay` are honored in unattended mode too — so a single double-click can launch something, run a check, and show you the result with no interaction.

## Examples

### Run a maintenance script as admin

`run_defaults.ini`:

```ini
NoPrompt=false
AfterLaunch=countdown
PostRunDelay=3
Script=Toggle-IPv6.ps1
Elevated=yes
Args=-Action Disable
PostRun=
```

Double-click, press Enter to accept the defaults, and it launches `Toggle-IPv6.ps1 -Action Disable` in an elevated window.

### Launch a proxy and test it, fully unattended

Start a local proxy, wait for it to come up, then confirm the exit IP — with no prompts:

```ini
NoPrompt=true
AfterLaunch=pause
PostRunDelay=3
Script=gost_launch-IPRoyal-Minneapolis-Rotate.bat
Elevated=yes
Args=
PostRun=curl.exe -x socks5h://127.0.0.1:11080 https://api.ipify.org
```

One double-click: the proxy launches in its own window, the launcher waits 3 seconds, runs the `curl` test, prints the exit IP, and pauses so you can read it.

## Notes & limitations

- **A `.bat` or console `.exe`** manages its own window; the launcher doesn't control when it closes.
- **The post-run delay is a fixed wait**, not a "wait until the port is listening" check. Increase `PostRunDelay` for slow-starting processes.
- **Arguments and post-run commands** work for normal flags and commands. Characters that are special to `cmd` — `&`, `|`, `<`, `>`, `(`, `)` — aren't fully supported in the saved defaults file (for example a URL with `&` query parameters). Keep saved commands simple, or run complex ones interactively.
- **Resetting:** delete `run_defaults.ini` to be prompted from scratch.

## License

MIT — do whatever you like.
