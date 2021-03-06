<#
.SYNOPSIS
Automatically subscribe to Teams to get Events
.DESCRIPTION
Enable AutoSubscribeNewMembers on all Teams Office 365 Groups
Subscribe all members to not enabled groups
.PARAMETER Organization
Domain of the Organization used when connecting in AzureAutomation Account
.PARAMETER Team
Only process given team
#>

[CmdletBinding()]
param (
    [String]$Organization,
    [String]$Team
)

$ErrorActionPreference = "STOP"

if ($PSPrivateMetadata.JobId) {
    Write-Output "Connecting via Automation Run As Account"
    $servicePrincipalConnection = Get-AutomationConnection -Name "AzureRunAsConnection"
    Connect-ExchangeOnline -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint -AppId $servicePrincipalConnection.ApplicationId -Organization $Organization –ShowBanner:$false
}
else {
    Connect-ExchangeOnline
}

$Groups = Get-UnifiedGroup -Filter { ResourceProvisioningOptions -eq "Team" } -ResultSize Unlimited | Where-Object { $_.AutoSubscribeNewMembers -eq $False -Or $_.AlwaysSubscribeMembersToCalendarEvents -eq $False }
if ($Team) {
    $Groups = $Groups | Where-Object { $_.DisplayName -eq $Team }
}

ForEach ($Group in $Groups) {
    Write-Output "Processing $($Group.DisplayName)"
    # Update group so that new members are added to the subscriber list and will receive calendar events
    Set-UnifiedGroup -Identity $Group.ExternalDirectoryObjectId -AutoSubscribeNewMembers:$True -AlwaysSubscribeMembersToCalendarEvents
    # Get current members and the subscribers list
    $Members = Get-UnifiedGroupLinks -Identity $Group.ExternalDirectoryObjectId -LinkType Member
    $Subscribers = Get-UnifiedGroupLinks -Identity $Group.ExternalDirectoryObjectId -LinkType Subscribers
    # Check each member and if they're not in the subscriber list, add them
    ForEach ($Member in $Members) {
        If ($Member.ExternalDirectoryObjectId -notin $Subscribers.ExternalDirectoryObjectId) {
            # Not in the list
            #    Write-Host "Adding" $Member.PrimarySmtpAddress "as a subscriber"
            Add-UnifiedGroupLinks -Identity $Group.ExternalDirectoryObjectId -LinkType Subscribers -Links $Member.PrimarySmtpAddress
            Write-Output "Subscribed $($Member.PrimarySmtpAddress) to $($Group.DisplayName)"
        }
    }
}