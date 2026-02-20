<#
.SYNOPSIS
Identifies Microsoft Entra ID devices that are stale based on last sign-in (using the configurable $DaysBack variable, default 90 days) and optionally deletes them, exporting a detailed report.

.DESCRIPTION
This script connects to Microsoft Graph with Device.ReadWrite.All permissions, calculates a date threshold
(based on $DaysBack), and retrieves devices whose ApproximateLastSignInDateTime is older than that threshold
and match the target enabled/disabled status. 

For enabled devices, it demonstrates how to safely delete them using the configurable $UseWhatIf variable. Disabled devices are reported for auditing.
The results, including action notes, are exported to a CSV file in a configurable folder.

.NOTES
- Requires Microsoft Graph PowerShell SDK
- Requires Device.ReadWrite.All permissions
- Export folder is configurable via $ExportFolder (default: C:\Temp)
- Export filename includes device status and date for tracking
- Uses server-side filtering for efficiency
- ApproximateLastSignInDateTime is updated periodically and may not reflect real-time activity
- To locate **disabled devices**, set `$TargetEnabledStatus = $false`
- To perform actual deletion of devices, set `$UseWhatIf = $false`


.WARNINGS
- Script uses $UseWhatIf for safety; set to `$false` only after validating results
- Deleting devices is destructive—verify before applying in production
- ApproximateLastSignInDateTime is not precise for audit/compliance
- Ensure ExportFolder exists or script will create it
- Review exported CSV before performing bulk changes
#>

# 1. Connect with necessary permissions
Connect-MgGraph -Scopes "Device.ReadWrite.All"

# --- CONFIGURATION ---
$TargetEnabledStatus = $true  # $true to find Enabled devices | $false to find Disabled devices
$DaysBack = -90
$ExportFolder = "C:\Temp"
$UseWhatIf = $true             # $true = simulate deletion; $false = perform actual deletion
# ---------------------

# 2. Date calculation formatted for Graph Filter
$dt = (Get-Date).AddDays($DaysBack).ToString("yyyy-MM-ddTHH:mm:ssZ")

# 3. Get devices with dynamic filter based on your choice
$StatusFilter = $TargetEnabledStatus.ToString().ToLower()

$Devices = Get-MgDevice -All -Filter "approximateLastSignInDateTime le $dt and accountEnabled eq $StatusFilter" `
  -Property "id","deviceId","displayName","operatingSystem","approximateLastSignInDateTime","accountEnabled"

$Results = foreach ($Device in $Devices) {
  try {
      # 4. Action
      if ($TargetEnabledStatus -eq $true) {
          # Deleting an enabled stale device, controlled by $UseWhatIf
          if ($UseWhatIf) {
              Remove-MgDevice -DeviceId $Device.Id -WhatIf
              $ActionNote = "WhatIf: Device would be DELETED"
          } else {
              Remove-MgDevice -DeviceId $Device.Id
              $ActionNote = "Device DELETED"
          }
      } else {
          # Reporting on already disabled devices
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
