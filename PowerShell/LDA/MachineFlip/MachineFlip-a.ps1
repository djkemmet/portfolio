#Requires -RunAsAdministrator

<#+------------------------------------------------------------------------------------------+

	_MachineFlip.ps1

	Purpose :  This script is responsible for flipping SRVRs to MNGRs and MNGRs to SRVRs by checking the VHD directive in our settings.csv
               against the hostname of the machine. If there is a mismatch then the machine VHD will be configured based on the hostname of
               the machine. So for example. If you have booted a manager VHD on a server machine. The manager VHD will be modified for a server
               config and vice versa. 

	Version :  1.0.1.2

	Parameters : None

	PowerShell Version : Tested on PS5 with 

	Support Files : None

	Author : DJ Kemmet, <EMAIL_ADDRESS>


	Notes :  
            * Requires -runasadministrator
            * This script is one shot. It will make all the requested changes in one go and then upon reboot D: or E: will become
             X:. 
            * Interestingly, If you run this script in powershell ISE or VS Code in a target VM, It doesn't behave correctly. But if 
              you run it in powershell it works as expected. so...always run this in powershell proper.
            * For best results debugging. Make Sure you're running VSCode as admin, Make sure you're using a 
              64 BIT shell, and make sure the file is saved to the disk inside your VM. Copy it out as you progress.
            * If you are debbugging this script, You're going to need to run VS Code as Local Admin
	Release Dates/Notes:
                       12/22/21 - Initial coding date.

+------------------------------------------------------------------------------------------+
#>

#region Assemblies and imports

Import-Module -Name LDAModule

#endregion

#region Constants and variable setup

$Global:ScriptName = 'MachineFlip'
$ScriptVersion = '1.0.1.2'

#Start Program!
mLog -Message "$($ScriptName) version $($ScriptVersion) started on $(hostname)"
#<INSERT MAIN CODE BLOCK HERE>

# Find the Settings.xml file and make it parseable.
mLog -Message "Finding 'main' Volume..."

#Region - ALWAYS RUN - Basic checks and importing the settings.csv file into the session. 
$DriveLetter = (Get-Volume | Where-Object -Property FileSystemLabel -eq "Main" | Select-Object DriveLetter).DriveLetter
if ($DriveLetter -eq $null){
    mLog -Message "***ERROR - A main drive containing boot vhds was not found on this system. Are you running this on the right machine?"
    #UNCOMMENT THIS OUT: exit 1  ### It should be extrorinaly rare this ever happens but we are exiting here and could still have other work to do
}

mLog -Message "Importing Settings.xml into session...."
$SettingsXML = $($DriveLetter) + ":\lda\system\settings\settings.xml"
try {
    [xml]$Global:Settings = Get-Content $SettingsXML -ErrorAction Stop -ErrorVariable XMLToSession
} catch {
    $ErrorDetail = $XMLToSession[0].ErrorRecord.Exception.Message
    Switch($XMLToSession[0].HResult){
        -2146233087 { Write-Host "The Settings.xml file could not be found. Please Make sure there is a settings.xml $($SettingsXML)";}
        default{ Write-Host "A novel error has occurred, The error was: $($ErrorDetail)"}
    }
}

$StoreNumber = $Env:ComputerName.substring(2,5)
#endregion

