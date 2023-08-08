
#requires -runasadministrator
function Initialize-Registry {
    # Mount the registry as a PSDrive
    New-PSDrive -Name "KMXHive" -PSProvider Registry -Root "HKLM:\Software\CarMax"
    
    # Check and initialize: Registry Hive.
    if ((Test-Path -Path KMXHive:\CustomInventoryAgent) -ne $True){
        #TODO: Implement logging, notifiy the event log.
        New-Item -Path "KMXHive:\CustomInventoryAgent" 

    }
    # Check the Hive fo
}

function Decode {
    If ($args[0] -is [System.Array]) {
        [System.Text.Encoding]::ASCII.GetString($args[0])
    }
    Else {
        "Not Found"
    }
}

Initialize-Registry

#
# Okay First, Let's identify the SNow CI Properties.
#

# Start here, this will probably be easiest for EUC-S to maintain. 
$ThisComputer = Get-ComputerInfo
# CI Name: HOSTNAME
$ComputerHostName = $ThisComputer.Name
# CI Serial Number: SERVICE TAG
# CI Manufacturer
$ComputerManufacturer = $ThisComputer.CsManufacturer
# Computer Model
$ComputerModel = $ThisComputer.CsModel
# CI Operating System
$ComputerOperatingSystem = $ThisComputer.WindowsProductName 
# CI OS Version: BUILD NUMBER
$ComputerBuildLevel = $ThisComputer.WindowsVersion 
# CI Diskspace
$ComputerDiskSize = (Get-Volume -DriveLetter C).Size / 1GB
# CI CPU MANUFACTURER
$ComputerProcessorName = ($ThisCoputer.CsProcessors[0]).Manufacturer
# CI CPU Type: "Xeon, i7, Ryzen 9"
$ComputerCPUType = ($ThisComputer.CsProcessors[0]).Name.split(" ")[1]
# CI CPU Core Count
$ComputerCPUCores = ($ThisComputer.CsProcessors[0]).NumberOfCores
# CI RAM (GB)
$ComputerInstalledMemory = Get-WmiObject Win32_PhysicalMemory | Select *
$ComputerRAM = 0
ForEach ($InstalledDIMM in $COmputerInstalledMemory){
    $DiscoveredCapacity += $InstalledDIMM.Capacity / 1GB
}

#
# Identify Monitors
#
$Monitors = Get-WmiObject WmiMonitorID -Namespace root\wmi
ForEach ($Monitor in $Monitors){
    $Manufacturer = Decode $Monitor.ManufacturerName -notmatch 0 
    $Model = Decode $Monitor.UserFriendlyName -notmatch 0
    $SerialNumber = Decode $Monitor.SerialNumberID -notMatch 0

    Write-Host "$Manufacturer, $Model $SerialNumber"
}