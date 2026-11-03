# Starts a process, records it in the run ledger, and waits for it.
# Every editor, commandlet, build or game run an agent starts goes through here,
# so Stop-Tracked.ps1 can end exactly what we started, never anything by name.
param(
	[Parameter(Mandatory)] [string] $FilePath,
	[string[]] $ArgumentList = @(),
	[string] $Owner = 'agent',
	[string] $StdOut,
	[switch] $NoWait
)

$Ledger = Join-Path $PSScriptRoot 'runs.tsv'

$Start = @{ FilePath = $FilePath; PassThru = $true; WindowStyle = 'Hidden' }
if ($ArgumentList.Count) { $Start.ArgumentList = $ArgumentList }
if ($StdOut) { $Start.RedirectStandardOutput = $StdOut; $Start.RedirectStandardError = "$StdOut.err" }

$P = Start-Process @Start
# PID plus start time, so a reused PID is never mistaken for ours.
$Row = "{0}`t{1}`t{2}`t{3}" -f $P.Id, $P.StartTime.ToString('o'), $Owner, (Split-Path $FilePath -Leaf)
Add-Content -Path $Ledger -Value $Row
Write-Output "tracked pid $($P.Id) ($Owner)"

if (-not $NoWait) {
	$P.WaitForExit()
	exit $P.ExitCode
}
