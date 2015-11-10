# Silence progress bars in PowerShell, which can sometimes feed back strange
# XML data to the Packer output.
$ProgressPreference = "SilentlyContinue"

Write-Output "Starting IIS Installation"

Import-Module ServerManager

# IIS

# Only needed for .NET 3, .NET 4/4.5 is already installed.
#Add-WindowsFeature NET-Framework-Core

Add-WindowsFeature Web-Server -IncludeAllSubFeature

Write-Output "Ended IIS Installation"

# WebDeploy
Write-Output "Starting WebDeploy Installation"

# Install Microsoft Web Deploy to be able to deploy website packages easily
$webDeployURL = "http://download.microsoft.com/download/D/4/4/D446D154-2232-49A1-9D64-F5A9429913A4/WebDeploy_amd64_en-US.msi"
$filePath = "$($env:TEMP)\WebDeploy_amd64_en-US.msi"

(New-Object System.Net.WebClient).DownloadFile($webDeployURL, $filePath)

Start-Process -FilePath msiexec -ArgumentList /i, $filePath, /qn -Wait

# Clean up
Remove-Item -Force -Path $filePath

Write-Output "Ended WebDeploy Installation"
