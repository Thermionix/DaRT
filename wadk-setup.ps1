
$adkfolder="C:\wadk_setup\offline\"
$wadkfolder="C:\wadk\"
$isofolder="C:\wadk_setup\"
$isoname="wadk81"

$adksetupexe="adksetup.exe"
$adksetupurl="http://download.microsoft.com/download/6/A/E/6AEA92B0-A412-4622-983E-5B305D2EBE56/adk/adksetup.exe"

$ErrorActionPreference = "Stop";

IF (-not (Test-Path $adksetupexe)) {
	(New-Object System.Net.WebClient).DownloadFile($adksetupurl,$adksetupexe)
}

If (-not (Test-Path -path $adkfolder -pathType container)) 
{ New-Item $adkfolder -type directory }

Write-Host "Updating wadk setup files contained in $adkfolder"
$process=Start-Process -file $adksetupexe -arg "/quiet /layout ""$adkfolder""" -passthru
$process.WaitForExit()

Do { 
Write-Host "
Please choose an option;
--------------------------
1 = Install WADK Locally
2 = Build WADK Setup ISO
3 = Exit
--------------------------"
$choice1 = read-host -prompt "Select number & press enter" } 
until ($choice1 -eq "1" -or $choice1 -eq "2" -or $choice1 -eq "3") 
Switch ($choice1) 
{ 
	"1" {

	Write-Host "Installing wadk to $wadkfolder"
	$process=Start-Process -file "$adkfolder\adksetup.exe" -arg "/quiet /installpath ""$wadkfolder""" -passthru
	$process.WaitForExit()

	} 
	"2" {

	. .\New-IsoFile.ps1

	dir "$adkfolder" | New-IsoFile -Path "$isofolder$isoname.iso" -Title "$isoname" -Force

	} 
	"3" {

	Exit

	}
}

