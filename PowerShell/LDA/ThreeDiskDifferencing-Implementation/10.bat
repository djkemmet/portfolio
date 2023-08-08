@Echo Off
@REM ******************************************************
@REM
@REM 	10.bat
@REM
@REM 	Purpose:  - Commit all differencing (child) disk(s)
@REM              - Remove differencing disk
@REM              - Point BCD to "default" child
@REM 
@REM 	Author:  <SOMEONE_THAT_ISNT_ME>, DJ Kemmet
@REM
@REM 	Support Files: 
@REM
@REM 	Notes:
@REM
@REM 	Revision History: 
@REM      05/13/2021 - Initial coding date
@REM      12/16/2021 - Refactored to account for a 3 disk differencing chain.
@REM
@REM ******************************************************
setlocal EnableDelayedExpansion

Call :Log %~n0 - Started
@REM Main script block starts below

@REM Determine the default machine type (look at the default)
echo "Determining Defualt Machine Type..."
Call :Log Run BCDEDIT /ENUM {default} to locate default vdisk
bcdedit /v /enum {default} | find /i "MNGR"
If %errorlevel% == 1 (
    Set system=SRVR
) else (
    Set system=MNGR
)
Call :Log System default = %system%

echo "Setting disks..."

call :SetDrives

rem
rem
rem So in this section we're going through ALL the disks and consolidating them, the reason for this is that while the system booted may be of one type or another, the disks cross-replicate
rem and as such they need to be consolidated. Since this section deletes the child disk that's being consolidated
rem
rem 

@REM Merge SRVR/MNGR DEFAULT -- BACKUP - Level 2
rem This should work because %%M would be "MNGR" and "SRVR" so this step takes care of the first two merges: Server and Manager Default to Backup merge.

Echo "Consolidating Server and Manager Default Disks into their respective Backup disks... `n"
For %%m in (MNGR,SRVR) Do (
    If Exist m:\VDisks\%%m\%%m-Default.vhdx (
        Call :Log m:\VDisks\%%m\%%m-default.vhdx file found
        echo Select VDisk File=m:\VDisks\%%m\%%m-Default.vhdx >diskpart.script
        echo Merge VDisk Depth=1 >>diskpart.script
        call :Log Run DiskPart /s diskpart.script to merge the differencing disk
        DiskPart /s diskpart.script
        Call :Log DiskPart return code = %errorleve%
        @REM Delete the child (it will be created below if needed)
        del m:\VDisks\%%m\%%m-Default.vhdx
    )
)

@REM Create MNGR-Default and make it's parent MNGR-Backup
echo "Creating new manager default disk as child of manager backup... `n"
Echo Create VDisk File=m:\VDisks\MNGR\MNGR-Default.vhdx Parent=m:\VDisks\MNGR\MNGR-Backup.vhdx >diskpart.script
Call :Log Create new differencing disk - Create VDisk File=m:\VDisks\MNGR\MNGR-Default.vhdx Parent=m:\VDisks\MNGR\MNGR-Backup.vhdx
diskpart /s diskpart.script
Call :Log DiskPart return code = %errorleve%

@REM Create SRVR-Default and make it's parent SRVR-Backup.
echo "Creating new  server default disk as child of server backup... `n"
Echo Create VDisk File=m:\VDisks\SRVR\SRVR-Default.vhdx Parent=m:\VDisks\SRVR\SRVR-Backup.vhdx >diskpart.script
Call :Log Create new differencing disk - Create VDisk File=m:\VDisks\SRVR\SRVR-Default.vhdx Parent=m:\VDisks\SRVR\SRVR-Backup.vhdx
diskpart /s diskpart.script
Call :Log DiskPart return code = %errorleve%

