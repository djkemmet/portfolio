#
# Author: DJ Kemmet, djkemmet@sftp.com
# Date: 10/22/19
# About : Powershell script to apply images to machines via "Flashstick Solution"
# Requirements: WinPE with powershell and requisite scripting modules applied to the image


# Accepts an Image name as an argument and applies that image to the machine
function applyImage($imageName){
    
    # Clear screen
    Clear-Host

    # Notify user which image is about to be applied
    Write-Host "Applying $imageName..."
    
    # Give it a sec...
    Start-Sleep -s 5

    # Tell User which step you're on: Preparing Disk
    Write-Host  ** Preaparing Disk... **

    # Use Diskpart to apply paritions to the disk...
    diskpart -s X:\utils\CreatePartitions-UEFI.bat

    # Tell User which step you're on: Apply Image
    Write-host ** Applying $imageName Image... **

    # Drive letter of the largest Partition on the disk, that is where we will install windows.
    $driveLetter = (Get-Volume -FriendlyName "Windows").DriveLetter + ":\"

    # Get The Drive Letter assigned to our images directory (handles dynamic Drive assignments)
    $ImageVolume = (Get-Volume -FriendlyName "Images").DriveLetter + ":\"

    # Craft an image string to pass to the DISM Command
    $Image = $ImageVolume + $imageName

    # Apply the appropriate image from the Images Drive
    Dism /apply-image /imagefile:$Image /index:1 /ApplyDir:$driveLetter

    # Apply Bootloader
    Write-host Applying Bootloader...
    X:\Windows\System32\bcdboot.exe W\:\Windows

    # Reboot into new OS
    Write-host rebooting into new image...
    Restart-Computer


}

# Draws a menu to the screen so a user can apply an image.
function mainMenu{

    # Start with a fresh window.
    Clear-Host

    # Write the initial menu to the screen. Are we applying a PC or POS Image?
    Write-Host "
    ###############################
    # SFOS IMAGE APPLICATION UTIL #
    ###############################
    1. Apply PC Image
    2. Exit
    "
    # Capture the User's input as variable imageType to be checked by a switch.
    $menuOption = Read-host

    # Use a switch to take action based on the value of $ImageType
    switch ($menuOption){

        # If the user selected option 1 (PC Image)...
        1 {

            # Clear off the previous menu
            Clear-Host

            # Figure out where the images are 
            $ImageVolume = (Get-Volume -FriendlyName "Images").DriveLetter + ":\"
            $SearchString = $ImageVolume + "*.wim"

            # Get a list of available images from the images partition
            $AvailableImages = @(Get-ChildItem $SearchString)

            # Write the new menu to the screen, Scan the image dir and return a list of iamges on the disk??
            write-host "
    ###############################
    # APPLY PC IMAGE #
    ###############################
            "
            # For loop to write image options to the screen
            for ($counter = 0; $counter -le $AvailableImages.Length; $counter++)
            {
                Write-Host $counter. $AvailableImages[$counter].Name
            }
            
            # Capture image preference.
            $ImageSelection = Read-Host "Please Select an image:"
            
            # Get the name of the image the user wants to apply to the machine
            $ImageName = $AvailableImages[$ImageSelection].name 

            # Share the share the name of the image the user wants applied with the applyimage function. 
            ApplyImage($ImageName)

        } # End case 1, PC Image

        #If the use selected Option 2 (POS Image)...
        2{
            # Clear the screen and return to powershell prompt
            Clear-Host
            Exit-PSHostProcess

        } # End case 2, POS Image.


    }

}






mainMenu