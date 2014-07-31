### This script uses the DISM and DaRT PowerShell commands to create a bootable DaRT image.
### Both a WIM and ISO file are produced.

$ErrorActionPreference = "Stop";

Import-Module "Dism"
Import-Module "Microsoft.Dart"

$Win8MediaPath = "D:\";
$DestinationWimPath = "C:\DaRT81\boot.wim";
$DestinationIsoPath = "C:\DaRT81\DaRT81.iso";
$WadkInstallFolder = "C:\wadk";

$WimParentPath = (Split-Path -Path "$destinationWimPath" -Parent);
$IsoParentPath = (Split-Path -Path "$destinationIsoPath" -Parent);
$TempMountPath = "$env:temp\DaRT81Mount_$(Get-Random)";

New-Item -Path $WimParentPath -Type Directory -Force
New-Item -Path $IsoParentPath -Type Directory -Force
New-Item -Path $TempMountPath -Type Directory -Force

Copy-Item "$Win8MediaPath\sources\boot.wim" $DestinationWimPath -Force
Set-ItemProperty $DestinationWimPath -Name IsReadOnly -Value $false

Mount-WindowsImage -ImagePath $DestinationWimPath -Path $TempMountPath -Index 2

#Add-WindowsDriver -Path $TempMountPath -Driver "C:\Windows\System32\DriverStore\FileRepository\xusb22.inf_amd64_2dca7d3a8a25c0f2\xusb22.inf" -ForceUnsigned

Add-WindowsPackage -Path $TempMountPath -PackagePath "$WadkInstallFolder\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-FMAPI.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$WadkInstallFolder\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-Scripting.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$WadkInstallFolder\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-HTA.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$WadkInstallFolder\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-SecureStartup.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$WadkInstallFolder\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-WMI.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$WadkInstallFolder\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-WDS-Tools.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$WadkInstallFolder\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-LegacySetup.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$WadkInstallFolder\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-WinReCfg.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$WadkInstallFolder\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-Scripting.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$WadkInstallFolder\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-Setup.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$WadkInstallFolder\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-HTA.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$WadkInstallFolder\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-NetFx.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$WadkInstallFolder\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs\WinPE-PowerShell.cab"

$config = New-DartConfiguration -AddAllTools -UpdateDefender
$config | Set-DartImage -Path $TempMountPath

Dismount-WindowsImage -Path $TempMountPath -Save

Export-DartImage -IsoPath $DestinationIsoPath -WimPath $DestinationWimPath

Remove-Item $TempMountPath -Force -Recurse

