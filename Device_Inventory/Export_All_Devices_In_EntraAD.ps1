<#
.SYNOPSIS
Exports an Entra ID (Azure AD) device summary report to CSV.

.DESCRIPTION
This script connects to Microsoft Graph using the Device.Read.All permission,
retrieves all registered devices, selects key device properties, and exports
the results to a CSV file.

The exported report includes:

- AccountEnabled
- DeviceId
- OperatingSystem
- OperatingSystemVersion
- DisplayName
- TrustType
- ApproximateLastSignInDateTime

The CSV file is saved to:
C:\temp\devicelist-summary-titan.csv

This script is commonly used for device inventory, auditing, compliance
checks, and stale device analysis.

.NOTES
Requirements:
- Microsoft Graph PowerShell SDK installed
- Appropriate permissions to grant Device.Read.All
- Access to Microsoft Graph

Output:
- CSV file containing device summary data

Use Cases:
- Device inventory reporting
- Security audits
- Compliance validation
- Device lifecycle management
#>

# 1. Connect
Connect-MgGraph -Scopes "Device.ReadWrite.All"

#2. Get Device Data
Get-MgDevice -All | Select-Object `
    AccountEnabled, `
    DeviceId, `
    OperatingSystem, `
    OperatingSystemVersion, `
    DisplayName, `
    TrustType, `
    ApproximateLastSignInDateTime | `
    Export-Csv -Path "C:\temp\devicelist-summary.csv" -NoTypeInformation
