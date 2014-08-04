### This script uses the DISM and DaRT PowerShell commands to create a bootable DaRT image.
### Both a WIM and ISO file are produced.

# TODO : test elevated

$ErrorActionPreference = "Stop";

Import-Module "Dism"
Import-Module "Microsoft.Dart"

$SourceMediaPath = "D:\";
$DartVersion = "8.1";
$WadkInstallFolder = "C:\Program Files (x86)\Windows Kits\$DartVersion";

$SourceWimPath = "$SourceMediaPath\sources\boot.wim";
$sourceWimIndex = 2;

$SourceWimInfo = Dism /Get-WimInfo /WimFile="$SourceWimPath" /Index=$sourceWimIndex
$SourceArchitecture = ([regex]::Match(($SourceWimInfo | Select-String "^Architecture : "),'(x86|x64)')).Value
$SourceVersion = ([regex]::Match(($SourceWimInfo | Select-String "^Version : "),'([0-9\.]+)')).Value

$DestinationWimPath = "C:\DaRT\boot-$SourceArchitecture-$SourceVersion.wim";
$DestinationIsoPath = "C:\DaRT\DaRT81-Win-$SourceArchitecture-$SourceVersion.iso";

if ($SourceArchitecture -eq "x64") {
$AdkPackagePath = "$WadkInstallFolder\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64";
} else {
$AdkPackagePath = "$WadkInstallFolder\Assessment and Deployment Kit\Windows Preinstallation Environment\x86";
}

$WimParentPath = (Split-Path -Path "$destinationWimPath" -Parent);
$IsoParentPath = (Split-Path -Path "$destinationIsoPath" -Parent);
$TempMountPath = "$env:temp\DaRT-Mount_$(Get-Random)";

New-Item -Path $WimParentPath -Type Directory -Force
New-Item -Path $IsoParentPath -Type Directory -Force
New-Item -Path $TempMountPath -Type Directory -Force

Copy-Item $SourceWimPath $DestinationWimPath -Force
Set-ItemProperty $DestinationWimPath -Name IsReadOnly -Value $false

Mount-WindowsImage -ImagePath $DestinationWimPath -Path $TempMountPath -Index $sourceWimIndex
try {

#Add-WindowsDriver -Path $TempMountPath -Driver "C:\Windows\System32\DriverStore\FileRepository\xusb22.inf_amd64_2dca7d3a8a25c0f2\xusb22.inf" -ForceUnsigned

Add-WindowsPackage -Path $TempMountPath -PackagePath "$AdkPackagePath\WinPE_OCs\WinPE-FMAPI.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$AdkPackagePath\WinPE_OCs\WinPE-Scripting.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$AdkPackagePath\WinPE_OCs\WinPE-HTA.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$AdkPackagePath\WinPE_OCs\WinPE-SecureStartup.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$AdkPackagePath\WinPE_OCs\WinPE-WMI.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$AdkPackagePath\WinPE_OCs\WinPE-WDS-Tools.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$AdkPackagePath\WinPE_OCs\WinPE-LegacySetup.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$AdkPackagePath\WinPE_OCs\WinPE-WinReCfg.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$AdkPackagePath\WinPE_OCs\WinPE-Scripting.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$AdkPackagePath\WinPE_OCs\WinPE-Setup.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$AdkPackagePath\WinPE_OCs\WinPE-HTA.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$AdkPackagePath\WinPE_OCs\WinPE-NetFx.cab"
Add-WindowsPackage -Path $TempMountPath -PackagePath "$AdkPackagePath\WinPE_OCs\WinPE-PowerShell.cab"

$config = New-DartConfiguration -AddAllTools -UpdateDefender
$config | Set-DartImage -Path $TempMountPath

Dismount-WindowsImage -Path $TempMountPath -Save

Export-DartImage -IsoPath $DestinationIsoPath -WimPath $DestinationWimPath

}
catch { Dismount-WindowsImage -Path $TempMountPath -Discard }
finally { Remove-Item $TempMountPath -Force -Recurse }

