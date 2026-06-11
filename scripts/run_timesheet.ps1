# ===========================================================================
# run_timesheet.ps1 — Wrapper for unattended scheduled runs (Windows)
#
# Called by Windows Task Scheduler.
# Cleans up stale browser locks, runs the fill+submit script, and
# writes timestamped output to logs\.
# ===========================================================================

$ErrorActionPreference = "Stop"

# ---- Resolve paths --------------------------------------------------------
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$VenvPython = Join-Path $ProjectDir ".venv\Scripts\python.exe"
$LogDir     = Join-Path $ProjectDir "logs"
$ProfileDir = Join-Path $ProjectDir "browser_state\profile"

# ---- Create log directory -------------------------------------------------
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile   = Join-Path $LogDir "timesheet_$Timestamp.log"

# ---- Helper: log with timestamp -------------------------------------------
function Write-Log {
    param([string]$Message)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Output $line
}

# ---- Start logging --------------------------------------------------------
& {
    Write-Log "=========================================="
    Write-Log "SharePoint Timesheet Bot — Scheduled Run"
    Write-Log "=========================================="
    Write-Log "Project dir : $ProjectDir"
    Write-Log "Python      : $VenvPython"
    Write-Log "Log file    : $LogFile"
    Write-Log ""

    # ---- Pre-flight: kill stale Chromium & remove lock --------------------
    Get-Process -Name "chromium" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    $LockFile = Join-Path $ProfileDir "SingletonLock"
    if (Test-Path $LockFile) { Remove-Item $LockFile -Force }
    Write-Log "Pre-flight cleanup done"

    # ---- Verify venv exists -----------------------------------------------
    if (-not (Test-Path $VenvPython)) {
        Write-Log "ERROR: Python venv not found at $VenvPython"
        Write-Log "Run: python -m venv .venv && pip install -r requirements.txt"
        exit 1
    }

    # ---- Run the fill script ----------------------------------------------
    Write-Log "Starting timesheet fill + submit..."
    Write-Log ""

    Set-Location $ProjectDir
    & $VenvPython scripts\test_fill_timesheet.py --submit
    $ExitCode = $LASTEXITCODE

    Write-Log ""
    Write-Log "Script exited with code: $ExitCode"

    # ---- Cleanup ----------------------------------------------------------
    Get-Process -Name "chromium" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    if (Test-Path $LockFile) { Remove-Item $LockFile -Force }

    Write-Log "Post-run cleanup done"
    Write-Log "=========================================="
    Write-Log "Finished at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Log "=========================================="

    exit $ExitCode

} 2>&1 | Tee-Object -FilePath $LogFile