#Region - ALWAYS RUN - Check for X:, configure as appropriate, handle errors.
Try {
    # Try to get the X Drive Assignment 
    if(Get-ItemProperty -Path "HKLM:\SYSTEM\MountedDevices" -Name "\DosDevices\X:" -ErrorAction Stop -ErrorVariable XCheckResult){
        MLog -Message "Found An exisitng x:\Drive Making sure it's what we expect by searching for the VDISKS/ Drirectory"
        if((Test-Path -Path "X:\VDISKS") -eq $true){
            MLog -Message "Found the Vdisks Directory, Continuing to configure the machine... "
        } else {
            MLog -Message "There was an x Drive, but it was not configured the way we expected. so we're going to reconfigure it now."
            $MainDriveVolumeLetter = (Get-Volume -FileSystemLabel Main | Select DriveLetter).DriveLetter
            MLog -Message "The Main Drive was Labeled as: $($MainDriveVolumeLetter), Updating this in the registry to become the X Drive..."
            MLog -Message "Removing the X Drive Registry key..."
            Remove-ItemProperty -Path "HKLM:\System\MountedDevices" -Name "\DosDevices\X:"
            MLOG -Message "Setting the Main Drive (Volume $($MainDriveVolumeLetter) to be the X Drive."
            Rename-ItemProperty -Path "HKLM:\System\MountedDevices" -Name "\DosDevices\$($MainDriveVolumeLetter):" -NewName "\DosDevices\X:" -ErrorAction Stop -ErrorVariable AssignXtoDResult 
            MLog -Message "The Main drive has successfully had it's drive letter reassigned. Rebooting..."
            Restart-Computer -Force
        }
    }  else {
        Mlog -Message "The Registry Key \DosDevices\X: does not exist on this system. Looking for the 'Main' Drive"
        $MainDriveVolumeLetter = (Get-Volume -FileSystemLabel Main | Select DriveLetter).DriveLetter
        MLog -Message "The Main Drive was Labeled as: $($MainDriveVolumeLetter), Updating this in the registry to become the X Drive..."
        Rename-ItemProperty -Path "HKLM:\System\MountedDevices" -Name "\DosDevices\$($MainDriveVolumeLetter):" -NewName "\DosDevices\X:" -ErrorAction Stop -ErrorVariable AssignXtoDResult 
        MLog -Message "The Maindrive has successfully had it's drive letter reassigned. Rebooting..."
        Restart-Computer -Force
    }

    # WELP You found an X Drive, Is there a D Drive? yea? Well then you know you need to reconfigure the machine. 
    # If there IS NOT a D: drive it's reasonable to assume that the drive has already been configured and the X that we're seeing
    # is the X Drive of the properly configured disk. 

    

# Otherwise, Get-ItemPropety for X failed, Handle it.    
} Catch {
    continue
}

#endregion 

### Valid point good sir. How's this?
### ------------------------------------------------------------
mLog -Message "Verifying the X Drive is properly Configured"

#Region - ALWAYS RUN - Check for and set the current Bootloader.  

# Check If "Current" bootloader entry matches "Default"
MLog -Message "Verifying the bootloader config. Is currently booted OS The Default?"
$current = (bcdedit /enum "{current}" | Select-String "identifier")[0].ToString().Replace("identifier", "").replace(" ", "")  ###double check this value / I don't think the way you have it will EVER say antyhing but "Current"
$default = (bcdedit /enum "{default}" | Select-String "identifier")[0].ToString().Replace("identifier", "").replace(" ", "")

# If it doesn't, this is a converstion do the following:
if(!($current -eq $default)){

    mLog -Message "Setting $current to default bootloader entry to make sure this VHD always boots... "
    bcdedit /default $current
} else {
    mLog -Message "The Bootloader was configured correctly and is booting from: $current"
}
#endregion

#Region - CONDITIONALLY RUN - Computer Specific Configurations
    # SRVR = Update Settings.xml, Create a Temporary User, One Other thing
    # MNGR = Update Settings.xml, Delete OST file from Cage Profile.
$Machine =  $Env:ComputerName.substring(7,4)

