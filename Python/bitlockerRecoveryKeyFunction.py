#
#  AUTHOR:                  DJ Kemmet, 9510900@carmax.com
#  ICD:                     8/22
#  PURPOSE:                 Creates an interface for programmatically retriving Bitlocker recovery keys
#                           to facilitate self-service solutions.
#
from importlib.util import resolve_name
from time import sleep
from selenium import webdriver
from selenium.webdriver.common.by import By
# So I can make like a keyboard
from selenium.webdriver.common.keys import Keys

def retrieveBitlockerDecryptionKey(domain, username, firstEight):
    IEWindow = webdriver.Ie()
    IEWindow.get('https://bitlocker.carmax.org/helpdesk/KeyRecoveryPage.aspx')

    #
    # Fill out our form.
    #

    # id("DomainNameTextBox")
    DomainNameInput = IEWindow.find_element(By.XPATH, 'id("DomainNameTextBox")')
    DomainNameInput.send_keys(domain)
    sleep(2)
    
    # id("UserNameTextBox")
    UserNameInput = IEWindow.find_element(By.XPATH, 'id("UserNameTextBox")')
    UserNameInput.send_keys(username)
    sleep(2)
    
    # id("KeyIdTextBox")
    KeyIDInput = IEWindow.find_element(By.XPATH, 'id("KeyIdTextBox")')
    KeyIDInput.send_keys(firstEight)
    sleep(2)

    # id("ReasonCodeSelect")
    ReasonCodeDropdown = IEWindow.find_element(By.XPATH, 'id("ReasonCodeSelect")')
    ReasonCodeDropdown.send_keys(Keys.ARROW_DOWN) # BIOS Changed
    ReasonCodeDropdown.send_keys(Keys.ARROW_DOWN) # Opearting System Files Modified
    ReasonCodeDropdown.send_keys(Keys.ARROW_DOWN) # Lost Startup Key
    ReasonCodeDropdown.send_keys(Keys.ARROW_DOWN) # Lost PIN
    ReasonCodeDropdown.send_keys(Keys.ARROW_DOWN) # TPM Reset
    ReasonCodeDropdown.send_keys(Keys.ARROW_DOWN) # Lost Passphrase
    ReasonCodeDropdown.send_keys(Keys.ARROW_DOWN) # Lost Smartcard
    ReasonCodeDropdown.send_keys(Keys.ARROW_DOWN) # Other
    sleep(2)

    #
    # Step 2: Click the submit button.
    #         I must have fricked up because it doesn't seem to make .click() available in-line
    #         and that doesn't seem right. research later. 
    SubmitButton = IEWindow.find_element(By.XPATH, 'id("SubmitButton")')

    # Turns our this is more reliable than click()
    SubmitButton.send_keys(Keys.ENTER)

    #
    # Step 3: Wait a few seconds for the page to update, lets call it 7 seconds
    #
    sleep(5)

    #
    # Step 3: Scrape The recovery key from the page. 
    #
    RecoveryKey = IEWindow.find_element(By.XPATH, 'id("KeyReturnField")').get_attribute("Value")
    
    print(RecoveryKey)
    return RecoveryKey


# Example Usage: 
retrieveBitlockerDecryptionKey('kmx.local', '9510900', 'C11FEF83')