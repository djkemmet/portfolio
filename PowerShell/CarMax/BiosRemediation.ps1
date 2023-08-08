# Start by Checking the Time and the disk mode. If these are both wrong, then we probably need to reconfigure bios.

if ((Get-Date -Format yyyy) -ne 2023) {

    Write-Output "The Date is wrong on the machine, what dis mode is the PC configured for?"


}
