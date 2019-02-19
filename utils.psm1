[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

################################################################################
# Registry tweaks
function Registy-tweaks {
  Write-Host -ForegroundColor Cyan "Starting Registy-tweaks function..."

  Write-Output "Make the password and account of admin user never expire..."
  Set-LocalUser -Name $admin_username -PasswordNeverExpires $true -AccountNeverExpires

  Write-Output "Make the admin login at startup..."
  $registry = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
  Set-ItemProperty -Path $registry -Name "AutoAdminLogon" -Value "1" -type String
  Set-ItemProperty -Path $registry -Name "DefaultDomainName" -Value ([System.Net.Dns]::GetHostName()) -type String
  Set-ItemProperty -Path $registry -Name "DefaultUsername" -Value $admin_username -type String
  Set-ItemProperty -Path $registry -Name "DefaultPassword" -Value $admin_password -type String

  # From https://stackoverflow.com/questions/9701840/how-to-create-a-shortcut-using-powershell
  $desktop_folder = [Environment]::GetFolderPath("Desktop")
  Write-Output "Create disconnect shortcut under $desktop_folder\disconnect.lnk..."
  $WshShell = New-Object -comObject WScript.Shell
  $Shortcut = $WshShell.CreateShortcut("$desktop_folder\disconnect.lnk")
  $Shortcut.TargetPath = "C:\Windows\System32\tscon.exe"
  $Shortcut.Arguments = "1 /dest:console"
  $Shortcut.Save()

  Write-Output "Priority to programs, not background..."
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Type DWord -Value 38

  Write-Output "Explorer set to performance..."
  Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Type DWord -Value 2

  Write-Output "Disable crash dump..."
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -Name "CrashDumpEnabled" -Type DWord -Value 0

  Write-Output "Showing all tray icons..."
  If (!(Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer")) {
    New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" | Out-Null
  }
  Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoAutoTrayNotify" -Type DWord -Value 1

  $registry = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
  Write-Output "Showing known file extensions..."
  Set-ItemProperty -Path $registry -Name "HideFileExt" -Type DWord -Value 0
  Write-Output "Showing hidden files..."
  Set-ItemProperty -Path $registry -Name "Hidden" -Type DWord -Value 1
  Write-Output "Hiding item selection checkboxes..."
  Set-ItemProperty -Path $registry -Name "AutoCheckSelect" -Type DWord -Value 0
  Write-Output "Enabling navigation pane expanding to current folder..."
  Set-ItemProperty -Path $registry -Name "NavPaneExpandToCurrentFolder" -Type DWord -Value 1
  Write-Output "Changing default Explorer view to This PC..."
  Set-ItemProperty -Path $registry -Name "LaunchTo" -Type DWord -Value 1
  Write-Output "Setting taskbar buttons to combine when taskbar is full..."
  Set-ItemProperty -Path $registry -Name "TaskbarGlomLevel" -Type DWord -Value 1
  Set-ItemProperty -Path $registry -Name "MMTaskbarGlomLevel" -Type DWord -Value 1

  Write-Output "Disabling Sticky keys prompt..."
  Set-ItemProperty -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Type String -Value "506"

  Write-Output "Lowering UAC level..."
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Type DWord -Value 0
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Type DWord -Value 0

  Write-Output "Installing .NET Framework 2.0, 3.0 and 3.5 runtimes..."
  If ((Get-CimInstance -Class "Win32_OperatingSystem").ProductType -eq 1) {
    Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -NoRestart -WarningAction SilentlyContinue | Out-Null
  } Else {
    Install-WindowsFeature -Name "NET-Framework-Core" -WarningAction SilentlyContinue | Out-Null
  }

  Write-Output "Unpinning all Start Menu tiles..."
  If ([System.Environment]::OSVersion.Version.Build -ge 15063 -And [System.Environment]::OSVersion.Version.Build -le 16299) {
    Get-ChildItem -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount" -Include "*.group" -Recurse | ForEach-Object {
      $data = (Get-ItemProperty -Path "$($_.PsPath)\Current" -Name "Data").Data -Join ","
      $data = $data.Substring(0, $data.IndexOf(",0,202,30") + 9) + ",0,202,80,0,0"
      Set-ItemProperty -Path "$($_.PsPath)\Current" -Name "Data" -Type Binary -Value $data.Split(",")
    }
  } ElseIf ([System.Environment]::OSVersion.Version.Build -ge 17134) {
    $key = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\*start.tilegrid`$windows.data.curatedtilecollection.tilecollection\Current"
    $data = $key.Data[0..25] + ([byte[]](202,50,0,226,44,1,1,0,0))
    Set-ItemProperty -Path $key.PSPath -Name "Data" -Type Binary -Value $data
    Stop-Process -Name "ShellExperienceHost" -Force -ErrorAction SilentlyContinue
  }

  Write-Output "Disabling Lock screen..."
    If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization")) {
      New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" | Out-Null
    }
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "NoLockScreen" -Type DWord -Value 1

  Write-Output "Disabling Location Tracking..."
  If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location")) {
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Force | Out-Null
  }
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Type String -Value "Deny"
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Type DWord -Value 0
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" -Name "Status" -Type DWord -Value 0

  Write-Host -ForegroundColor Green "Done."
}

################################################################################
# Install Local Experience Packs
function Install-LanguageExperiencePack {
  Write-Host -ForegroundColor Cyan "Starting Install-LanguageExperiencePack function..."

  Write-Output "Adding secondary fr-FR keyboard..."
  $langs = Get-WinUserLanguageList
  $langs.Add("fr-FR")
  Set-WinUserLanguageList $langs -Force

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
  $url = "https://go.microsoft.com/fwlink/?linkid=874181"

  Write-Output "Installing Nvidia Driver $nvidia_version"
  Write-Output "Downloading..."
  (New-Object System.Net.WebClient).DownloadFile($url, "$PSScriptRoot\$driver_file")

  Write-Output "Extracting..."
  $extractFolder = "$PSScriptRoot\NVIDIA"
  $filesToExtract = "Display.Driver NGXCore NVI2 NVWMI EULA.txt license.txt setup.cfg setup.exe"
  Start-Process -FilePath "$env:programfiles\7-zip\7z.exe" -ArgumentList "x $PSScriptRoot\$driver_file $filesToExtract -o""$extractFolder""" -wait

  Write-Output "Installing..."
  Start-Process -FilePath "$extractFolder\setup.exe"  -ArgumentList "-s", "-noreboot", "-noeula", "-clean" -Wait

  Write-Output "Cleaning..."
  Remove-Item -Path "$PSScriptRoot\$driver_file" -Confirm:$false
  Remove-Item -Path "$extractFolder" -Recurse -Confirm:$false

  Write-Host -ForegroundColor Green "Done."
}

################################################################################
# Manage Display Adapters
function Manage-Display-Adapters {
  Write-Host -ForegroundColor Cyan "Starting Manage-Display-Adapters function..."

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

  Write-Output "Enabling NvFBC..."
  (New-Object System.Net.WebClient).DownloadFile("https://github.com/nVentiveUX/azure-gaming/raw/master/NvFBCEnable.zip", "$PSScriptRoot\NvFBCEnable.zip")
  Expand-Archive -LiteralPath "$PSScriptRoot\NvFBCEnable.zip" -DestinationPath "$PSScriptRoot"
  & "$PSScriptRoot\NvFBCEnable.exe" -enable -noreset

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
  Remove-Item -Path "$PSScriptRoot\$wdk_installer" -Confirm:$false

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
  (New-Object System.Net.WebClient).DownloadFile("http://media.steampowered.com/client/installer/SteamSetup.exe", "$PSScriptRoot\$steam_exe")
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
