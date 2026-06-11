# ===========================================================================
# uninstall_task.ps1 — Remove the Windows Task Scheduler task
# ===========================================================================

$ErrorActionPreference = "Stop"

$TaskName = "SharePointTimesheetBot"

Write-Host "Uninstalling SharePoint Timesheet Bot scheduled task..." -ForegroundColor Cyan
Write-Host ""

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Task removed: $TaskName" -ForegroundColor Green
} else {
    Write-Host "Task not found: $TaskName" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done! The scheduled bot has been removed." -ForegroundColor Green
