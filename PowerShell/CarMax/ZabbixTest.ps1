#Get all the location grounps in AD. 
$GroupList = @()
$Creds = Get-Credential


# Create list of OU to search for locations
@(
    "OU=HomeOffice,OU=CarMaxWorkstations,DC=KMX,DC=LOCAL",
    "OU=Stores,OU=CarMaxWorkstations,DC=KMX,DC=LOCAL"
    ) | ForEach-Object -Process {

    # Get AD OUs contained in the locations listed above.
    Get-ADOrganizationalUnit -Filter * -SearchBase $_ | ForEach-Object -Process {

        # Fiter out undesirable OU Names based off first index.
        Switch($_.DistinguishedName.Split(",")[0]){
            OU=HomeOffice { Write-Host "Found Home Office OU, Skipping..."}
            OU=Kiosks {Write-Host "Found Kiosks Sub OU, Skipping..."}
            OU=EnterpriseSystems { Write-Host "Found Enterprise Systems OU, Skipping"}
            OU=Robotics {Write-Host "Found Robotics OU Skipping..."}
            OU=Pilot { Write-Host "Found Pilot OU, Skipping..."}
            OU=Shutdown_Script {Write-Host "Found shutdown Script OU, Skipping..."}
            OU=7001-LAB {Write-Host "Skipping Malformed OU..."}
            OU=VirtualDesktops {Write-Host "Found Virtual Desktops OU, Skipping..."}
            OU=Stores {Write-Host "Found Stores OU, Skipping..."}
            # If none of the Above, add it to our group list that needs to be made in Zabbix
            default {Write-Host "FOUND OU: $_"; $GroupList += $_.split("=")[1]}
        }
    }
}

Clear-Host
Write-Host "FOUND THE FOLLOWING LOCATIONS IN AD:"
Write-Host $GroupList

#Great, We've Generated our list of locations, now Lets sign in to zabbix so we can check them 
Connect-Zabbix -IPAddress 172.18.100.34 -PSCredential $Creds -noSSL

#Okay now that we're connected Lets check our list of host groups for location groups that match
$GroupList | ForEach-Object -Process {
    if(Get-ZabbixHostGroup -GroupName "Location: $_"){
        Write-Host "Found Exist Host Group: Location $_"
    } else {
        Write-Host "MISSING GROUP: Location: $_"
        #New-ZabbixHostGroup -Name "Location: $_"
    }
    Write-Host "Location: $_"

}

