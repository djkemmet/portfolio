@Echo Off
@REM ******************************************************
@REM
@REM 	MOD_BCD.BAT
@REM
@REM 	Purpose:  Modify the current BCD when it can't be
@REM              exported and re-created.
@REM
@REM 
@REM 	Author:  Mark "Monty" Montgomery
@REM
@REM 	Support Files: 
@REM
@REM 	Notes:
@REM
@REM 	Revision History: 
@REM      12/02/2020 - Initial coding date
@REM
@REM ******************************************************

@REM Variables 
set LogFile=d:\windows\logs\LDA\%~n0.log

setlocal enabledelayedexpansion

Call :LOG BUILD_BCD.BAT - Started

REM *****************************
REM **   FIND VHDX DRIVE       **
REM *****************************
for %%1 in (c,d,e,f,g,h,i,j,k,l,m) do (
	If Exist %%1:\VDISKS\ (
		set DriveLetter=%%1
		Call :LOG vdisk directory was found on drive %%1:
	)
)

echo "Handling Null Drive Letter..."
rem If the variable DriveLetter has no value, call the logging function to write the log and end the script.
If "%DriveLetter%" == "" (
	Call :LOG ***ERROR - Unable to locate a SRVR-Core.VHDX on any drive letter
	Call :LOG Exiting
)
	rem GoTo EOF

echo "Handling MISSING BCDGUIDS Dir"
rem check for directory, if it does not exist, make it.
If NOT Exist %DriveLetter%:\LDA\SYSTEM\SETTINGS\BCDGUIDS (
	md %DriveLetter%:\LDA\SYSTEM\SETTINGS\BCDGUIDS
)

rem Check for the BCD File, which contains our boot info, and if it exists, use it for the value of variable BCDFILE, otherwise use the BCD frile from the 
rem windows PE media, which I believe is a template at this point. Once this is done, write to the log with :log function so we know which file we ended up using.
rem DOES THIS MEAN THAT THIS SCRIPT ONLY EXECUTES IN THE CONTEXT OF A PREBOOT ENVIRONMENT? - No, You need to mount the 100MB EFI partition as S: with diskpart and then this
rem                                                                                          works as you would expect but don't be a dumb dumb and try to use the wrong BCD File.
rem                                                                                          http://woshub.com/how-to-repair-uefi-bootloader-in-windows-8/
REM *****************************
REM **   LOCATE THE BCD FILE   **
REM *****************************
If Exist C:\EFI\Microsoft\BOOT\BCD (
    echo "Found EFI Boot"
	set BCDFILE=C:\EFI\Microsoft\BOOT\BCD
) Else (
    echo "Found BIOS Boot"
	set BCDFILE=C:\BOOT\BCD
)
Call :LOG BCD File = %BCDFILE%


rem for file CONTENTS (for /f) in the contents of the BCD File - so this is basically telling us where windows is, which is required for us to create a BCD Entry (per the docs?) 
rem WHAT DOES ^| MEAN AND WHAT DOES IT DO? - So the carot is an escape character which I believe indicates to the command interpreter that that the for /f statement is complete, allowing
rem                                          the | to be interpreted as a PIPE, so we're effectively piping the output of the BCDEDIT command to the find command 
REM *****************************
REM **   DETERMINE DEFAULT     **
REM *****************************
for /f "tokens=2" %%1 in ('bcdedit /store %BCDFILE% /enum {default} /v ^| find /i "osdevice"') do (
	set BootDefault=%%1
	Call :LOG Default GUID = %%1
)

