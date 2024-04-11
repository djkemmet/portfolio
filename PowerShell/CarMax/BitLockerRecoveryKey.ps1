Import-Module Selenium

function Get-BitlockerDecryptionKey([String]$Domain, [String]$Username, [Int]$KeyID){
    
    #Open Browser and Navigate to recovery page.
    $IEBrowserWindow = Start-SeInternetExplorer
    
    # E Doesn't support headless, so basically there's always going to be a window in 
    # this script's runspace.
    Enter-SeUrl -Url '' -Driver $IEBrowserWindow

    # Find and Fill Doamin Name TextBox
    $DomainNameInput = Find-SeElement -Driver $IEBrowserWindow -Id "DomainNameTextBox"
    Send-SeKeys -Element $DomainNameInput -Keys $Domain

    # Find and Fill Username TextBox
    $UsernameInput = Find-SeElement -Driver $IEBrowserWindow -Id "UserNameTextBox"
    Send-SeKeys -Element $UsernameInput -Keys $Username

    # Find and Fill Key ID TextBox
    $KeyIDInput = Find-SeElement -Driver $IEBrowserWindow -Id "KeyIdTextBox"
    Send-SeKeys -Element $KeyIDInput -Keys $KeyID

    # Cycle to correct Reason Code
    $ReasonCodeDropDown = Find-SeElement -Driver $IEBrowserWindow -Id "ReasonCodeSelect"
    $ReasonCodeDropDown.SendKeys([OpenQA.Selenium.Keys]::ArrowDown) # BIOS Changed
    $ReasonCodeDropDown.SendKeys([OpenQA.Selenium.Keys]::ArrowDown) # Opearting System Files Modified
    $ReasonCodeDropDown.SendKeys([OpenQA.Selenium.Keys]::ArrowDown) # Lost Startup Key
    $ReasonCodeDropDown.SendKeys([OpenQA.Selenium.Keys]::ArrowDown) # Lost PIN
    $ReasonCodeDropDown.SendKeys([OpenQA.Selenium.Keys]::ArrowDown) # TPM Reset
    $ReasonCodeDropDown.SendKeys([OpenQA.Selenium.Keys]::ArrowDown) # Lost Passphrase
    $ReasonCodeDropDown.SendKeys([OpenQA.Selenium.Keys]::ArrowDown) # Lost Smartcard
    $ReasonCodeDropDown.SendKeys([OpenQA.Selenium.Keys]::ArrowDown) # Other

    # Click the Submit button
    $SubmitButton = Find-SeElement -Driver $IEBrowserWindow -Id "SubmitButton"
    $SubmitButton.SendKeys([OpenQA.Selenium.Keys]::Enter)
    
    # Wait 3 second for the page to refresh
    Start-Sleep -seconds 5

    # Extreact the recovery key
    $RecoveryKey = $IEBrowserWindow.FindElementByXPath("id('KeyReturnField')").getAttribute('value')

    # Return the Recovery key.
    Write-Host $RecoveryKey
    Return $RecoveryKey
} # End Function

Get-BitlockerDecryptionKey -Domain "" -Username '' -KeyID 
