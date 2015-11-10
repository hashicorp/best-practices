# Silence progress bars in PowerShell, which can sometimes feed back strange
# XML data to the Packer output.
$ProgressPreference = "SilentlyContinue"

Write-Output "Starting PSWindowsUpdate Installation"
# Install PSWindowsUpdate for scriptable Windows Updates
$webDeployURL = "https://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc/file/41459/43/PSWindowsUpdate.zip"
$filePath = "$($env:TEMP)\PSWindowsUpdate.zip"

(New-Object System.Net.WebClient).DownloadFile($webDeployURL, $filePath)

$shell = New-Object -ComObject Shell.Application
$zipFile = $shell.NameSpace($filePath)
$destinationFolder = $shell.NameSpace("C:\Program Files\WindowsPowerShell\Modules")

$copyFlags = 0x00
$copyFlags += 0x04 # Hide progress dialogs
$copyFlags += 0x10 # Overwrite existing files

$destinationFolder.CopyHere($zipFile.Items(), $copyFlags)
# Clean up
Remove-Item -Force -Path $filePath

Write-Output "Ended PSWindowsUpdate Installation"

Write-Output "Starting Windows Update Installation"

Import-Module PSWindowsUpdate

if (Test-Path C:\Windows\Temp\PSWindowsUpdate.log) {
    # Save old logs
    Rename-Item -Path C:\Windows\Temp\PSWindowsUpdate.log -NewName PSWindowsUpdate-$((Get-Date).Ticks).log

    # Uncomment the line below to delete old logs instead
    #Remove-Item -Path C:\Windows\Temp\PSWindowsUpdate.log
}

try {
    $updateCommand = {ipmo PSWindowsUpdate; Get-WUInstall -AcceptAll -IgnoreReboot | Out-File C:\Windows\Temp\PSWindowsUpdate.log}
    $TaskName = "PackerUpdate"

    $User = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Scheduler = New-Object -ComObject Schedule.Service

    $Task = $Scheduler.NewTask(0)

    $RegistrationInfo = $Task.RegistrationInfo
    $RegistrationInfo.Description = $TaskName
    $RegistrationInfo.Author = $User.Name

    $Settings = $Task.Settings
    $Settings.Enabled = $True
    $Settings.StartWhenAvailable = $True
    $Settings.Hidden = $False

    $Action = $Task.Actions.Create(0)
    $Action.Path = "powershell"
    $Action.Arguments = "-Command $updateCommand"

    $Task.Principal.RunLevel = 1

    $Scheduler.Connect()
    $RootFolder = $Scheduler.GetFolder("\")
    $RootFolder.RegisterTaskDefinition($TaskName, $Task, 6, "SYSTEM", $Null, 1) | Out-Null
    $RootFolder.GetTask($TaskName).Run(0) | Out-Null

    Write-Output "The Windows Update log will be displayed below this message. No additional output indicates no updates were needed."
    do {
		sleep 1
		if ((Test-Path C:\Windows\Temp\PSWindowsUpdate.log) -and $script:reader -eq $null) {
			$script:stream = New-Object System.IO.FileStream -ArgumentList "C:\Windows\Temp\PSWindowsUpdate.log", "Open", "Read", "ReadWrite"
			$script:reader = New-Object System.IO.StreamReader $stream
		}
		if ($script:reader -ne $null) {
			$line = $Null
			do {$script:reader.ReadLine()
				$line = $script:reader.ReadLine()
				Write-Output $line
			} while ($line -ne $null)
		}
	} while ($Scheduler.GetRunningTasks(0) | Where-Object {$_.Name -eq $TaskName})
} finally {
    $RootFolder.DeleteTask($TaskName,0)
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Scheduler) | Out-Null
	if ($script:reader -ne $null) {
		$script:reader.Close()
		$script:stream.Dispose()
	}
}
Write-Output "Ended Windows Update Installation"
