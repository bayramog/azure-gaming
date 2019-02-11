[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

################################################################################
# Registry tweaks
function Registy-tweaks {
  Write-Host -ForegroundColor Cyan "Starting Registy-tweaks function..."

  Write-Output "Make the password and account of admin user never expire."
  Set-LocalUser -Name $admin_username -PasswordNeverExpires $true -AccountNeverExpires

  Write-Output "Make the admin login at startup."
  $registry = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
  Set-ItemProperty $registry "AutoAdminLogon" -Value "1" -type String
  Set-ItemProperty $registry "DefaultDomainName" -Value ([System.Net.Dns]::GetHostName()) -type String
  Set-ItemProperty $registry "DefaultUsername" -Value $admin_username -type String
  Set-ItemProperty $registry "DefaultPassword" -Value $admin_password -type String

  # From https://stackoverflow.com/questions/9701840/how-to-create-a-shortcut-using-powershell
  Write-Output "Create disconnect shortcut under C:\disconnect.lnk"
  $WshShell = New-Object -comObject WScript.Shell
  $Shortcut = $WshShell.CreateShortcut("C:\disconnect.lnk")
  $Shortcut.TargetPath = "C:\Windows\System32\tscon.exe"
  $Shortcut.Arguments = "1 /dest:console"
  $Shortcut.Save()

  Write-Output "Priority to programs, not background"
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38

  Write-Output "Explorer set to performance"
  Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2

  Write-Output "Disable crash dump"
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "CrashDumpEnabled" -Value 0

  Write-Output "Show file extensions, hidden items and disable item checkboxes"
  $registry = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
  Set-ItemProperty $registry HideFileExt 0
  Set-ItemProperty $registry HideDrivesWithNoMedia 0
  Set-ItemProperty $registry Hidden 1
  Set-ItemProperty $registry AutoCheckSelect 0

  Write-Output "Weird accessibility stuff"
  Set-ItemProperty "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "506"
  Set-ItemProperty "HKCU:\Control Panel\Accessibility\Keyboard Response" "Flags" "122"
  Set-ItemProperty "HKCU:\Control Panel\Accessibility\ToggleKeys" "Flags" "58"

  Write-Output "Do not combine taskbar buttons and no tray hiding stuff"
  Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name TaskbarGlomLevel -Value 2
  Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name EnableAutoTray -Value 0

  Write-Output "Disable UAC"
  New-ItemProperty -Path "HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system" -Name EnableLUA -PropertyType DWord -Value 1 -Force | Out-Null
  New-ItemProperty -Path "HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system" -Name ConsentPromptBehaviorAdmin -PropertyType DWord -Value 0 -Force | Out-Null
  New-ItemProperty -Path "HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system" -Name PromptOnSecureDesktop -PropertyType DWord -Value 0 -Force | Out-Null

  Write-Host -ForegroundColor Green "Done."
}

################################################################################
# Install Local Experience Packs: fr-fr
function Install-LanguageExperiencePackfr {
  Write-Host -ForegroundColor Cyan "Starting Install-LanguageExperiencePackfr function..."

  $ManifestPath = (Get-AppxPackage Microsoft.LanguageExperiencePackfr-fr).InstallLocation + "\Appxmanifest.xml"
  Add-AppxPackage -Path $ManifestPath -Register -DisableDevelopmentMode

  Write-Host -ForegroundColor Green "Done."
}

################################################################################
# Install 7zip
function Install-7zip {
  Write-Host -ForegroundColor Cyan "Starting Install-7zip function..."

  $7Zip_exe = "7Zip.exe"
  Write-Output "Downloading 7zip into path $PSScriptRoot\$7Zip_exe"
  (New-Object System.Net.WebClient).DownloadFile("https://www.7-zip.org/a/7z1806-x64.exe", "$PSScriptRoot\$7Zip_exe")

  Write-Output "Installing 7Zip"
  Start-Process -FilePath "$PSScriptRoot\$7Zip_exe" -ArgumentList "/S" -Wait
  Remove-Item -Path "$PSScriptRoot\$7Zip_exe" -Confirm:$false

  Write-Host -ForegroundColor Green "Done."
}

################################################################################
# Install NVIDIA drivers
function Install-NvidiaDriver {
  Write-Host -ForegroundColor Cyan "Starting Install-NvidiaDriver function..."

  $driver_file = "nvidia-driver.exe"
  $drivers = (New-Object System.Net.WebClient).DownloadString("https://www.nvidia.com/Download/processFind.aspx?psid=75&pfid=783&osid=57&lid=1&whql=1&lang=en-us")
  $nvidia_version = $($drivers -match '<td class="gridItem">(\d\d\d\.\d\d)</td>' | Out-Null; $Matches[1])
  # $url = "http://international.download.nvidia.com/Windows/Quadro_Certified/$nvidia_version/$nvidia_version-quadro-grid-desktop-notebook-win10-64bit-international-whql.exe"
  $url = "http://international.download.nvidia.com/Windows/Quadro_Certified/$nvidia_version/$nvidia_version-tesla-desktop-win10-64bit-international.exe"

  Write-Output "Installing Nvidia Driver $nvidia_version"
  Write-Output "Downloading..."
  (New-Object System.Net.WebClient).DownloadFile($url, "$PSScriptRoot\$driver_file")

  Write-Output "Extracting..."
  $extractFolder = "C:\NVIDIA\DisplayDriver\$nvidia_version\Win10_64\International"
  $filesToExtract = "Display.Driver NGXCore NVI2 PhysX NVWMI PPC EULA.txt ListDevices.txt setup.cfg setup.exe"
  Start-Process -FilePath "$env:programfiles\7-zip\7z.exe" -ArgumentList "x $PSScriptRoot\$driver_file $filesToExtract -o""$extractFolder""" -wait
  (Get-Content "$extractFolder\setup.cfg") | Where-Object {$_ -notmatch 'name="\${{(EulaHtmlFile|FunctionalConsentFile|PrivacyPolicyFile)}}'} | Set-Content "$extractFolder\setup.cfg" -Encoding UTF8 -Force

  Write-Output "Installing..."
  Start-Process -FilePath "$extractFolder\setup.exe"  -ArgumentList "-s", "-noreboot", "-noeula", "-clean" -Wait

  Write-Output "Cleaning..."
  Remove-Item -Path "$PSScriptRoot\$driver_file" -Confirm:$false
  Remove-Item -Path "$extractFolder" -Confirm:$false

  Write-Host -ForegroundColor Green "Done."
}

################################################################################
# Disabling Hyper-V Video
function Disable-Devices {
  Write-Host -ForegroundColor Cyan "Starting Disable-Devices function..."

  $url = "https://gallery.technet.microsoft.com/PowerShell-Device-60d73bb0/file/147248/2/DeviceManagement.zip"
  $compressed_file = "DeviceManagement.zip"
  $extract_folder = "DeviceManagement"

  Write-Output "Downloading Device Management Powershell Script"
  (New-Object System.Net.WebClient).DownloadFile($url, "$PSScriptRoot\$compressed_file")
  Unblock-File -Path "$PSScriptRoot\$compressed_file"

  Write-Output "Extracting Device Management Powershell Script"
  Expand-Archive "$PSScriptRoot\$compressed_file" -DestinationPath "$PSScriptRoot\$extract_folder" -Force
  Remove-Item -Path "$PSScriptRoot\$compressed_file" -Confirm:$false

  Import-Module "$PSScriptRoot\$extract_folder\DeviceManagement.psd1"
  Write-Output "Disabling Microsoft Hyper-V Video"
  Get-Device | Where-Object -Property Name -Like "Microsoft Hyper-V Video" | Disable-Device -Confirm:$false
  Write-Output "Disabling Generic PnP Monitor"
  Get-Device | Where-Object -Property Name -Like "Generic PnP Monitor" | Where DeviceParent -like "*BasicDisplay*" | Disable-Device  -Confirm:$false

  Write-Output "Delete the basic display adapter's drivers (since Parsec still see 2 Display adapter)"
  takeown /f C:\Windows\System32\Drivers\BasicDisplay.sys
  icacls C:\Windows\System32\Drivers\BasicDisplay.sys /grant "$env:username`:F"
  move C:\Windows\System32\Drivers\BasicDisplay.sys C:\Windows\System32\Drivers\BasicDisplay.old

  Write-Host -ForegroundColor Green "Done."
}

################################################################################
# Disable TCC
function Disable-TCC {
  Write-Host -ForegroundColor Cyan "Starting Disable-TCC function..."

  $nvsmi = "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
  $gpu = & $nvsmi --format=csv,noheader --query-gpu=pci.bus_id
  & $nvsmi -g $gpu -fdm 0

  Write-Host -ForegroundColor Green "Done."
}

################################################################################
# Install-VirtualAudio
function Install-VirtualAudio {
  Write-Host -ForegroundColor Cyan "Starting Install-VirtualAudio function..."

  $compressed_file = "VBCABLE_Driver_Pack43.zip"
  $driver_folder = "VBCABLE_Driver_Pack43"
  $driver_inf = "vbMmeCable64_win7.inf"
  $hardward_id = "VBAudioVACWDM"
  $wdk_installer = "wdksetup.exe"
  $devcon = "C:\Program Files (x86)\Windows Kits\10\Tools\x64\devcon.exe"

  Write-Output "Downloading Windows Development Kit installer"
  (New-Object System.Net.WebClient).DownloadFile("http://go.microsoft.com/fwlink/p/?LinkId=526733", "$PSScriptRoot\$wdk_installer")

  Write-Output "Installing Windows Development Kit"
  Start-Process -FilePath "$PSScriptRoot\$wdk_installer" -ArgumentList "/S" -Wait
  Remove-Item -Path "$PSScriptRoot\$compressed_file" -Confirm:$false

  Write-Output "Downloading Virtual Audio Driver"
  (New-Object System.Net.WebClient).DownloadFile("http://vbaudio.jcedeveloppement.com/Download_CABLE/$compressed_file", "$PSScriptRoot\$compressed_file")
  Unblock-File -Path "$PSScriptRoot\$compressed_file"

  Write-Output "Extracting Virtual Audio Driver"
  Expand-Archive "$PSScriptRoot\$compressed_file" -DestinationPath "$PSScriptRoot\$driver_folder" -Force
  Remove-Item -Path "$PSScriptRoot\$compressed_file" -Confirm:$false

  Write-Output "Importing vb certificate"
  (Get-AuthenticodeSignature -FilePath "$PSScriptRoot\$driver_folder\vbaudio_cable64_win7.cat").SignerCertificate | Export-Certificate -Type CERT -FilePath "$PSScriptRoot\$driver_folder\vbcable.cer" | Out-Null
  Import-Certificate -FilePath "$PSScriptRoot\$driver_folder\vbcable.cer" -CertStoreLocation "cert:\LocalMachine\TrustedPublisher" | Out-Null

  Write-Output "Installing virtual audio driver"
  Start-Process -FilePath $devcon -ArgumentList "install", "$PSScriptRoot\$driver_folder\$driver_inf", $hardward_id -Wait

  Write-Host -ForegroundColor Green "Done."
}

################################################################################
# Install ZeroTier VPN
function Install-VPN {
  Write-Host -ForegroundColor Cyan "Starting Install-VPN function..."

  Write-Output "Disabling Teredo tunneling"
  Set-Net6to4Configuration -State disabled
  Set-NetTeredoConfiguration -Type disabled
  Set-NetIsatapConfiguration -State disabled

  Write-Output "Downloading ZeroTier"
  (New-Object System.Net.WebClient).DownloadFile("https://download.zerotier.com/dist/ZeroTier%20One.msi", "$PSScriptRoot\zerotier.msi")

  Write-Output "Installing ZeroTier"
  Start-Process -FilePath "$PSScriptRoot\zerotier.msi" -ArgumentList "/quiet" -Wait
  Remove-Item -Path "$PSScriptRoot\zerotier.msi" -Confirm:$false

  Write-Host -ForegroundColor Green "Done."
}

################################################################################
# Install Steam
function Install-Steam {
  Write-Host -ForegroundColor Cyan "Starting Install-Steam function..."

  $steam_exe = "steam.exe"
  Write-Output "Downloading steam into path $PSScriptRoot\$steam_exe"
  (New-Object System.Net.WebClient).DownloadFile("https://steamcdn-a.akamaihd.net/client/installer/SteamSetup.exe", "$PSScriptRoot\$steam_exe")
  Write-Output "Installing steam"
  Start-Process -FilePath "$PSScriptRoot\$steam_exe" -ArgumentList "/S" -Wait
  Remove-Item -Path "$PSScriptRoot\$steam_exe" -Confirm:$false

  Write-Host -ForegroundColor Green "Done."
}

################################################################################
# Install Parsec
function Install-Parsec {
  Write-Host -ForegroundColor Cyan "Starting Install-Parsec function..."

  $parsec_exe = "parsec-windows.exe"
  Write-Output "Downloading Parsec into path $PSScriptRoot\$parsec_exe"
  (New-Object System.Net.WebClient).DownloadFile("https://s3.amazonaws.com/parsec-build/package/parsec-windows.exe", "$PSScriptRoot\$parsec_exe")
  Write-Output "Installing Parsec"
  Start-Process -FilePath "$PSScriptRoot\$parsec_exe" -ArgumentList "/S" -Wait
  Remove-Item -Path "$PSScriptRoot\$parsec_exe" -Confirm:$false

  Write-Host -ForegroundColor Green "Done."
}

################################################################################
# Install Epic Games Launcher
function Install-EpicGameLauncher {
  Write-Host -ForegroundColor Cyan "Starting Install-EpicGameLauncher function..."

  $epic_msi = "EpicGamesLauncherInstaller.msi"
  Write-Output "Downloading Epic Games Launcher into path $PSScriptRoot\$epic_msi"
  (New-Object System.Net.WebClient).DownloadFile("https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi", "$PSScriptRoot\$epic_msi")
  Write-Output "Installing Epic Games Launcher"
  Start-Process -FilePath "$PSScriptRoot\$epic_msi" -ArgumentList "/quiet" -Wait
  Remove-Item -Path "$PSScriptRoot\$epic_msi" -Confirm:$false

  Write-Host -ForegroundColor Green "Done."
}
