<#
.SYNOPSIS
Identifies Microsoft Entra ID devices that are stale based on last sign-in (using the configurable $DaysBack variable, default 90 days) and optionally disables them, exporting a detailed report.

.DESCRIPTION
This script connects to Microsoft Graph with Device.ReadWrite.All permissions, calculates a date threshold
(based on $DaysBack), and retrieves devices whose ApproximateLastSignInDateTime is older than that threshold
and match the target enabled/disabled status. 

For enabled devices, it demonstrates how to safely disable them using `-WhatIf`. Disabled devices are reported for auditing.
The results, including action notes, are exported to a CSV file in a configurable folder.

.NOTES
- Requires Microsoft Graph PowerShell SDK
- Requires Device.ReadWrite.All permissions
- Export folder is configurable via $ExportFolder (default: C:\Temp)
- Export filename includes device status and date for tracking
- Uses server-side filtering for efficiency
- ApproximateLastSignInDateTime is updated periodically and may not reflect real-time activity
- To locate **disabled devices**, set `$TargetEnabledStatus = $false`

.WARNINGS
- Script uses -WhatIf for safety; remove -WhatIf only after validating results
- Disabling devices impacts end users—verify before applying in production
- ApproximateLastSignInDateTime is not precise for audit/compliance
- Ensure ExportFolder exists or script will create it
- Review exported CSV before performing bulk changes
#>

# 1. Connect with necessary permissions
Connect-MgGraph -Scopes "Device.ReadWrite.All"

# --- CONFIGURATION ---
$TargetEnabledStatus = $true  # SET TO: $true to find Enabled devices | $false to find Disabled devices
$DaysBack = -90
$ExportFolder = "C:\Temp"
# ---------------------

# 2. Date calculation formatted for Graph Filter
$dt = (Get-Date).AddDays($DaysBack).ToString("yyyy-MM-ddTHH:mm:ssZ")

# 3. Get devices with dynamic filter based on your choice
# We convert the boolean to a lowercase string for the OData filter
$StatusFilter = $TargetEnabledStatus.ToString().ToLower()

$Devices = Get-MgDevice -All -Filter "approximateLastSignInDateTime le $dt and accountEnabled eq $StatusFilter" `
    -Property "id","deviceId","displayName","operatingSystem","approximateLastSignInDateTime","accountEnabled"

$Results = foreach ($Device in $Devices) {
    try {
        # 4. Action (Using -WhatIf for safety)
        # If targeting ENABLED devices, you likely want to Disable or Delete.
        # If targeting DISABLED devices, you might just be auditing or re-enabling.
        if ($TargetEnabledStatus -eq $true) {
            # Example: Disabling an enabled stale device
            Update-MgDevice -DeviceId $Device.Id -AccountEnabled:$false -WhatIf
            $ActionNote = "WhatIf: Device would be DISABLED"
        } else {
            # Example: Just reporting on already disabled devices
            $ActionNote = "Audit: Device is already disabled"
        }

        [PSCustomObject]@{
            DisplayName                   = $Device.DisplayName
            DeviceId                      = $Device.DeviceId
            Id                            = $Device.Id
            OperatingSystem               = $Device.OperatingSystem
            ApproximateLastSignInDateTime = $Device.ApproximateLastSignInDateTime
            AccountEnabled                = $Device.AccountEnabled
            Action                        = $ActionNote
        }
    }
    catch {
        Write-Host "Failed to process: $($Device.DisplayName) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 5. Export results
if ($Results) {
    if (!(Test-Path $ExportFolder)) { New-Item -ItemType Directory -Path $ExportFolder }
    
    $StatusText = if ($TargetEnabledStatus) { "enabled" } else { "disabled" }
    $FileName = "$ExportFolder\stale-$StatusText-devices-$(Get-Date -Format 'yyyyMMdd').csv"
    
    $Results | Export-Csv -Path $FileName -NoTypeInformation
    Write-Host "Process complete. $($Results.Count) $StatusText devices identified in $FileName" -ForegroundColor Green
} else {
    Write-Host "No devices found matching the stale criteria for status: $TargetEnabledStatus" -ForegroundColor Yellow
}