rem For file, assign placeholder %%1 to the second value in out line split by a ., this line comes from running bcdedit specifically against the BCD file we saw above (/store) filtering with /enum to find the 
rem specific boot entry we're looking for in this case it's {deafult\} but it could otherwise be something like {bootmgr\} or any other entry we've created in the BCD config file. Once we've found the default config, 
rem we use the 
REM *****************************
REM **  DETERMINE UEFI/BIOS    **
REM *****************************
for /f "tokens=2 delims=." %%1 in ('bcdedit /store %BCDFILE% /enum {default} ^| find /i "path"') Do (
	If %%1 == efi (
		Set WinPath=\windows\system32\winload.efi
	) Else (
		Set WinPath=\windows\system32\winload.exe
	)
)
@REM if nothing set then set a default
If "!WinPath!" == set WinPath=\windows\system32\winload.exe
Call :LOG Setting boot path to !WinPath!

REM *****************************
REM **   Remove All Entries    **
REM *****************************

rem So it's worth noting that when you're doing this in a SCRIPT you use %%<var_name> but when you're debugging this in the actual command promp you you se $<var_name>
rem IS THIS A BUG? - So From what I can tell from the code, When you call /enum with BCDEDIT you need to specify 
rem ASK MONTY ABOUT THIS LATER. "/enum osloader" leaves iut boitliader
for /f "tokens=2" %%1 in ('bcdedit /store %BCDFILE% /enum osloader ^| find /i "identifier"') do (
	bcdedit /store %BCDFILE% /delete %%1
	If ERRORLEVEL 1 (
		Call :LOG **Warning - Unable to remove %%1 from the BCD
	) Else (
		Call :LOG Successfully removed %%1 from the BCD
	)
)


REM *****************************
REM **   MANAGER DEFAULT       **
REM *****************************

rem /application isn't documented, what do SPECIFICALLY - https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/bcdedit
rem But for what it's worth it looks like we're creating a new Boot entry for "Manager - Differencing Disk" and then capturing it's guid by looking for the 3rd
rem token in the command's output and delimiting by spaces, then creating local variable GUID to store that value for use in configuring the additional options for
rem that entry. 
rem Set the below properties of our new entry using the BCD file we identified in lines I
for /f "tokens=3 delims= " %%1 in ('bcdedit /store %BCDFILE% /create /application OSLOADER /d "MANAGER  - DEFAULT DISK"') do (
	set GUID=%%1
	Call :LOG SERVER DEFAULT DISK created with GUID %GUID%
)

bcdedit /store %BCDFILE% /set %GUID% device vhd=[%DriveLetter%:]\VDISKS\MNGR\MNGR-Default.vhdx

bcdedit /store %BCDFILE% /set %GUID% path %WinPath%

bcdedit /store %BCDFILE% /set %GUID% description "MANAGER - DEFAULT DISK"

bcdedit /store %BCDFILE% /set %GUID% locale en-US

bcdedit /store %BCDFILE% /set %GUID% inherit {bootloadersettings}

bcdedit /store %BCDFILE% /set %GUID% osdevice vhd=[%DriveLetter%:]\VDISKS\MNGR\MNGR-Default.vhdx

bcdedit /store %BCDFILE% /set %GUID% systemroot \windows

bcdedit /store %BCDFILE% /set %GUID% nx OptIn

bcdedit /store %BCDFILE% /set %GUID% bootmenupolicy Legacy

bcdedit /store %BCDFILE% /set {bootmgr} displayorder %GUID% /addlast
If ERRORLEVEL 1 (
	Call :LOG ***ERROR - MANAGER DEFAULT DISK was NOT successfully added 
) Else (
	Call :LOG MANAGER DEFAULT DISK successfully added 
)

echo %GUID% >%DriveLetter%:\LDA\SYSTEM\SETTINGS\BCDGUIDS\MNGRPC.txt


REM *****************************
REM **   SERVER  DEFAULT       **
REM *****************************

REM This means to create a new osloader entry in BCD then we reference t his GUID in our Set Statements
for /f "tokens=3 delims= " %%1 in ('bcdedit /store %BCDFILE% /create /application OSLOADER /d "SERVER  - DEFAULT DISK"') do (
	set GUID=%%1
	Call :LOG SERVER DEFAULT DISK created with GUID %GUID%
)

