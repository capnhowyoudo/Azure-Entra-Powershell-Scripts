<#
.SYNOPSIS
Retrieves Microsoft Entra ID devices that have not signed in within the last $DaysBack days and exports a summary to CSV, with separate filtering options for enabled and disabled devices.

.DESCRIPTION
This script connects to Microsoft Graph with Device.ReadWrite.All permissions, calculates a date threshold based on $DaysBack,
and retrieves devices whose ApproximateLastSignInDateTime is older than that threshold. 
It allows filtering for enabled or disabled devices separately. The results are exported to a CSV file.

.NOTES
- Requires Microsoft Graph PowerShell SDK
- Requires Device.ReadWrite.All permissions
- Export folder is configurable
- Separate variables allow filtering for Enabled ($Enabled = $true) or Disabled ($Disabled = $true) devices
- To exclude enabled devices, set `$Enabled = $false`
- To exclude disabled devices, set `$Disabled = $false`
- Server-side filtering is used for performance
- Correctly formats $DaysBack as ISO 8601 datetime for Graph queries

.WARNINGS
- ApproximateLastSignInDateTime is periodically updated and may not reflect real-time activity
- Review exported CSV before taking any bulk action
#>

# 1. Connect
Connect-MgGraph -Scopes "Device.ReadWrite.All"

# --- CONFIGURATION ---
$DaysBack = 90                  # Number of days back to consider a device stale
$Enabled = $true                # $true = include enabled devices | $false = exclude
$Disabled = $true               # $true = include disabled devices | $false = exclude
$ExportPath = "C:\Temp\devicelist-olderthan-90days-summary.csv"
# ---------------------

# 2. Calculate the threshold date in ISO 8601 format (DO NOT use quotes)
$dt = (Get-Date).AddDays(-$DaysBack).ToString("yyyy-MM-ddTHH:mm:ssZ")

# 3. Build filter string dynamically
$filterParts = @("approximateLastSignInDateTime le $dt")
if ($Enabled -and -not $Disabled) { $filterParts += "accountEnabled eq true" }
elseif (-not $Enabled -and $Disabled) { $filterParts += "accountEnabled eq false" }
# If both $Enabled and $Disabled are $true, include all devices
# If both $Enabled and $Disabled are $false, no devices will be returned

$FilterString = $filterParts -join " and "

# 4. Run the command with server-side filter for efficiency
Get-MgDevice -All -Filter $FilterString | Select-Object `
    AccountEnabled, `
    DeviceId, `
    OperatingSystem, `
    OperatingSystemVersion, `
    DisplayName, `
    TrustType, `
    ApproximateLastSignInDateTime | `
    Export-Csv -Path $ExportPath -NoTypeInformation

Write-Host "Process complete. Devices exported to $ExportPath"
