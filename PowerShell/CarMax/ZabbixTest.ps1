#Get all the location grounps in AD. 
$GroupList = @()
$Creds = Get-Credential


# Create list of OU to search for locations
@(

    ) | ForEach-Object -Process {

    # Get AD OUs contained in the locations listed above.
    Get-ADOrganizationalUnit -Filter * -SearchBase $_ | ForEach-Object -Process {

        # Fiter out undesirable OU Names based off first index.
        Switch($_.DistinguishedName.Split(",")[0]){
            OU=
            OU=
            OU=
            OU=
            OU=
            OU=
            OU=
            OU=
            OU=
            # If none of the Above, add it to our group list that needs to be made in Zabbix
            default {Write-Host "FOUND OU: $_"; $GroupList += $_.split("=")[1]}
        }
    }
}

Clear-Host
Write-Host "FOUND THE FOLLOWING LOCATIONS IN AD:"
Write-Host $GroupList

#Great, We've Generated our list of locations, now Lets sign in to zabbix so we can check them 
Connect-Zabbix -IPAddress  -PSCredential $Creds -noSSL

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