bcdedit /store %BCDFILE% /set %GUID% device vhd=[%DriveLetter%:]\VDISKS\SRVR\SRVR-Default.vhdx

bcdedit /store %BCDFILE% /set %GUID% path %WinPath%

bcdedit /store %BCDFILE% /set %GUID% description "SERVER  - DEFAULT DISK"

bcdedit /store %BCDFILE% /set %GUID% locale en-US

bcdedit /store %BCDFILE% /set %GUID% inherit {bootloadersettings}

bcdedit /store %BCDFILE% /set %GUID% osdevice vhd=[%DriveLetter%:]\VDISKS\SRVR\SRVR-Default.vhdx

bcdedit /store %BCDFILE% /set %GUID% systemroot \windows

bcdedit /store %BCDFILE% /set %GUID% nx OptIn

bcdedit /store %BCDFILE% /set %GUID% bootmenupolicy Legacy

bcdedit /store %BCDFILE% /set {bootmgr} displayorder %GUID% /addlast
If ERRORLEVEL 1 (
	Call :LOG ***ERROR - SERVER DEFAULT DISK was NOT successfully added 
) Else (
	Call :LOG SERVER DEFAULT DISK OSLoader successfully added 
)

echo %GUID% >%DriveLetter%:\LDA\SYSTEM\SETTINGS\BCDGUIDS\SRVRPC.txt

REM *****************************
REM **   MANAGER BACKUP        **
REM *****************************

rem /application isn't documented, what do SPECIFICALLY - https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/bcdedit
rem But for what it's worth it looks like we're creating a new Boot entry for "Manager - Differencing Disk" and then capturing it's guid by looking for the 3rd
rem token in the command's output and delimiting by spaces, then creating local variable GUID to store that value for use in configuring the additional options for
rem that entry. 
rem Set the below properties of our new entry using the BCD file we identified in lines I

for /f "tokens=3 delims= " %%1 in ('bcdedit /store %BCDFILE% /create /application OSLOADER /d "MANAGER  - BACKUP DISK"') do (
	set GUID=%%1
	Call :LOG MANAGER BACKUP DISK created with GUID %GUID%
)

bcdedit /store %BCDFILE% /set %GUID% device vhd=[%DriveLetter%:]\VDISKS\MNGR\MNGR-Backup.vhdx

bcdedit /store %BCDFILE% /set %GUID% path %WinPath%

bcdedit /store %BCDFILE% /set %GUID% description "MANAGER - BACKUP DISK"

bcdedit /store %BCDFILE% /set %GUID% locale en-US

bcdedit /store %BCDFILE% /set %GUID% inherit {bootloadersettings}

bcdedit /store %BCDFILE% /set %GUID% osdevice vhd=[%DriveLetter%:]\VDISKS\MNGR\MNGR-Backup.vhdx

bcdedit /store %BCDFILE% /set %GUID% systemroot \windows

bcdedit /store %BCDFILE% /set %GUID% nx OptIn

bcdedit /store %BCDFILE% /set %GUID% bootmenupolicy Legacy

bcdedit /store %BCDFILE% /set {bootmgr} displayorder %GUID% /addlast
If ERRORLEVEL 1 (
	Call :LOG ***ERROR - MANAGER BACKUP DISK was NOT successfully added 
) Else (
	Call :LOG MANAGER BACKUP DISK successfully added 
)

echo %GUID% >%DriveLetter%:\LDA\SYSTEM\SETTINGS\BCDGUIDS\MNGRPC.txt


REM *****************************
REM **   SERVER  BACKUP        **
REM *****************************

for /f "tokens=3 delims= " %%1 in ('bcdedit /store %BCDFILE% /create /application OSLOADER /d "SERVER  - BACKUP DISK"') do (
	set GUID=%%1
	Call :LOG SERVER BACKUPDISK created with GUID %GUID%
)

bcdedit /store %BCDFILE% /set %GUID% device vhd=[%DriveLetter%:]\VDISKS\SRVR\SRVR-Backup.vhdx

