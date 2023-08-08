#
# This script is a Proof of Concept for uploading aloha POS Transaction logs to
# the Office365 / OneDrive For Business account of the store the server is 
# running in. This helps with recovery.
#


$Settings = @{

    "AnotherSetting" = 1
    "OneMoreSetting" = $true
}
$Credentials = Get-Credential

#
# PHASE ONE: Get The TLOGS
# To minimize disruption and avoid corruption we're going to copy the files off the store server and 
# on to the host running this script. 
#

# Get-ADComputer -Server "<SERVER_ADDRESS>" -SearchBase "<AD_OU>" -Filter * | ForEach-Object -Process { 

#     $Session = Enter-PSSession -ComputerName $_.dnshostname -Credential $Credentials
#     Invoke-Command -Session $Session -Script { }
    
#     $x = 1
#     Write-Host $_.dnshostname

# }

#
# PHASE TWO: Start Uploading the TLOGS
# We're going to upload the TLOGS from the Host this script is running on to 
#
#



#Specify tenant admin and site URL
$User = "<EMAIL_ADDRESS>"
$SiteURL = "<SHAREPONT_SITE>"


#This would be THe Directories where the translog or dated subs folder exist on the server
$Folder = "C:\Users\dkemmet\Desktop\"

# The Sharepoint Document library where we want to upload our documents to. 
$DocLibName = "Documents"

#Add references to SharePoint client assemblies and authenticate to Office 365 site – required for CSOM
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.dll"
Add-Type -Path "C:\Program Files\Common Files\Microsoft Shared\Web Server Extensions\16\ISAPI\Microsoft.SharePoint.Client.Runtime.dll"

# Muh P-wurd
$Password  = ConvertTo-SecureString "<PASSWORD_SHAME_I_KNOW>" -AsPlainText -Force


#Bind to site collection and add my credentials to the context (session?)
$Context = New-Object Microsoft.SharePoint.Client.ClientContext($SiteURL)
$Creds = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($User,$Password)
$Context.Credentials = $Creds

#Retrieve list
$List = $Context.Web.Lists.GetByTitle("$DocLibName")

# Get The Contents of the Document Library so we can check to see if our DatedSubs directory is there
$LibraryContents = $List.GetItems([Microsoft.SharePoint.Client.CamlQuery]::CreateAllItemsQuery())

$Context.Load($LibraryContents)


$LibraryContents | ForEach-Object -Process {
    Write-Host $_.Name
}

$x = 1

$Context.Load($List)
$Context.ExecuteQuery()


#TODO: Target uploads to a folder for the store.
#Upload file
Foreach ($File in (Get-ChildItem $Folder -File))
{
$FileStream = New-Object IO.FileStream($File.FullName,[System.IO.FileMode]::Open)
$FileCreationInfo = New-Object Microsoft.SharePoint.Client.FileCreationInformation
$FileCreationInfo.Overwrite = $true
$FileCreationInfo.ContentStream = $FileStream
$FileCreationInfo.URL = $File
$Upload = $List.RootFolder.Files.Add($FileCreationInfo)
$Context.Load($Upload)
$Context.ExecuteQuery()
}