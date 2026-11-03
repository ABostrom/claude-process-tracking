# Ends processes Start-Tracked.ps1 recorded, with their child trees.
# Only ledger rows whose PID still has the recorded start time are touched.
#   Stop-Tracked.ps1              lists what is still running
#   Stop-Tracked.ps1 -Owner x     ends the runs owned by x
#   Stop-Tracked.ps1 -All         ends every recorded run
param([string] $Owner, [switch] $All)

$Ledger = Join-Path $PSScriptRoot 'runs.tsv'
if (-not (Test-Path $Ledger)) { 'no runs recorded'; return }

$Keep = @()
foreach ($Line in Get-Content $Ledger) {
	$Id, $Started, $Who, $Exe = $Line -split "`t"
	$P = Get-Process -Id $Id -ErrorAction SilentlyContinue
	$Ours = $P -and $P.StartTime.ToString('o') -eq $Started
	if (-not $Ours) { continue }   # finished, or the PID now belongs to someone else

	if ($All -or ($Owner -and $Who -eq $Owner)) {
		# Children first (shader workers, crash reporter), then the run itself.
		Get-CimInstance Win32_Process -Filter "ParentProcessId=$Id" -ErrorAction SilentlyContinue |
			ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
		Stop-Process -Id $Id -Force -ErrorAction SilentlyContinue
		$null = $P.WaitForExit(5000)
		if (Get-Process -Id $Id -ErrorAction SilentlyContinue) {
			"STUCK pid $Id $Exe ($Who): did not exit, likely hung in the kernel; needs a reboot"
			$Keep += $Line
		} else {
			"ended pid $Id $Exe ($Who)"
		}
	} else {
		"running pid $Id $Exe ($Who) since $Started"
		$Keep += $Line
	}
}
Set-Content -Path $Ledger -Value $Keep