bcdedit /store %BCDFILE% /set %GUID% path %WinPath%

bcdedit /store %BCDFILE% /set %GUID% description "SERVER  - BACKUP DISK"

bcdedit /store %BCDFILE% /set %GUID% locale en-US

bcdedit /store %BCDFILE% /set %GUID% inherit {bootloadersettings}

bcdedit /store %BCDFILE% /set %GUID% osdevice vhd=[%DriveLetter%:]\VDISKS\SRVR\SRVR-Backup.vhdx

bcdedit /store %BCDFILE% /set %GUID% systemroot \windows

bcdedit /store %BCDFILE% /set %GUID% nx OptIn

bcdedit /store %BCDFILE% /set %GUID% bootmenupolicy Legacy

bcdedit /store %BCDFILE% /set {bootmgr} displayorder %GUID% /addlast
If ERRORLEVEL 1 (
	Call :LOG ***ERROR - SERVER BACKUP DISK was NOT successfully added 
) Else (
	Call :LOG SERVER BACKUP DISK OSLoader successfully added 
)

echo %GUID% >%DriveLetter%:\LDA\SYSTEM\SETTINGS\BCDGUIDS\SRVRPC.txt

REM *****************************
REM **    MANAGER CORE         **
REM *****************************

for /f "tokens=3 delims= " %%1 in ('bcdedit /store %BCDFILE% /create /application OSLOADER /d "MANAGER - CORE DISK"') do (
	set GUID=%%1
	Call :LOG Manager Core Disk OSLoader created with GUID %GUID%
)

bcdedit /store %BCDFILE% /set %GUID% device vhd=[%DriveLetter%:]\VDISKS\MNGR\MNGR-Core.vhdx

bcdedit /store %BCDFILE% /set %GUID% path %WinPath%

bcdedit /store %BCDFILE% /set %GUID% description "MANAGER - RESTORE TO BACKUP"

bcdedit /store %BCDFILE% /set %GUID% locale en-US

bcdedit /store %BCDFILE% /set %GUID% inherit {bootloadersettings}

bcdedit /store %BCDFILE% /set %GUID% osdevice vhd=[%DriveLetter%:]\VDISKS\MNGR\MNGR-Core.vhdx

bcdedit /store %BCDFILE% /set %GUID% systemroot \windows

bcdedit /store %BCDFILE% /set %GUID% nx OptIn

bcdedit /store %BCDFILE% /set %GUID% bootmenupolicy Legacy

bcdedit /store %BCDFILE% /set {bootmgr} displayorder %GUID% /addlast
If ERRORLEVEL 1 (
	Call :LOG ***ERROR - MANAGER CORE DISK was NOT successfully added 
) Else (
	Call :LOG MANAGER CORE DISK successfully added 
)

echo %GUID% >%DriveLetter%:\LDA\SYSTEM\SETTINGS\BCDGUIDS\MNGRPCBackup.txt

REM *****************************
REM **    SERVER  CORE         **
REM *****************************

for /f "tokens=3 delims= " %%1 in ('bcdedit /store %BCDFILE% /create /application OSLOADER /d "SERVER  - CORE DISK"') do (
	set GUID=%%1
	Call :LOG Server Core Disk OSLoader created with GUID %GUID%
)

bcdedit /store %BCDFILE% /set %GUID% device vhd=[%DriveLetter%:]\VDISKS\SRVR\SRVR-Core.vhdx

bcdedit /store %BCDFILE% /set %GUID% path %WinPath%

bcdedit /store %BCDFILE% /set %GUID% description "SERVER  - RESTORE TO BACKUP"

bcdedit /store %BCDFILE% /set %GUID% locale en-US

bcdedit /store %BCDFILE% /set %GUID% inherit {bootloadersettings}

bcdedit /store %BCDFILE% /set %GUID% osdevice vhd=[%DriveLetter%:]\VDISKS\SRVR\SRVR-Core.vhdx

