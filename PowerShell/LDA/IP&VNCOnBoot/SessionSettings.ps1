<#+------------------------------------------------------------------------------------------+

	_PowerShellTemplate.ps1

	Purpose :  Template/starting point for building PowerShell Scripts
               


	Version :  1.0.0.0

	Parameters : None

	PowerShell Version : 5.1

	Support Files : None

	Author : DJ Kemmet, <EMAIL>


	Notes :  Runs as a startup script in windows PE, will theoretically replace 10.bat implements a settings.file
	         for the pre-boot environment for configurability. 


	Release Dates/Notes:
                       12/7/21  - Initial coding date.

+------------------------------------------------------------------------------------------+
#>

#region Assemblies and imports

#Import-Module -Name LDAModule

#endregion

#region Constants and variable setup

#$Global:ScriptName = '_TEMPLATE'
$ScriptVersion = '1.0.0.0'


#Functions

#Start Program!
#mLog -Message ($ScriptName) + ' version ' + $ScriptVersion + ' started') 

# Check for ipsettings.csv and exit if not present.
if(!(Test-Path X:\Menu\SessionSettings.csv)){
    Write-Host "Could not find the IP config file for this machine. Exiting."
    Exit
}

# The ipsettings.csv is present open and unpack.
Write-Host "Found bootsettings.csv, importing configuration..."
$Config = Import-CSV X:\Menu\SessionSettings.csv

Write-host "IP To Apply: $($Config.IPAddress)"
Write-Host "Enable VNC Set To : $($Config.VNCEnabled), Configuring accordingly."

#
# IP Config
#

# Disable the Firewall in WindowsPE
Write-Host "Disabling Firewall..."
wpeutil DisableFirewall

#Create the Gateway Address
Write-Host "Generating Gateway Address..."
$Gateway = ""
$IP = ($Config.IPAddress).split(".")[0..2] 
ForEach ($Number in $IP){ $Gateway+=($Number+ ".")}
$Gateway+="1"


#region - Set the IP Address of the Session
$IP = ((ipconfig | Select-String "IPv4").ToString()).split(":")[1].Replace(" ", "")

# If There is no IP address or there is an IP address 
If($IP -ne $Config.IPAddress){

	# Start a detached loop in a new process that will go all slick willy on 
	# setting an IP address for the System It will never stop never stopping trying to set
	# and IP address until
	Start-Job -ScriptBlock {

		While ($IP -ne $Config.IPAddress) {
			netsh interface ipv4 set address Ethernet0 static $($Config.IPAddress) 255.255.255.0 $Gateway
			$IP = ((ipconfig | Select-String "IPv4").ToString()).split(":")[1].Replace(" ", "")
		}
	}
}

#endregion
#Set the IPAddress


#TODO: Write code to enumerate the interfaces and always select whichever ethernet
#      interface is "lowest" on the list
Write-Host "Setting IP Address..."
try {
	netsh interface ipv4 set address Ethernet0 static $($Config.IPAddress) 255.255.255.0 $Gateway
	ipconfig
}catch {
	netsh interface ipv4 set address Ethernet static $($Config.IPAddress) 255.255.255.0 $Gateway
	ipconfig
}


Write-Host Launching VNC...
Start-Process "X:\Program Files\VNC\WinVNC.exe" -ArgumentList "/start"

#mLog -Message ($ScriptName) + ' version ' + $ScriptVersion + ' ended') 
