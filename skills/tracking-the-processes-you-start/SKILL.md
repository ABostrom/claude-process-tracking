---
name: tracking-the-processes-you-start
description: Use when starting a long-running or heavy process from a shell or agent on Windows (an Unreal editor or commandlet, a build, a cook, a test run, a game or server), when handing work back, when a build fails with LNK1104 or a locked DLL, or when an orphaned process is left running and you cannot tell whether it is yours.
---

# Tracking the processes you start

## Overview
Every long-running process you start goes through `Start-Tracked.ps1`, which records its PID and start time in a ledger. `Stop-Tracked.ps1` ends exactly those, with their children. You never kill by name and never guess which PID is yours.

An untracked orphan holds files and DLLs, so the next build fails with errors like `LNK1104`. It also uses the user's CPU and memory, and only they can find it.

## Quick reference
Both scripts live beside this file. The ledger, `runs.tsv`, is written next to them.

| Need | Command |
|---|---|
| Start and wait (exit code passes through) | `Start-Tracked.ps1 -FilePath <exe> -ArgumentList a,b -Owner <task> -StdOut <log>` |
| Start in the background | add `-NoWait`, then poll the log file |
| What is still running | `Stop-Tracked.ps1` |
| End your runs | `Stop-Tracked.ps1 -Owner <task>` |
| End every recorded run | `Stop-Tracked.ps1 -All`, only when the user asks |

`-Owner` names your task, branch or agent. Runs with another owner are not yours to end.

## Rules
- **Launch every heavy process through it.** A process you launched any other way is one you cannot clean up.
- **Before handing back,** run `Stop-Tracked.ps1 -Owner <task>` and include its output in your report.
- **A STUCK line** means the process refused to die, usually a kernel-side hang at exit. Report the PID and that it may need a reboot. Do not retry, and do not quietly work round the locked files.
- **Never kill by name** (`Stop-Process -Name`, `taskkill /IM`). The user's own copy of the program may be running.

## Common mistakes
| Mistake | Fix |
|---|---|
| Launching straight with `Start-Process` or `&` | Use `Start-Tracked.ps1` |
| Killing a PID read from a log | It may be reused; the ledger checks the start time |
| Leaving a helper editor or server open after a pass | End it before the next build |
| Ending `-All` to tidy up | End only `-Owner` yours |
