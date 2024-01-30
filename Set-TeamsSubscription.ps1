<#
.SYNOPSIS
Automatically enable all Teams to subscribe its Members
.DESCRIPTION
Enable AutoSubscribeNewMembers on all Teams Office 365 Groups
Subscribe all members to not enabled groups
#>

#requires -Modules @{ModuleName="ExchangeOnlineManagement";ModuleVersion="3.0.0"}

[CmdletBinding()]
param (
    # Display Name of the team to process. Processes all Teams if empty.
    [String]$Team
)

$ErrorActionPreference = "STOP"

Connect-ExchangeOnline

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