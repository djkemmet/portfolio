<#+------------------------------------------------------------------------------------------+

	_PowerShellTemplate.ps1

	Purpose :  This script is responsible for consolidating VHDs running on store servers, then
               re-implementing them as a set of 3 disks to help with backups and failures. so
               1. Consolidate VHDs existing on the hard drive
               2. Create new VHD Differencing family (core, backup, default)
               3. Set the bootloader by copying and modifying existing entries to make the VHDs
                  bootable again. 
               This solutions re-purposes existing code. 
               


	Version :  0.1.0.0

	Parameters : None

	PowerShell Version : 5.1

	Support Files : None

	Author : Daniel "DJ" Kemmet, <EMAIL_ADDRESS>


	Notes :  


	Release Dates/Notes:
                       12/2/021  - Initial coding date.

+------------------------------------------------------------------------------------------+
#>

#region Assemblies and imports

#Import-Module -Name LDAModule

#endregion

#region Constants and variable setup

$Global:ScriptName = '_TEMPLATE'
$ScriptVersion = '0.1.0.0'


# Functions

# Start Program!
# mLog -Message ($ScriptName) + ' version ' + $ScriptVersion + ' started')

# Global variables needed for this script.
#BUG: Identify the DISKS Dir, Don't hard code it. : GetVolume | Where DriveType -eq "Fixed"
$Global:SRVRVDISKDIR = "D:\VDISKS\SRVR"
$Global:MNGRVDISKDIR = "D:\VDISKS\MNGR"
$Global:DISKPARTSCRIPT = "D:\"

$Global:SRVRCHILDDISK = $null
$Global:SRVRCOREDISK  = $null

$Global:MNGRCHILDDISK  = $null
$Global:MNGRCOREDISK  = $null
function Merge-VHDs {
    
<#
.SYNOPSIS
    Returns True/False, This function is responsible for taking a child VHD and
    merging/consolidating it with it's parent. It assumes that parent in child are 
    in the same directory. 

.PARAMETER ParentVHD
    Optional, This parameter takes a string that represents the absolute path to the
    parent of the VHD We're merging/consolidating. For Future use.

.PARAMETER ChildVHD
    Required, this parameter takes a string that represents the absolute path to
    the child VHD that is 

.EXAMPLE 
    Merge-VHDs -ChildVHD D:\VDISKS\SRVRN3000-C1.vhdx
#>


    #TODO: Make the diskpart script path relative.
    #TODO: Make this function error-aware.
        param (
            [object]$ParentVHD,
            [object]$ChildVHD
        )
    
        # Check for and remove any existing diskpart script. It needs to be regenerated every time 
        # with the correct disk names. 
        if (Test-Path d:\diskpart.script){
            Write-Host "Found the diskpart script on merge invocation. Removing it"
            Remove-Item -Path d:\diskpart.script
        } else {
            Write-host "The Diskpart script wasn't found on merge request. THIS IS GOOD!"
        }


        Write-Host "MERGING $($ChildVHD.FullName) INTO $($ParentVHD.FullName)... "
    
        # Generate the diskpart script we're going to run
        Write-Host "Creating new diskpart script" 
        New-Item -Type "file" -Path "D:\" -Name "diskpart.script"
    
        # Populate the diskpart script:
    
        # Mount the vdisk for consolidation
        $DiskSelectCommand = "select vdisk file=$($ChildVHD)"
        Add-Content -Path d:\diskpart.script -Value $DiskSelectCommand
    
        # Issue the command for th actual disk merge
        $MergeDiskCommand = "merge vdisk depth=1"
        Add-Content -Path d:\diskpart.script -Value $MergeDiskCommand 
    
        # DEBUG: See what the diskaprt script looks like
        Write-Host "Running the following diskpart script: "
        Get-Content -Path d:\diskpart.script
    
        # Now run the actual merge
        Start-Process "cmd.exe" -ArgumentList "/C diskpart.exe /s d:\diskpart.script" -wait
    
        Write-Host "The disks have been successfully merged."
    
        Remove-Item -Path d:\diskpart.script -Force
        Return $true
}

