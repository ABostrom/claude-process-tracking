# Starts a process, records it in the run ledger, and waits for it.
# Every editor, commandlet, build or game run an agent starts goes through here,
# so Stop-Tracked.ps1 can end exactly what we started, never anything by name.
param(
	[Parameter(Mandatory)] [string] $FilePath,
	[string[]] $ArgumentList = @(),
	[string] $Owner = 'agent',
	[string] $StdOut,
	[switch] $NoWait,
	# Wait until no other owner's run is live, then start: one heavy run on the machine at a time.
	[switch] $WaitForClear,
	[int] $PollSeconds = 60
)

$Ledger = Join-Path $PSScriptRoot 'runs.tsv'

function Get-OthersLive {
	if (-not (Test-Path $Ledger)) { return @() }
	foreach ($Line in Get-Content $Ledger) {
		$Id, $Started, $Who, $Exe = $Line -split "`t"
		if ($Who -eq $Owner) { continue }
		$Other = Get-Process -Id $Id -ErrorAction SilentlyContinue
		try { $Live = $Other -and -not $Other.HasExited -and $Other.StartTime.ToString('o') -eq $Started } catch { $Live = $false }
		if ($Live) { "$Exe ($Who) pid $Id" }
	}
}

$Start = @{ FilePath = $FilePath; PassThru = $true; WindowStyle = 'Hidden' }
if ($ArgumentList.Count) { $Start.ArgumentList = $ArgumentList }
if ($StdOut) { $Start.RedirectStandardOutput = $StdOut; $Start.RedirectStandardError = "$StdOut.err" }

# The check and the launch happen under one machine-wide lock, so two callers cannot both see a clear machine.
$Gate = New-Object System.Threading.Mutex($false, 'Global\TrackedRunsGate')
$Held = $false
try {
	while ($true) {
		$Held = $Gate.WaitOne()
		$Busy = if ($WaitForClear) { @(Get-OthersLive) } else { @() }
		if ($Busy.Count -eq 0) { break }
		$Gate.ReleaseMutex(); $Held = $false
		Write-Output ("waiting for: " + ($Busy -join ', '))
		Start-Sleep -Seconds $PollSeconds
	}
	$P = Start-Process @Start
	# PID plus start time, so a reused PID is never mistaken for ours.
	$Row = "{0}`t{1}`t{2}`t{3}" -f $P.Id, $P.StartTime.ToString('o'), $Owner, (Split-Path $FilePath -Leaf)
	Add-Content -Path $Ledger -Value $Row
}
finally {
	if ($Held) { $Gate.ReleaseMutex() }
	$Gate.Dispose()
}
Write-Output "tracked pid $($P.Id) ($Owner)"

if (-not $NoWait) {
	$P.WaitForExit()
	exit $P.ExitCode
}
