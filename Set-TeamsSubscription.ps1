<#
.SYNOPSIS
Automatically enable all Teams to subscribe its members
.DESCRIPTION
Enable AutoSubscribeNewmembers on all Teams Office 365 groups
Subscribe all members to not enabled groups
#>

#requires -Modules @{ModuleName="ExchangeOnlineManagement";ModuleVersion="3.0.0"}

[CmdletBinding()]
param (
    # Display Name of team or teams to process. Processes all Teams if empty.
    [String[]]$Team
)

$ErrorActionPreference = "STOP"

Connect-ExchangeOnline

$groups = Get-UnifiedGroup -Filter { ResourceProvisioningOptions -eq "Team" } -ResultSize Unlimited | Where-Object { $_.AutoSubscribeNewmembers -eq $False -Or $_.AlwaysSubscribemembersToCalendarEvents -eq $False }
if ($Team) {
    $groups = $groups | Where-Object { $_.DisplayName -in $Team }
}

ForEach ($group in $groups) {
    Write-Output "Processing $($group.DisplayName)"
    # Update group so that new members are added to the subscriber list and will receive calendar events
    Set-UnifiedGroup -Identity $group.ExternalDirectoryObjectId -AutoSubscribeNewmembers:$True -AlwaysSubscribemembersToCalendarEvents
    # Get current members and the subscribers list
    $members = Get-UnifiedGroupLinks -Identity $group.ExternalDirectoryObjectId -LinkType Member
    $subscribers = Get-UnifiedGroupLinks -Identity $group.ExternalDirectoryObjectId -LinkType Subscribers
    # Check each member and if they're not in the subscriber list, add them
    ForEach ($member in $members) {
        If ($member.ExternalDirectoryObjectId -notin $subscribers.ExternalDirectoryObjectId) {
            Add-UnifiedGroupLinks -Identity $group.ExternalDirectoryObjectId -LinkType subscribers -Links $member.PrimarySmtpAddress
            Write-Output "Subscribed $($member.PrimarySmtpAddress) to $($group.DisplayName)"
        }
    }
}