function Create-DifferencingLink {
<#
.DESCRIPTION
    This function is responsible for making a VHD that is a child of the -ParentVHD Provided
    to the command. For now, You need to specify full paths, in the future, the disk will be made where
    The parent is. 

.EXAMPLE
    You might use this function to create a multi disk Differencing chain, in the commands below we create the Disk chain
    for a standard server deployment
    Create-DifferencingLink -TargetVHD "D:\VDISKS\SRVR\SRVRN3000-Core.vhdx"  -ChildVHD "D:\VDISKS\SRVR\SRVRN3000-Backup.vhdx" 
    Create-DifferencingLink -TargetVHD "D:\VDISKS\SRVR\SRVRN3000-Backup.vhdx"  -ChildVHD "D:\VDISKS\SRVR\SRVRN3000-Default.vhdx" 

.EXAMPLE
    You might use this function to create a multi disk Differencing chain, in the commands below we create the Disk chain
    for a standard manager deployment
    Create-DifferencingLink -TargetVHD "D:\VDISKS\MNGR\MNGRN3000-Core.vhdx"   -ChildVHD "D:\VDISKS\MNGR\MNGRN3000-Backup.vhdx"
    Create-DifferencingLink -TargetVHD "D:\VDISKS\MNGR\MNGRN3000-Backup.vhdx"  -ChildVHD "D:\VDISKS\MNGR\MNGRN300-Default.vhdx"

#>
    
    param (
        [String]$TargetVHD,
        [String]$ChildVHD
    )

    
    # If there's already a differinglink.script for diskpart in the directory this command is running from
    # Delete it so it can be generated fresh for this request. 
    if (Test-Path -Path D:\DifferencingLink.script) {
        Remove-Item -Path D:\DifferencingLink.script
    }

    #Create a diskpart script to select and merge the 
    New-Item -ItemType File -Name DifferencingLink.script -Path D:\

    # Now that we have  a diskpart script, Craft the command for our diskpart script and put it in our temp script.
    Write-Host "Now Creating a child of $TargetVHD, with disk name $ChildVHD"
    $SelectVdiskCommand = "create vdisk FILE=$($ChildVHD) TYPE=expandable PARENT=$($TargetVHD)"
    Add-Content -Path D:\DifferencingLink.script -Value $SelectVdiskCommand 

    # For Debugging, See what it's going to do in the VM.
    #Get-Content -Path D:\DifferencingLink.script

    # Now do the thing.
    Start-Process "cmd.exe" -ArgumentList "/C diskpart.exe /s d:\DifferencingLink.script" -wait

    try{
        Remove-Item -Path d:\DifferencingLink.script
    }catch {
        Write-Host "Didn't delete diskpart script. It probably didn't exist."
    }
    
}

 # End Merge VHD Function

#Script Starts Here!
Write-Host "Beginning the VHD differencing Conversion..."