bcdedit /store %BCDFILE% /set %GUID% systemroot \windows

bcdedit /store %BCDFILE% /set %GUID% nx OptIn

bcdedit /store %BCDFILE% /set %GUID% bootmenupolicy Legacy

bcdedit /store %BCDFILE% /set {bootmgr} displayorder %GUID% /addlast
If ERRORLEVEL 1 (
	Call :LOG ***ERROR - SERVER CORE DISK was NOT successfully added 
) Else (
	Call :LOG SERVER CORE DISK successfully added 
)


echo %GUID% >%DriveLetter%:\LDA\SYSTEM\SETTINGS\BCDGUIDS\SRVRPCBackup.txt

REM *****************************
REM **    WIN PE               **
REM *****************************

for /f "tokens=3 delims= " %%1 in ('bcdedit /store %BCDFILE% /create /application OSLOADER /d "WINPE - Diagnostic"') do set GUID=%%1

for /f "tokens=3 delims= " %%1 in ('bcdedit /store %BCDFILE% /create /device /d "WINPE - Diagnostic"') do set GUID2=%%1

bcdedit /store %BCDFILE% /set %GUID% device ramdisk=[%DriveLetter%:]\VDISKS\PE\boot.wim,%GUID2%

bcdedit /store %BCDFILE% /set %GUID% osdevice ramdisk=[%DriveLetter%:]\VDISKS\PE\boot.wim,%GUID2%

bcdedit /store %BCDFILE% /set %GUID% path %WinPath%

bcdedit /store %BCDFILE% /set %GUID% locale en-US

bcdedit /store %BCDFILE% /set %GUID% inherit {bootloadersettings}

bcdedit /store %BCDFILE% /set %GUID% systemroot \windows

bcdedit /store %BCDFILE% /set %GUID% detecthal Yes

bcdedit /store %BCDFILE% /set %GUID% winpe Yes

bcdedit /store %BCDFILE% /set %GUID% nx optin

bcdedit /store %BCDFILE% /set %GUID% ems No

bcdedit /store %BCDFILE% /set %GUID2% ramdisksdidevice partition=%DriveLetter%:

bcdedit /store %BCDFILE% /set %GUID2% ramdisksdipath \VDISKS\PE\boot.sdi

bcdedit /store %BCDFILE% /set %GUID% bootmenupolicy Legacy

bcdedit /store %BCDFILE% /set {bootmgr} displayorder %GUID% /addlast
If ERRORLEVEL 1 (
	Call :LOG ***ERROR - Windows PE OSLoader was NOT successfully added 
) Else (
	Call :LOG Windows PE OSLoader successfully added 
)

echo %GUID% >%DriveLetter%:\LDA\SYSTEM\SETTINGS\BCDGUIDS\PEBoot.txt

REM *****************************
REM **      Set Default        **
REM *****************************
If %computername:~7,4% == MNGR (
	Set DefaultBoot=MNGR
	GoTo SetDefault
)
If %computername:~7,4% == SRVR (
	Set DefaultBoot=SRVR
	GoTo SetDefault
)

For /f "tokens=3 delims=<>" %%1 in ('type %DriveLetter%:\lda\system\settings\settings.xml ^| find /i "<VHD>"') do (
	Set DefaultBoot=%%1
)

Call :LOG Default boot found as %DefaultBoot%

:SetDefault
For /f %%i in ('type %DriveLetter%:\lda\system\settings\bcdguids\MNGRPC.txt') do (
	bcdedit /store %BCDFILE% /set {bootmgr} default %%i
	If ERRORLEVEL 1 (
		Call :LOG **Warning - Unable to set default boot option
	) Else (
		Call :LOG Successfully Configure the default boot option
	)
)
GoTo :EOF

:LOG
Echo %date% %time:~0,8% - %*
If Exist c:\windows\logs\lda (
	Echo %date% %time:~0,8% - %* >>%LogFile%
)
GoTo :EOF