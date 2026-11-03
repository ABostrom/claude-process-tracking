# Process tracking for Claude Code

A Claude Code skill that makes agents end only the processes they started.

Agents launch editors, builds and test runs, then lose track of them. The orphans hold DLLs, break the next build and use up the machine. Killing by name is worse, because it takes the user's own editor with it.

`Start-Tracked.ps1` records each run's PID and start time. `Stop-Tracked.ps1` lists them and ends only those, with their child processes, keyed by an owner name. A PID reused by another program is never mistaken for one of ours. A process that will not die is reported as STUCK rather than retried.

Windows and PowerShell only.

## Install
Copy `skills/tracking-the-processes-you-start` into either:
- `~/.claude/skills/` for every project, or
- `<project>/.claude/skills/` for one project.

Claude Code picks it up from its description. To make sure subagents use it, add a line to their briefs: "Launch heavy processes through skill `tracking-the-processes-you-start`, and run `Stop-Tracked.ps1 -Owner <task>` before handing back."

## Use
```powershell
.\Start-Tracked.ps1 -FilePath UnrealEditor-Cmd.exe -ArgumentList '<proj>','-run=...' -Owner mylane -StdOut run.log -NoWait
.\Stop-Tracked.ps1                 # list live runs
.\Stop-Tracked.ps1 -Owner mylane   # end mine
```