@REM If There is a flag file...
if Exist D:\MENU\consolidatebackups.txt (
    Echo "Consolidating Server and Manager Backup Disks into their respective Core disks... `n"
    @REM Merge SRVR/MNGR BACKUP -- CORE - Level 1
    rem This should work because %%M would be "MNGR" and "SRVR" so this step takes care of the SECOND two merges: Server and Manager Backup to Core merge.
    For %%m in (MNGR,SRVR) Do (
        If Exist m:\VDisks\%%m\%%m-Backup.vhdx (
            Call :Log m:\VDisks\%%m\%%m-Backup.vhdx file found
            echo Select VDisk File=m:\VDisks\%%m\%%m-Backup.vhdx >diskpart.script
            echo Merge VDisk Depth=1 >>diskpart.script 
            call :Log Run DiskPart /s diskpart.script to merge the differencing disk
            DiskPart /s diskpart.script
            Call :Log DiskPart return code = %errorleve%
            @REM Delete the child (it will be created bselow if needed)
            del m:\VDisks\%%m\%%m-Backup.vhdx
        )
    )

    @REM At this point, both the MNGR and SRVR Default and backup disks have been deleted, lines 46 and 61, this means that 4 new disks need to be created. MNGR-Default, MNGR-Backup, SRVR-Default, SRVR-Backup

    @REM Create MNGR-Backup and make it's parent MNGR-Core
    Echo "Creating new manager backup disk as child to manager core... `n"
    Echo Create VDisk File=m:\VDisks\MNGR\MNGR-Backup.vhdx Parent=m:\VDisks\MNGR\MNGR-Core.vhdx >diskpart.script
    Call :Log Create new differencing disk - Create VDisk File=m:\VDisks\MNGR\MNGR-Backup.vhdx Parent=m:\VDisks\MNGR\MNGR-Core.vhdx
    diskpart /s diskpart.script
    Call :Log DiskPart return code = %errorleve%


    @REM Create SRVR-Backup and make it's parent SRVR-Core
    echo "Creating new server backup disk as child of server core... `n"
    Echo Create VDisk File=m:\VDisks\SRVR\SRVR-Backup.vhdx Parent=m:\VDisks\SRVR\SRVR-Core.vhdx >diskpart.script
    Call :Log Create new differencing disk - Create VDisk File=m:\VDisks\SRVR\SRVR-Backup.vhdx Parent=m:\VDisks\SRVR\SRVR-Core.vhdx
    diskpart /s diskpart.script
    Call :Log DiskPart return code = %errorleve%
    )


    @REM Let's find the correct "Child" boot ID and boot back to that!  (After all we have a fresh new file right!)
    echo "Scanning boot loader config to determine new default boot entries... `n"
    for /f %%i in ('powershell -command "(((bcdedit /enum /v | Select-String -Pattern '\s*%system%' -context 1,0).Context | where PreContext -like "*identif*").DisplayPreContext -split '\s+|\t+')[1]"') Do (
        Call :Log Set BCD Boot default to %%i
        bcdedit /set {bootmgr} default %%i
        Call :Log BCDResult = %errorlevel%
    )
) ELSE (
    Echo "There was no consolidate backups flag file found so SRVR/MNGR Backups will not be consolidated to core. "
)

Call :Log Process complete - rebooting
@rem wpeutil reboot

Call :Log %~n0 - Ended

GoTo :EOF

:LOG
Echo %date% %time:~0,8% - %*
If Exist m:\lda\LOGS (
	Echo %date% %time:~0,8% - %* >>m:\LDA\Logs\%~n0.log
)
GoTo :EOF


rem this function is responsible for making drive mapping consistent when 
rem executing EOD disk consolidation
:SetDrives

if Exist X:\Menu\setdrives.txt (
    del X:\Menu\setdrives.txt
)
echo "Setting up local drives..."
echo select disk 0 >> X:\MENU\setdrives.txt
echo select volume 1 >> X:\MENU\setdrives.txt
echo assign letter=s >> X:\MENU\setdrives.txt
echo select volume 2 >> X:\MENU\setdrives.txt
echo assign letter=d >> X:\MENU\setdrives.txt
diskpart /s x:\MENU\setdrives.txt
diskpart list volume
GoTo :EOF rem this basically means end the subroutine (Function) in CMD
