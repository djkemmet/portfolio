Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#region Helpers and Globals    
$GenerateAndFillProfile = {
    $Global:Computer = Get-ADComputer $ComputerNameTextField.Text 
    $ComputerDNSNameValue.Text = $Computer.DNSHostName
    $ComputerStatusValue.Text = $Computer.Enabled 
}
function Show-MessageBox {  

    # Simplify Property Selection and Utilization with switches.
    [CmdletBinding()]  
    Param (   
        [Parameter(Mandatory = $false)]  
        [string]$Title = 'MessageBox in PowerShell',

        [Parameter(Mandatory = $true)]
        [string]$Message,  

        [Parameter(Mandatory = $false)]
        [ValidateSet('OK', 'OKCancel', 'AbortRetryIgnore', 'YesNoCancel', 'YesNo', 'RetryCancel')]
        [string]$Buttons = 'OKCancel',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Error', 'Warning', 'Information', 'None', 'Question')]
        [string]$Icon = 'Information',

        [Parameter(Mandatory = $false)]
        [ValidateRange(1,3)]
        [int]$DefaultButton = 1
    )            

    # Determine Possible Default Button
    if ($Buttons -eq 'OK') {
        $Default = 'Button1'
    }
    elseif (@('AbortRetryIgnore', 'YesNoCancel') -contains $Buttons) {
        $Default = 'Button{0}' -f [math]::Max([math]::Min($DefaultButton, 3), 1)
    }
    else {
        $Default = 'Button{0}' -f [math]::Max([math]::Min($DefaultButton, 2), 1)
    }

    # Redundant Assembly Import Removed.
    # added from tip by [Ste](https://stackoverflow.com/users/8262102/ste) so the 
    # button gets highlighted when the mouse hovers over it.
    [void][System.Windows.Forms.Application]::EnableVisualStyles()

    # Setting the first parameter 'owner' to $null lets he messagebox become topmost
    [System.Windows.Forms.MessageBox]::Show($null, $Message, $Title,   
                                            [Windows.Forms.MessageBoxButtons]::$Buttons,   
                                            [Windows.Forms.MessageBoxIcon]::$Icon,
                                            [Windows.Forms.MessageBoxDefaultButton]::$Default)
}
function Test-ADCredential([PSCredential]$Credential) {
        $cred = $Credential
        $username = $cred.username

        Try{
            
            Switch ((Get-ADUser $Credential.UserName -Credential $Credential -ErrorAction Stop).name){
                $username {
                    Write-Host "Credential Verified"
                    return $true
                }
                default { # Basically, handling a non-standard response.
                    Write-Host "Could not confirm Credential, try again."
                    return $false
                }
            }
        } catch { # The issuance of the command failed.
            #TODO: Need to update this with descriptive error message
            Write-Host "Something went wrong checking the credential, reachout to DJ Kemmet @ 9510900@carmax.com with a PD and steps to reproduce. "
            return $false
        }
    }

##
## GLOBALS
##
$Global:CredentialVerified = $false
Show-MessageBox -Title 'PA Account Required' -Message 'Hi there! This application requires your privileged access account to operate correctly. Please provide that credential and ensure your access level permits you to add a device to a specific application group.' -Icon Information -Buttons OK
$Global:LaunchCredential
$Global:LoginAttempts = 0
#endregion

while($Global:CredentialVerified -eq $false){
    switch($Global:CredentialVerified){
        $true{
            continue
        }
        $false{
            $Global:LoginAttempts += 1
            if($Global:LoginAttempts -gt 3){
                Show-MessageBox -Title "Too Many Login Attempts" -Message "Maximum number of tries exceeded.Make sure your PA account isn't locked out and try again."
                exit
            }
            $Global:LaunchCredential = Get-Credential
            $Global:CredentialVerified = Test-ADCredential -Credential $Global:LaunchCredential
        }
    }
}

#
# Functionalize: this needs to be Cyclical until the PA Credential is validated.
#

#region Create Canvas (form)
$UserConfigForm = New-Object System.Windows.Forms.Form
$UserConfigForm.Text = 'Computer Configurator - Release V0.2'
if ($Global:CredentialVerified -eq $true){
    $UserConfigForm.Text = "$($Global:LaunchCredential.UserName): Computer Configurator - Release V0.3"
}
$UserConfigForm.Size = New-Object System.Drawing.Size(1024, 900)
$UserConfigForm.WindowState = 'Maximized'
$UserConfigForm.StartPosition = 'CenterScreen'
#endregion


#region Focus User Controls
$ComputerNameLabel = New-Object System.Windows.Forms.Label
$ComputerNameLabel.Text = "Computer:"
$ComputerNameLabel.Location = New-Object System.Drawing.Size(25,10)
$ComputerNameLabel.Size = New-Object System.Drawing.Size(60, 20)
$UserConfigForm.Controls.add($ComputerNameLabel) 

$ComputerNameTextField = New-Object System.Windows.Forms.TextBox
$ComputerNameTextField.Location = New-Object System.Drawing.Size(85,10)
$UserConfigForm.Controls.add($ComputerNameTextField)

