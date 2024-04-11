#Requires -RunAsAdministrator

$LogName =
$LogSource = 

# Check for and create event log on local machine.
Get-EventLog -LogName $LogName -ErrorVariable LogCheckResult
Switch ($LogCheckResult.Message) {
    "The event log ' Events' on computer '.' does not exist."{
        New-EventLog -LogName $LogName -Source $LogSource
    }
}

#Mark start of the script and start check for devices. 
Write-EventLog -LogName $LogName -Source $LogSource -EntryType Information -EventId 0 -Message " Started PC Health Check on device $(hostname), $(Get-Date)"

# Logitech webcams have an audio enpoint artifact when they're added to the system. Let's identify them this way. 
$Cams = Get-PnpDevice | Where-Object -Property FriendlyName -like -value Cannon* | Where-Object -Property Class -like -Value WPD

#
# Results, What should we do when there's a problems. 
#

#ERROR: There's nothing...
if(!$Cams){
    Write-EventLog -LogName $LogName -Source $LogSource -EventId 67 -Message "I didn't get any feedback from the system regard webcam artifacts. You probably need to connect and configure cameras for $(hostname)"
    Exit
}

#ERROR: There's not enough...
if($Cams.GetType().Name -eq 'CimInstance'){
    Write-EventLog -LogName $LogName -Source $LogSource -EventId 66 -Message "HEADS UP! Which scanning the PCs for Attached Cameras, I only recieved one artifact for attached cameras. You are either missing cameras or there is a connectivity / functional issue. Please investigate"
    Exit
}



