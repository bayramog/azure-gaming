<#
.SYNOPSIS
    Bootstrap an Azure VM running Windows 10.

.DESCRIPTION
    This script requires administrative privileges.
#>

$script_name = "utils.psm1"
Import-Module "C:\$script_name"

Disable-Devices
Disable-TCC
Install-VirtualAudio
Install-Steam
Install-EpicGameLauncher
Install-Parsec

Write-Host -ForegroundColor Yellow "Would you like to reboot now?"
$Readhost = Read-Host "(Y/N) Default is no"
Switch ($ReadHost) {
    Y {Write-host "Rebooting now..."; Start-Sleep -s 2; Restart-Computer}
    N {Write-Host "Exiting script in 5 seconds."; Start-Sleep -s 5}
    Default {Write-Host "Exiting script in 5 seconds"; Start-Sleep -s 5}
}

# End of script
exit