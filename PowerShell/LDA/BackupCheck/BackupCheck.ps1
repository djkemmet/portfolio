# Simple disk verification script that provides 2 points of inspection
    # 1. Do the year of any dates for the files created = 1980, If they do, That disk is bad and needs to be replaced
    # 2. Are there any more or less than 3 disks on the system? if so, that machine is non standard and needs to be adjusted. 

#
# THIS SCRIPT IS RESPONSIBLE FOR REMOTELY LOGGING IN TO ALL SERVERS AND WORKSTATIONS IN THE TARGETD OU AND CHECKING THE VHD FILES
# FOR CORRUPTION SO THEY CAN BE REPLACED OR REBUILT TO AVOID A STORE FAILING AND BEING DOWN FOR 1-4 DAYS.
#

$TargetedComputers = @()
$InspectionResults = @()

# Define our Scope
## Server PCs
Get-ADComputer -Server <SERVER_ADDRESS> -Filter '*' -SearchBase "<AD_OU>" | ForEach-Object -Process {   
    $TargetedComputers += $_.DNSHostName
}

## Manager PCs
Get-ADComputer -Server <SERVER_ADDRESS> -Filter '*' -SearchBase "<AD_OU>" | ForEach-Object -Process {   
    $TargetedComputers += $_.DNSHostName
}
# Work our scope by...
$TargetedComputers | Foreach-object -Process {

    # Focus on a computer and get some data we need
    $ComputerWereFocusedOn = $_
    $TargetedComputerVHDs = @()

    # Now Get It's manager and server disks. 
    Try {
        $ServerDisks = Invoke-Command -ComputerName $ComputerWereFocusedOn -ScriptBlock { Get-ChildItem -Path "X:\VDISKS\SRVR"} -ErrorVariable ServerDiskCheckFail -ErrorACtion Stop
        $ManagerDisks = Invoke-COmmand -ComputerName $ComputerWereFocusedOn -ScriptBlock { Get-CHildItem -Path "X:\VDISKS\MNGR"} -ErrorVariable ManagerDiskCheckFail -ErrorAction Stop
        $TargetedComputerVHDs += $ServerDisks
        $TargetedComputerVHDs += $ManagerDisks
    } Catch {
        Switch($ServerDiskCheckFail[0].HResult){
            -2146233087 {$InspectionResults += "$(Get-Date): ACTION ITEM - Could not connect to $($ComputerWereFocusedOn). Please Investigate"}
            default {Write-Host "Something Happened that I don't understand. I should tell someone."}
        }
    }


    #Write-Host "$(Get-Date): $($ComputerWereFocusedOn) has $(($TargetedComputerVHDs).count) disks"
    #Add-Content -Path C:\Users\dkemmet\Desktop\DISKCOUNT.txt -Value "$(Get-Date): $($ComputerWereFocusedOn) has $(($TargetedComputerVHDs).count) disks"
    
    # If there is anything other than 3 disks on the machine, but continue evaluating the disks because while there could be a good number of disks we don't know if
    # Those disks are functional. 
    if($TargetedComputerVHDs.count -ne 3){
       $InspectionResults += "$(Get-Date): ACTION ITEM - $($ComputerWereFocusedOn) has a non standard number of disks and needs to be remidiated."
        Write-Host "$(Get-Date): ACTION ITEM - $($ComputerWereFocusedOn) has a non standard number of disks and needs to be remidiated. $($TargetedComputerVHDs.count)"
        
        #Either way we are notating that something needs to be worked on so we 
        # Aren't worried about checking the individual disks.
    }

    #For clarity and debugging we're going to report the disk count to the results log.
    #$InspectionResults += "$(Get-Date): $($ComputerWereFocusedOn) has $($TargetedComputerVHDs.count) Disks."
    Write-Host "$(Get-Date): $($ComputerWereFocusedOn) has $($TargetedComputerVHDs.count) Disks."

    # Provide Check 2: Disks with a date from the 1980s
    $TargetedComputerVHDs | ForEach-Object -Process {

        $DiskBeingInspected = $_

        # LastAccessTime, LastWriteTime, CreationTime
        $DiskBeingInspected.LastAccessTime, $DiskBeingInspected.LastWriteTime, $DiskBeingInspected.CreationTime | ForEach-Object -Process {
            #Debug
            #Write-Host "$($DiskBeingInspected) on $($ComputerWereFocusedOn) has a date of $_"

            if (($_).year -eq 1980) {

                # One of access/write/created reported a date from 80s's note this 
                $InspectionResults += "ACTION ITEM - Found Disk $($DiskBeinginspected) on computer $($ComputerWereFocusedOn) reporting a file date 1980. Please fix this machine."
            }
        }
    }
}

$NotificationEmailBody = ""
$InspectionResults | ForEach-Object -Process {
    $NotificationEmailBody += "$($_) `n"
}

'<EMAIL_ADDRESS>' | ForEach-Object -Process {
    Send-MailMessage -SmtpServer smtp.lda.local -From 'Commander Data <<EMAIL_ADDRESS>>' -To $_ -Subject "VHD Status Report for: $(Get-Date)" -Body $NotificationEmailBody
}