# Merge the Disks

    ##############################
    # SERVER DISK CONSOLIDATIONS #
    ##############################
    # Look for the "core" and the "backup" TODO: Wrap in Try/Catch for merge VHD
    if (Test-Path -path $Global:SRVRVDISKDIR) {


        ##########################################
        # PHASE ONE - Check for and assign Disks #
        ##########################################

        # Since we've found the SRVR vhd dir, enumerate all the files so we can take action.
        Get-ChildItem -Path $Global:SRVRVDISKDIR | ForEach-Object -Process {

            # Preserve the object so we can assign it to it's appropriate global.
            $VHDImageObject = $_
            Write-Host "Analyzing $VHDImageObject..."

            # If you find a file with "Child" in the name, make it our $SRVRCHILD Image
            if(Select-String -InputObject $_.Name -Pattern "-Child"){
                
                #This wasn't  a global to contain the Image data.
                $Global:SRVRCHILDDISK = $VHDImageObject
                Write-Host "FOUND SRVR CHILD: $($Global:SRVRCHILDDISK.FullName)"
            }
            # Since It Wasn't a child, Be Double sure it's not a child 
            if(!(Select-String -InputObject $_.Name -Pattern "-Child")){

                # Then make sure That it's not a default disk, might as well
                # Write for where we are headed.  
                if(!(Select-String -InputObject $_.Name -Pattern "-Default")){

                    if(!(Select-String -inputObject $_.Name -Pattern "-Backup")){
                        # It's safe to say it's a core Disk. So Assign It's global.
                        $Global:SRVRCOREDISK = $VHDImageObject
                        Write-Host ("FOUND SRVR CORE: $($Global:SRVRCOREDISK.FullName)")
                    }
                }
            }
        }  #END SRVR DISK ENUMERATION
        

        ############################################################
        # PHASE TWO - VERIFY DISKS FOUND, CONSOLIDATE AND CLEAN UP #
        ############################################################

        #Before we do the merge, lets make sure we have both disks identified before we continue. 
        if(!($Global:SRVRCOREDISK = $null)){

            # We have a server core, check for a server child. 
            if(!($Global:SRVRCHILDDISK = $null)){

                # We have a child the disks can be consolidated
                # We made it this far which means the parent and child server disks exist, and we have what we need to merge.
                if (Merge-VHDs -ParentVHD $Global:SRVRCOREDISK -ChildVHD $Global:SRVRCHILDDISK) {
                    Write-host "The Disk consolidation appears to have been successful"

                    # Get rid of the SRVR child VHD now that it's been merged. We're going to create a new, three disk chain.
                    try {
                        Remove-Item $Global:SRVRCHILDDISK.FullName -Force
                    } catch {
                        Write-Host "Tried to delete SRVR Child, but couldn't. It probably doesn't exist."
                    }
                }
            } 
        # We Couldn't find one of the disks we needed. 
        }else {
            Write-Host "A Server Core disk could not be found so a consolidation cannot be performed."
        }
    # Otherwise, we couldn't find the server VDISK directory so something is probably wrong. Alert and end the charade
    } else {
        Write-Host "Could not find a server disk directory. Something is seriously wrong. Exiting."
        exit.
    }
   
    ##############################
    # MANAGER DISK CONSOLIDATION #
    ##############################
    # Look for the "core" and the "backup" TODO: Wrap in Try/Catch for merge VHD
    if (Test-Path -path $Global:MNGRVDISKDIR) {
        
            ##########################################
            # PHASE ONE - Check for and assign Disks #
            ##########################################

            # Since we've found the SRVR vhd dir, enumerate all the files so we can take action.
            Get-ChildItem -Path $Global:MNGRVDISKDIR | ForEach-Object -Process {

                # Preserve the object so we can assign it to it's appropriate global.
                $VHDImageObject = $_

                # If you find a file with "Child" in the name, make it our $SRVRCHILD Image
                if(Select-String -InputObject $_.Name -Pattern "-Child"){
                    
                    #This wasn't  a global to contain the Image data.
                    $Global:MNGRCHILDDISK = $VHDImageObject
                    Write-Host "FOUND MNGR CHILD: $($Global:MNGRCHILDDISK.FullName)"
                    Start-Sleep 5
                }

                # Since It Wasn't a child, Be Double sure it's not a child 
                if(!(Select-String -InputObject $_.Name -Pattern "-Child")){

                    # Then make sure That it's not a default disk, might as well
                    # Write for where we are headed.  
                    if(!(Select-String -InputObject $_.Name -Pattern "-Default")){

                        if(!(Select-String -InputObject $_.Name -Pattern "-Backup")){
                            # It's safe to say it's a core Disk. So Assign It's global.
                            $Global:MNGRCOREDISK  = $VHDImageObject
                            Write-Host ("FOUND MNGR CORE: $($Global:MNGRCOREDISK.FullName)")
                            Start-Sleep 5

                        }
                    }
                }
            }  #ENDS MNGR DISK ENUMERATION


            ############################################################
            # PHASE TWO - VERIFY DISKS FOUND, CONSOLIDATE AND CLEAN UP #
            ############################################################

            #Before we do the merge, lets make sure we have both disks identified before we continue. 
            if(!($Global:MNGRCOREDISK = $null)){

                # We have a server core, check for a server child. 
                if(!($Global:MNGRCHILDDISK = $null)){

                    # We have a child the disks can be consolidated
                    # We made it this far which means the parent and child server disks exist, and we have what we need to merge.
                    if (Merge-VHDs -ParentVHD $Global:MNGRCOREDISK -ChildVHD $Global:MNGRCHILDDISK) {
                        Write-host "The Disk consolidation appears to have been successful"

                        # Get rid of the SRVR child VHD now that it's been merged. We're going to create a new, three disk chain.
                        try {
                            Remove-Item $Global:MNGRCHILDDISK.FullName -Force
                        } catch {
                            Write-Host "Tried to delete SRVR Child, but couldn't. It probably doesn't exist."
                        }
                    }
                } else {
                    Write-Host "A Server Child disk was not verified. Server disk consolidation will not move forward."
                } 
            }else {
                Write-Host "A Server Core disk was not verified. Server disk consolidation will not move forward."
            }

    # Otherwise, we couldn't find the server VDISK directory so something is probably wrong. Alert and end the charade        
    } else {
        Write-Host "Could not find a manager disk directory. Something is seriously wrong. Exiting."
        exit
    }

    ##################################
    # RENAME CORE VHDs APPROPRIATELY #
    ##################################
    # Rename SRVRN3000.vhdx, reset global for the Server core disk.
    Rename-Item -Path $Global:SRVRCOREDISK.FullName -NewName "SRVR-Core.vhdx"
    $Global:SRVRCOREDISK = Get-Item -Path D:\VDISKS\SRVR\SRVR-Core.vhdx

    # Rename MNGRN3000.vhdx, reset globlal for the ManagerDisk
    Rename-Item -Path $Global:MNGRCOREDISK.FullName -NewName "MNGR-Core.vhdx"
    $Global:MNGRCOREDISK = Get-Item -Path D:\VDISKS\MNGR\MNGR-Core.vhdx



    ########################
    # CREATE NEW VHD CHAIN #
    ########################
    # SRVR
    Create-DifferencingLink -TargetVHD "D:\VDISKS\SRVR\SRVR-Core.vhdx"  -ChildVHD "D:\VDISKS\SRVR\SRVR-Backup.vhdx" 
    Create-DifferencingLink -TargetVHD "D:\VDISKS\SRVR\SRVR-Backup.vhdx"  -ChildVHD "D:\VDISKS\SRVR\SRVR-Default.vhdx" 
    # MNGR
    Create-DifferencingLink -TargetVHD "D:\VDISKS\MNGR\MNGR-Core.vhdx"   -ChildVHD "D:\VDISKS\MNGR\MNGR-Backup.vhdx"
    Create-DifferencingLink -TargetVHD "D:\VDISKS\MNGR\MNGR-Backup.vhdx"  -ChildVHD "D:\VDISKS\MNGR\MNGR-Default.vhdx"
    

    ########################
    # CONFIGURE BOOTLOADER #
    ########################
    Start-Process cmd.exe -ArgumentList "/C .\MOD_BCD.BAT" -wait


#mLog -Message ($ScriptName) + ' version ' + $ScriptVersion + ' ended') 



