#
# AUTHOR : DJ Kemmet
# OCD:     8/22
# PURPOSE: This script extracts the Templates and all elements associated with those templates for the purposes of backing up and restoring these
#          these configurations into a new / standby zabbix instance. This script obviously does not back up Collected Data, Hosts, or Maps.

# Connect to our server, define the scope, and make some lists. 
Connect-Zabbix -IPAddress -noSSL
$OurTemplates = @()
$OurConfiguredTemplates = @()
$OurConfiguredItems = @()
$OurConfiguredActions = @()

#Backup our TEMPLATES.
Write-Host "Backing up Zabbix Templates..."
Start-Sleep -Seconds 5
# Enumerate our templates and get their actual representation in data.
 $OurTemplates | ForEach-Object -Process {
    Clear-Host
    Write-Host "Backing Up template $_..."
    $OurConfiguredTemplates += Get-ZabbixTemplate -TemplateName $_ | ConvertTo-Json
    Get-ZabbixTemplate -TemplateName $_ | ConvertTo-Json
    Start-Sleep -seconds 2
}


#Backup our ITEMS.
Write-Host "Backing up Zabbix Items..."
# Enumerate our templates and 
$OurTemplates | ForEach-Object -Process {
    #Clear-Host
    Write-Host "Backing Up Items from template $_..."
    $OurConfiguredItems += Get-ZabbixItem -TemplateID (Get-ZabbixTemplate $_ | Select-Object TemplateId).templateid
   Get-ZabbixTemplate -TemplateName $_ | ConvertTo-Json
   Start-Sleep -Seconds 2
}

#Backup our ACTIONS
Write-Host "Backing up Zabbix Actions..."
$OurConfiguredActions += Get-ZabbixAction | ConvertTo-JSON


#Make a hard-backup
Write-Host "Creating 'hard' backups of each to user dir..."

$OurConfiguredItems | out-File -FilePath C:\Users\\ZabbixItems.json
$OurConfiguredActions | out-File -FilePath C:\Users\\ZabbixActions.json
$OurConfiguredTemplates | out-File -FilePath C:\Users\\ZabbixTemplates.json

Write-Host "Disconnecting from Production Instance..."
Disconnect-Zabbix


Write-Host "Connecting To Dev Instance..."
Connect-Zabbix -IPAddress ... -noSSL 

$DebugHere = $true


Write-Host $OurTemplates