$UserFocusButton = New-Object System.Windows.Forms.Button
$UserFocusButton.Text = 'Focus on Computer'
$UserFocusButton.Location = New-Object System.Drawing.Size(25,40)
$UserFocusButton.Size = New-Object System.Drawing.Size(160,40)
$UserFocusButton.Add_Click($GenerateAndFillProfile)

$UserConfigForm.Controls.add($UserFocusButton)
#endregion

#region User Profile

#
# Computer DNS Name
#

$ComputerDNSNameLabel = New-Object System.Windows.Forms.Label
$ComputerDNSNameLabel.Text = "DNS Name: "
$ComputerDNSNameLabel.Location = New-Object System.Drawing.Size(25,100)
$UserConfigForm.Controls.Add($ComputerDNSNameLabel)

$ComputerDNSNameValue = New-Object System.Windows.Forms.Label
$ComputerDNSNameValue.Text = ''
$ComputerDNSNameValue.Location = New-Object System.Drawing.Size(150,100)
$ComputerDNSNameValue.AutoSize = $true
$UserConfigForm.Controls.Add($ComputerDNSNameValue)

#
# ACCOUNT STATUS
#
$ComputerStatusLabel = New-Object System.Windows.Forms.Label
$ComputerStatusLabel.Text = "Enabled:  "
$ComputerStatusLabel.Location = New-Object System.Drawing.Size(25, 125)
$UserConfigForm.Controls.Add($ComputerStatusLabel)

$ComputerStatusValue = New-Object System.Windows.Forms.Label
$ComputerStatusValue.Text = ""
$ComputerStatusValue.Location = New-Object System.Drawing.Size(150,125)
$UserConfigForm.Controls.Add($ComputerStatusValue)

##
## Computer name for CPU reciving groups.
##

$TargetComputerTextBox = New-Object System.Windows.Forms.TextBox
$TargetComputerTextBox.Location = New-Object System.Drawing.Size(125, 152)
$UserConfigForm.Controls.Add($TargetComputerTextBox)

##
## Group Sync Button
##
$ExportConfigJSONButton = New-Object System.Windows.Forms.Button
$ExportConfigJSONButton.Text = 'Sync Groups To:'
$ExportConfigJSONButton.AutoSize = $true
$ExportConfigJSONButton.Location = New-Object System.Drawing.Size(25, 150)
$ExportConfigJSONButton.Add_Click({

    # If the computer Exists and is enabled.
    If (Get-ADComputer -Identity $TargetComputerTextBox.Text){
        $TargetComputer = Get-ADComputer -Identity $TargetComputerTextBox.Text
        Show-MessageBox -Title "Found It!" -Message "Found the computer you're trying to apply groups to ( $($TargetComputerTextBox.Text) ) from ( $($ComputerDNSNameValue.Text) )"

        Get-ADPrincipalGroupMembership -Identity $(Get-ADComputer $Global:Computer) | ForEach-Object -Process {
            Add-ADGroupMember -Identity $_ -Members $TargetComputer -Credential $Global:LaunchCredential

        }
    } else {

    }
})
$UserConfigForm.Controls.Add($ExportConfigJSONButton)



#endregion

#region Procedurally Generated App Group Button Grid



$ApplicationGroups = Get-ADGroup -Filter '*' -SearchBase "OU=Software,OU=EndpointManagement,DC=KMX,DC=LOCAL" 
$ComputerApplicationGroups = Get-ADPrincipalGroupMembership -Identity (Get-ADComputer $(hostname)) | Select Name
$StartPosition = 25
$Horizontal = $StartPosition
$Vertical = 200
$ButtonCount = 0
$ApplicationGroups| Sort-Object | ForEach-Object {

    $x = 1

    if ($ButtonCount -ne 0){
        $Vertical+= 55 
    }

    $CurrentButton = $null
    $CurrentButton = New-Object System.Windows.Forms.Button
    $CurrentButton.Anchor = 'left,top'
    $CurrentButton.Location = New-Object System.Drawing.Point($Horizontal,$Vertical)
    # if ($_ -in $ApplicationGroups ) {
    #     $CurrentButton.BackColor = '#CCCC99'
    # }
    $CurrentButton.size = '140,55'
    $CurrentButton.Text = $_.Name
    $CurrentButton.Add_Click({
        Add-ADGroupMember -Identity $this.Text -Members (Get-ADComputer -Identity $ComputerNameTextField.Text).DistinguishedName -Credential $Global:LaunchCredential
        $ConfirmationDialog = New-Object -ComObject Wscript.shell
        $Output = $ConfirmationDialog.Popup("Computer $($ComputerNameTextField.Text) has been added to application group $($this.text)")
    })
    $CurrentButton.Name = "AppGroupButton$($ButtonCount)"
    $UserConfigForm.Controls.add($CurrentButton)
    $ButtonCount++

    if($ButtonCount -gt 8) {
        $Horizontal += 140 # Shift RIGHT
        $vertical = 200
        $ButtonCount = 0 #Reset our counter.
    }
}
$x = 1
#endregion

$UserConfigForm.ShowDialog()



