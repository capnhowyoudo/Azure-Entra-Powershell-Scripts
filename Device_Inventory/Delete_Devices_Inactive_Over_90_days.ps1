<#
.SYNOPSIS
Identifies Microsoft Entra ID devices that are stale based on last sign-in (Default 90 days) and optionally deletes them, with flexible inclusion/exclusion of enabled or disabled devices.

.DESCRIPTION
Connects to Microsoft Graph, calculates a date threshold based on $DaysBack, and retrieves devices whose ApproximateLastSignInDateTime is older than that threshold.
Devices can be filtered to include enabled devices, disabled devices, or both using the $IncludeEnabled and $IncludeDisabled variables.
Enabled devices can be deleted (simulated or actual), while disabled devices are reported for auditing.
Results are exported to a CSV file.

.NOTES
- Requires Microsoft Graph PowerShell SDK
- Requires Device.ReadWrite.All permissions
- Export folder is configurable via $ExportFolder
- `$IncludeEnabled = $true` to include enabled devices; `$false` excludes enabled devices completely from results
- `$IncludeDisabled = $true` to include disabled devices; `$false` excludes disabled devices completely from results
- `$UseWhatIf = $true` to simulate deletions; `$false` to perform actual deletion
- Correctly formats $DaysBack as ISO 8601 datetime for Graph filtering

.WARNINGS
- Deleting devices is destructive; always verify with -WhatIf first
- ApproximateLastSignInDateTime may not be real-time accurate
- Ensure ExportFolder exists or script will create it
- Review CSV before taking action
#>

# 1. Connect
Connect-MgGraph -Scopes "Device.ReadWrite.All"

# --- CONFIGURATION ---
$DaysBack = 90                 # Number of days back to consider a device stale
$IncludeEnabled = $true        # Include enabled devices
$IncludeDisabled = $true       # Include disabled devices
$ExportFolder = "C:\Temp"
$UseWhatIf = $true             # $true = simulate deletion | $false = perform actual deletion
# ---------------------

# 2. Calculate threshold date in ISO 8601 format (DO NOT use quotes)
$dt = (Get-Date).AddDays(-$DaysBack).ToString("yyyy-MM-ddTHH:mm:ssZ")

# 3. Build dynamic Graph filter
$filterParts = @("approximateLastSignInDateTime le $dt")

if ($IncludeEnabled -and -not $IncludeDisabled) { $filterParts += "accountEnabled eq true" }
elseif (-not $IncludeEnabled -and $IncludeDisabled) { $filterParts += "accountEnabled eq false" }
# If both $IncludeEnabled and $IncludeDisabled are $true, include all devices
# If both are $false, no devices will be returned

$FilterString = $filterParts -join " and "

# 4. Get devices
$Devices = Get-MgDevice -All -Filter $FilterString `
    -Property "id","deviceId","displayName","operatingSystem","approximateLastSignInDateTime","accountEnabled"

$Results = foreach ($Device in $Devices) {
    try {
        # 5. Action
        if ($Device.AccountEnabled -and $IncludeEnabled) {
            if ($UseWhatIf) {
                Remove-MgDevice -DeviceId $Device.Id -WhatIf
                $ActionNote = "WhatIf: Device would be DELETED"
            } else {
                Remove-MgDevice -DeviceId $Device.Id
                $ActionNote = "Device DELETED"
            }
        } elseif (-not $Device.AccountEnabled -and $IncludeDisabled) {
            $ActionNote = "Audit: Device is already disabled"
        } else {
            $ActionNote = "Excluded by configuration"
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

# 6. Export results
if ($Results) {
    if (!(Test-Path $ExportFolder)) { New-Item -ItemType Directory -Path $ExportFolder }
    
    $StatusText = if ($IncludeEnabled -and -not $IncludeDisabled) { "enabled" } `
                  elseif (-not $IncludeEnabled -and $IncludeDisabled) { "disabled" } `
                  else { "all" }
    $FileName = "$ExportFolder\stale-$StatusText-devices-$(Get-Date -Format 'yyyyMMdd').csv"
    
    $Results | Export-Csv -Path $FileName -NoTypeInformation
    Write-Host "Process complete. $($Results.Count) $StatusText devices identified in $FileName" -ForegroundColor Green
} else {
    Write-Host "No devices found matching the stale criteria for current configuration" -ForegroundColor Yellow
}
