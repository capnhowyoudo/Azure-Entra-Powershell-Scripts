<#
.SYNOPSIS
Identifies and (WhatIf) disables stale Entra ID devices inactive for 90 days.

.DESCRIPTION
This script connects to Microsoft Graph with Device.ReadWrite.All permissions,
calculates a 90-day inactivity threshold, and retrieves all enabled devices
whose ApproximateLastSignInDateTime is older than that threshold.

For each matching device, the script:

- Attempts to disable the device using Update-MgDevice
- Uses -WhatIf to simulate the change (no modification occurs)
- Captures device details into a results object
- Outputs status indicating the device would be disabled

Results are exported to a date-stamped CSV file in C:\Temp.

This script is intended for audit and validation before executing actual
device disable operations.

.NOTES
Safety Mechanism:
- The Update-MgDevice command uses the -WhatIf parameter.
- No devices will be disabled while -WhatIf is present.

To Execute Changes:
- Remove the -WhatIf switch from Update-MgDevice when ready
  to perform actual device disable actions.

Requirements:
- Microsoft Graph PowerShell SDK
- Device.ReadWrite.All permission
- Appropriate administrative privileges

Recommended Practice:
- Always review the generated CSV before removing -WhatIf
- Consider running during a maintenance window
#>

# 1. Connect
Connect-MgGraph -Scopes "Device.ReadWrite.All"

# 2. Date calculation
$dt = (Get-Date).AddDays(-90).ToString("yyyy-MM-ddTHH:mm:ssZ")

# 3. Get devices with explicit property selection
$Devices = Get-MgDevice -All -Filter "approximateLastSignInDateTime le $dt and accountEnabled eq true" `
           -Property "id","deviceId","displayName","operatingSystem","approximateLastSignInDateTime","accountEnabled"

$Results = foreach ($Device in $Devices) {
    try {
        # 4. FIXED: Using the colon syntax to prevent positional parameter errors
        Update-MgDevice -DeviceId $Device.Id -AccountEnabled:$false -WhatIf
        
        [PSCustomObject]@{
            DisplayName                    = $Device.DisplayName
            DeviceId                       = $Device.DeviceId
            Id                             = $Device.Id
            OperatingSystem                = $Device.OperatingSystem
            ApproximateLastSignInDateTime  = $Device.ApproximateLastSignInDateTime
            Status                         = "WhatIf: Device would be disabled"
        }
    }
    catch {
        # This will now catch and display the specific error message if it fails again
        Write-Host "Failed to process: $($Device.DisplayName) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 6. Export
if ($Results) {
    $Results | Export-Csv -Path "C:\Temp\disabled-stale-devices-$(Get-Date -Format 'yyyyMMdd').csv" -NoTypeInformation
    Write-Host "Process complete. Check C:\Temp for the CSV." -ForegroundColor Green
}
