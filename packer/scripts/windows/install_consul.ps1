write-output "Creating Consul directories"
foreach ($dir in @('log', 'data')) {
  New-Item -Path "C:\opt\consul\$dir" -ItemType Directory -Force
}

write-output "Creating nssm directory"
New-Item -Path "C:\opt\nssm" -ItemType Directory -Force

write-output "Setting urls"
$nssmUrl = "http://nssm.cc/release/nssm-2.24.zip"
$consulUrl = "https://releases.hashicorp.com/consul/0.6.0-rc1/consul_0.6.0-rc1_windows_amd64.zip"
$uiUrl = "https://releases.hashicorp.com/consul/0.6.0-rc1/consul_0.6.0-rc1_web_ui.zip"

write-output "Setting file paths"
$nssmFilePath = "$($env:TEMP)\nssm.zip"
$consulFilePath = "$($env:TEMP)\consul.zip"
$uiFilePath = "$($env:TEMP)\consulwebui.zip"

write-output "Downloading nssm"
(New-Object System.Net.WebClient).DownloadFile($nssmUrl, $nssmFilePath)
write-output "Downloading Consul"
(New-Object System.Net.WebClient).DownloadFile($consulUrl, $consulFilePath)
write-output "Downloading Consul Web UI"
(New-Object System.Net.WebClient).DownloadFile($uiUrl, $uiFilePath)

write-output "Creating shell object"
$shell = New-Object -ComObject Shell.Application

write-output "Setting namespaces"
$nssmZip = $shell.NameSpace($nssmFilePath)
$consulZip = $shell.NameSpace($consulFilePath)
$uiZip = $shell.NameSpace($uiFilePath)

write-output "Setting destinations"
$nssmDestination = $shell.NameSpace("C:\opt\nssm")
$consulDestination = $shell.NameSpace("C:\opt\consul")
$uiDestination = $shell.NameSpace("C:\opt\consul")

write-output "Setting copy flags"
$copyFlags = 0x00
$copyFlags += 0x04 # Hide progress dialogs
$copyFlags += 0x10 # Overwrite existing files

write-output "Copying nssm"
$nssmDestination.CopyHere($nssmZip.Items(), $copyFlags)
write-output "Copying Consul"
$consulDestination.CopyHere($consulZip.Items(), $copyFlags)
write-output "Copying Consul Web UI"
$uiDestination.CopyHere($uiZip.Items(), $copyFlags)

# Alternative way to unzip
# cmd /c "7z e C:\install\consul\0.5.2_windows_386.zip -oC:\opt\consul > C:\install_log\consul.log"

# Move nssm exe to /opt
write-output "Moving nssm"
Move-Item -Path "C:\opt\nssm\nssm-2.24\win32\nssm.exe" "C:\opt" -Force
write-output "Moving Consul Web UI"
Move-Item -Path "C:\opt\consul\dist" "C:\opt\consul\ui" -Force

# Clean up
write-output "Cleanup"
#Remove-Item -Force -Path "C:\opt\nssm"
Remove-Item -Force -Path $consulFilePath
Remove-Item -Force -Path $uiFilePath
Remove-Item -Force -Path $nssmFilePath

# Create the Consul service and set its options
write-output "Creating Consul service"
C:\opt\nssm.exe install consul "C:\opt\consul\consul.exe" agent -config-dir "C:\etc\consul.d"
write-output "Setting Consul options"
C:\opt\nssm.exe set consul AppEnvironmentExtra "GOMAXPROCS=%NUMBER_OF_PROCESSORS%"
C:\opt\nssm.exe set consul AppRotateFiles 1
C:\opt\nssm.exe set consul AppRotateOnline 1
C:\opt\nssm.exe set consul AppRotateBytes 10485760
C:\opt\nssm.exe set consul AppStdout C:\opt\consul\log\consul.log
C:\opt\nssm.exe set consul AppStderr C:\opt\consul\log\consul.log

write-output "Stopping Consul service"
Stop-Service consul -EA silentlycontinue
Set-Service consul -StartupType Manual

# Disable negative DNS response caching
write-output "Disable negative DNS response caching"
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters -Name MaxNegativeCacheTtl -Value 0 -Type DWord

# Allow Consul Serf traffic through the firewall
write-output "Set firewall"
netsh advfirewall firewall add rule name="Consul Serf LAN TCP" dir=in action=allow protocol=TCP localport=8301
netsh advfirewall firewall add rule name="Consul Serf LAN UDP" dir=in action=allow protocol=UDP localport=8301
