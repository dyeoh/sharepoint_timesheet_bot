# ===========================================================================
# install_task.ps1 — Install a Windows Task Scheduler task for scheduled runs
# ===========================================================================

$ErrorActionPreference = "Stop"

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$TaskName   = "SharePointTimesheetBot"
$RunScript  = Join-Path $ProjectDir "scripts\run_timesheet.ps1"
$LogDir     = Join-Path $ProjectDir "logs"

Write-Host "Installing SharePoint Timesheet Bot scheduled task..." -ForegroundColor Cyan
Write-Host ""

# ---- Ensure run script exists ---------------------------------------------
if (-not (Test-Path $RunScript)) {
    Write-Host "ERROR: Run script not found: $RunScript" -ForegroundColor Red
    exit 1
}

# ---- Ensure logs directory exists -----------------------------------------
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

# ---- Remove existing task if present --------------------------------------
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host "Removing existing task..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# ---- Build task components ------------------------------------------------
$Action  = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NonInteractive -ExecutionPolicy Bypass -File `"$RunScript`"" `
    -WorkingDirectory $ProjectDir

# Every Friday at 09:00
$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At "09:00"

$Settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable

# ---- Register the task ----------------------------------------------------
Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -RunLevel Limited `
    -Description "Automatically fills and submits SharePoint timesheets every Friday at 9 AM." | Out-Null

Write-Host "Task registered: $TaskName" -ForegroundColor Green
Write-Host ""
Write-Host "Schedule : Every Friday at 09:00" -ForegroundColor White
Write-Host "Logs     : $LogDir\" -ForegroundColor White
Write-Host ""
Write-Host "Useful commands:" -ForegroundColor White
Write-Host "  Check status : Get-ScheduledTask -TaskName '$TaskName'"
Write-Host "  Run now      : Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "  Disable      : Disable-ScheduledTask -TaskName '$TaskName'"
Write-Host "  Remove       : .\scripts\uninstall_task.ps1"
Write-Host ""
Write-Host "Done! The bot will run automatically every Friday at 9 AM." -ForegroundColor Green
