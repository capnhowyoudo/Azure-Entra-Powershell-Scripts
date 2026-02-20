<#
.SYNOPSIS
Retrieves Microsoft Entra ID devices that have not signed in within the last 90 days and exports a summary to CSV.

.DESCRIPTION
This script connects to Microsoft Graph with Device.ReadWrite.All permissions, calculates a date threshold
(90 days prior to execution), and queries devices whose ApproximateLastSignInDateTime is older than that threshold.
The resulting device attributes are selected and exported to a CSV file for reporting or cleanup analysis.

.NOTES
- Requires Microsoft Graph PowerShell SDK
- Requires appropriate Graph permissions (Device.ReadWrite.All)
- Uses server-side filtering for better performance
- ApproximateLastSignInDateTime is periodically updated and may not reflect real-time activity
- Export location: C:\Temp\devicelist-olderthan-90days-summary.csv

.WARNINGS
- ApproximateLastSignInDateTime is not guaranteed to be precise for audit/compliance decisions
- Ensure the scope Device.ReadWrite.All is approved in your tenant
- Review exported data before performing bulk disable/delete actions
- Script overwrites the CSV if the file already exists
#>

# 1. Connect
Connect-MgGraph -Scopes "Device.ReadWrite.All"

# 2. Calculate the date in ISO 8601 format (required for Graph filtering)
$dt = (Get-Date).AddDays(-90).ToString("yyyy-MM-ddTHH:mm:ssZ")

# 3. Run the command with a server-side filter for efficiency
Get-MgDevice -All -Filter "approximateLastSignInDateTime le $dt" | Select-Object `
    AccountEnabled, `
    DeviceId, `
    OperatingSystem, `
    OperatingSystemVersion, `
    DisplayName, `
    TrustType, `
    ApproximateLastSignInDateTime | `
    Export-Csv -Path "C:\Temp\devicelist-olderthan-90days-summary.csv" -NoTypeInformation