mLog -Message "Machine role = $($Machine) SettingsFile = $($Settings.LocalSettings.VHD) "
if (!(($Settings.LocalSettings.VHD) -eq $Machine)){

    mLog -Message "Conditional Changes are required, Starting..."
    Try {

        #First, Since the machine hasn't been rebooted, identify the current "Main" Drive Letter
        MLog -Message "Finding 'main' Volume..."
        $DriveLetter = (Get-Volume | Where-Object -Property FileSystemLabel -eq "main" | Select-Object DriveLetter).DriveLetter ### Duplicate code - this was already done around line 54
    

        # Make Role-Specific changes.
        Switch($Machine){

            "SRVR"{ 
                # Correct the Settings.xml file
                mLog -Message "Updating settings.xml, VHD = SRVR"
                $Settings.LocalSettings.VHD = "SRVR" 
                New-LocalUser -Name "TemporaryManager" -Password (ConvertTo-SecureString "<PASSWORD>" -AsPlainText -Force)

                $exePath = "Autologon.exe"
                $user = "TemporaryManager"
                $domain = (hostname)
                $password = "<PASSWORD>"

                mLog -Message "Creating Temporary account, $($user) for the store manager to use."
                Start-Process -FilePath $exePath -ArgumentList "/accepteula", $user, $domain, $password -wait
                ###  why do we not need the entry below?  I would think we would...
                # We don't set this because it au
                # Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" -Name ForceAutoLogon -Value 1 
            }
            "MNGR"{ 
                # Correct the Settings.xml file
                mLog -Message "For Manager, updating settings.xml so that VHD = MNGR ..."
                $Settings.LocalSettings.VHD = "MNGR"

                #Debug
                #New-Item -Type Directory -Path C:\Users\cafe1234\AppData\Local\Microsoft\Outlook\ -ErrorAction SilentlyContinue
                #New-Item -Type File -Path C:\Users\cafe1234\AppData\Local\Microsoft\Outlook\SillyGooze.OST - ErrorAction SilentlyContinue
    
                # Remove the OST File
                mLog -Message "Lazy Deleting the OST Files in any cafe* profile."
                #$StoreNumber = hostname
				Get-ChildItem C:\Users\cafe*\AppData\Local\Microsoft\Outlook\*.ost -ErrorVariable $OSTCleanupError | ForEach-Object -Process {
					MLog -Message "Found OST File $($($_).Name) and will delete it."
				}
				
                try {
               		Get-ChildItem C:\Users\cafe*\AppData\Local\Microsoft\Outlook\*.ost | % { Remove-Item $_ }
                } catch {
                    mLog -Message "There were no OST Files to Clean up.: `n`n $OSTCleanupError"
                }
                #A Temporary User is not created on the manager machine because it is already a user-accessible machine by default.
            }
        }
    
        mLog -Message "Saving changes to Settings.xml..."
        $Settings.Save($SettingsXML)
    
        mLog -Message "The Conversion is complete, The computer will now reboot for registry changes to take effect."  ### you have the restart commented out / if you changed the X: then a reboot is required
        Restart-Computer -Force

    }catch {
        Write-Host "Something went wrong while trying to make the Role-Specific changes to this computer: `n`n`n $($Error[0].Message)"
    }
} else {  

    MLog -Message "The Computer Name and the VHD Directive Matched so there are no conditional changes to be made."
    # The Computer name and the VHD type match. So we need to check and see if this is just the computer coming back online after EOD has run
    # OR if the manager PC is present and It's time to remove the Account from our server machine. 
    $ComputerHostname = $Env:ComputerName.substring(7,4)
    $VHDConfigDirective = $Settings.LocalSettings.VHD

    #If the host name and the VHD config match...
    If($ComputerHostName = $VHDConfigDirective){

        MLog -Message "Polling for manager machine cannot be tested on non-production setups. Disregard any errors"

        # First, We Need to get the host IP Address so we know what network we're on, Stripping out the 4th octet. - This is going to have to be tested. 
        # TODO: The Interface alias needs to be a switch to handle different nic names, like ETHERNET, NIC-TEAM ETC
        
        #Wrap this is a try/catch
        $NetworkIP = (Get-NetIPAddress | Where-Object -Property AddressFamily -eq -Value IPv4 | Select-Object InterfaceAlias, IPAddress | Where-Object -FilterScript {$_.IPAddress -like "10.128*"} | Select IPAddress).ipAddress.split(".")[0..2] | ForEach-Object -Process {$CompiledIP += $_ + "."}
        $ManagerBoxIP = $CompiledIP + "26"
        
        if ((Test-NetConnection $ManagerBoxIP).PingSucceeded -eq $True){
            Write-Host "Manager PC Was found on the network. Removing Auto-logon from server machine."
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" -Name DefaultUserName
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinLogon" -Name DefaultPassword
            Write-Host "Auto-logon has been deactivated."
            
        } else {
            mLog -Message "The Manager PC was not found on this network. No action Required."
        } 
    }
    MLog -Message "Script is done, exiting..."
    exit
}
#endregion



