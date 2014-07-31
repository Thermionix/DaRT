
$ErrorActionPreference = "Stop"
$scriptRoot=Resolve-Path "."

$wsusoffline_zip="wsusoffline931.zip"
$wsusoffline_url="http://download.wsusoffline.net/$wsusoffline_zip"
$wsusoffline_dir="$scriptRoot\wsusoffline"
$wsusoffline_bin="$wsusoffline_dir\UpdateGenerator.exe"
$wsusoffline_cmd="$wsusoffline_dir\cmd\DownloadUpdates.cmd"

$geteltorito_url="http://www.ltr-data.se/files/geteltorito.zip"
$geteltorito_bin="$scriptRoot\geteltorito.exe"

$imdisk_url="http://www.ltr-data.se/files/imdiskinst.exe"

$mkisofs_url="http://smithii.com/files/cdrtools-latest.zip"
$mkisofs_bin="$scriptRoot\cdrtools-latest\mkisofs.exe"

$x64_image=$true
$win_iso_filename="en_windows_7_enterprise_n_with_sp1_x64_dvd_u_677704.iso"

if ($x64_image) { $wsus_target="w61-x64" } else { $wsus_target="w61" }

$ignored_kbs=@("KB2506143","KB2533552","KB2819745")

$kb_dir=Resolve-Path "$wsusoffline_dir\client\$wsus_target\glb"
$dism_temp="$scriptRoot\dismmount"
$src_temp="$scriptRoot\src"
$sources_temp="$src_temp\sources"
$wim_temp="$sources_temp\install.wim"
$bootbin_filename="boot.bin"
$bootbin_path="$src_temp\$bootbin_filename"

# check powershell version
# check admin priveleges

function Download-Extract($url)
{
	#  $wc = New-Object System.Net.WebClient
	#  $wc.DownloadFile($source, $destination)
	
	# unzip
}

function Test-WsusOfflineBin
{
	IF (-not (Test-Path $wsusoffline_bin)) {
		
		# pull $wsusoffline_url
		# unzip $wsusoffline_zip into $wsusoffline_dir
		throw "$wsusoffline_bin not found!"
	}
}

function Test-WinIsoExists
{
	IF (-not (Test-Path $win_iso_filename)) 
	{ 
		throw "$win_iso_filename not found!" 
	}
}

function Test-ImDisk
{
	Write-Host "Checking imdisk installed"
	if ( -not (Get-Command ImDisk -errorAction SilentlyContinue)) { 
		Write-Host "Installing imdisk" -Fore Yellow

		$imdiskinst="imdiskinst.exe"
		
		# Test $imdiskinst
		# else wget

		$env:IMDISK_SILENT_SETUP = 1
		
		$process=Start-Process -file $imdiskinst -arg "-y" -passthru
		$process.WaitForExit()
		
		#throw "failed to install ImDisk"
	}
}

function Test-geteltorito
{
	#$geteltorito_url
}

function Test-mkisofs
{

}

function Mount-Iso([string] $isoPath)
{
	Write-Host "Mount-Iso called with $isoPath"
	if ( -not (Test-Path $isoPath)) { throw "$isoPath does not exist" }
	
	$driveLetter = ls function:[i-z]: -n | ?{ !(test-path $_) } | random
	Write-Host "Mounting $isoPath using ImDisk"
	(& "imdisk" -a -f $isoPath -m $driveLetter -o rw) | out-null
	Start-Sleep -s 7
	return ($driveLetter+"\")
}

function Dismount-Iso([string] $driveLetter)
{
	Write-Host "Unmounting $driveLetter using ImDisk"
	Start-Sleep -s 4
	(& "imdisk" -D -m ($driveLetter.Replace("\",""))) | out-null
}

function Select-WimIndex
{
	& dism /get-wiminfo /wimfile:$wim_temp | Out-Host
	# capture output, if 'index :' -count -gt 1
	return (Read-Host "Please enter an index from the list to update")
	# else return 1
}

function Update-WimImage
{
	IF(-not (Test-Path -path $dism_temp))
	{
		New-Item -ItemType Directory -Force -Path $dism_temp
	}
	
	IF(-not (Test-Path -path $wim_temp))
	{
		throw "Missing $wim_temp"
	}

	Write-Host "Updating $wim_temp"

	Set-ItemProperty $wim_temp -name IsReadOnly -value $false

	$index=Select-WimIndex
	& dism /mount-wim /wimfile:$wim_temp /mountdir:$dism_temp /index:$index
	& dism /image:$dism_temp /Add-Package /PackagePath:$kb_dir
	& dism /unmount-wim /mountdir:$dism_temp /commit
	
	Set-ItemProperty $wim_temp -name IsReadOnly -value $true
}

function Remove-IgnoredKbs
{
	Get-ChildItem $kb_dir | where { 
	$_.Name -Match ($ignored_kbs -join "|") } | foreach {
		Write-Host "Removing ignored update $($_.Name)"
		$kbfile=Join-Path $kb_dir $_.Name
		if (Test-Path $kbfile -PathType Leaf) { rm $kbfile }
	}
}

function Download-WsusUpdates
{
	Write-Host "Getting updates for $wsus_target"
	$process=Start-Process -FilePath $wsusoffline_cmd -ArgumentList "$wsus_target glb" -passthru -Wait
	$process.WaitForExit()
}

function Update-WsusOffline
{
	Write-Host "Updating WsusOfflineUpdater"
	# & UpdateOU.cmd
}

function Extract-BootBin
{
	& $geteltorito_bin $win_iso_filename | Out-File $bootbin_path
}

function Build-UpdatedIso
{
	# dd if=../en_windows_7_enterprise_x64_dvd_x15-70749.iso of=boot.img bs=2048 count=8 skip=734
	# ..\bin\mkisofs.exe -iso-level 4 -udf -exclude-list %ISO_FILTER% -output %OUTPUT_PATH%\%ISO_NAME%.iso -volid %ISO_VOLID% ..\client
	# $mkisofs_bin -udf -v -no-emul-boot -b $mountPath\boot.bin -c $mountPath\boot.catalog -o test.iso -M E:\ /sources/=C:\source\win7iso\install.wim
	# mkisofs -iso-level 4 -l -d -D -J -joliet-long -b boot.bin -hide boot.bin -hide boot.catalog -allow-multidot -no-emul-boot -volid "XPCD" -A MKISOFS -sysid "Win32" -boot-load-size 4 -o "M:\Winlite.iso" "M:\source"
	# "/sources/=C:\source\win7iso\install.wim"
	# mkisofs -udf -v -b boot/etfsboot.com -no-emul-boot -hide boot.bin -hide boot.catalog -o new.iso X17-59186
	#"-graft-points",
	#"-c",(Join-Path $mountPath "boot.catalog"),	

	# $latestkb = 
	# get latest file in $kb_dir
	# kb(d\+)
	# = 2957689
	
	# $new_iso_filename=
	# $win_iso_filename strip extension
	# strip u_(d\+_)
	# add u_$latestkb
	
	$new_iso_filename="en_windows_7_enterprise_n_with_sp1_x64_dvd_u_2957689.iso"

	## TODO : test New-IsoFile.ps1	

	IF (Test-Path $new_iso_filename) { Remove-Item $new_iso_filename }
	
	$mkisofs_args=@("-udf",
		"-v",
		"-b",$bootbin_filename,
		"-iso-level","4",
		"-no-emul-boot",
		"-hide",$bootbin_filename,
		"-hide","boot.catalog",
		"-o",$new_iso_filename,
		$src_temp)
		
	$process=Start-Process -FilePath $mkisofs_bin -ArgumentList $mkisofs_args -passthru -Wait
	$process.WaitForExit()
}

function Copy-IsoContents
{
	IF (Test-Path $src_temp) 
	{ 
		Remove-Item $src_temp -Recurse -Force
	}
	
	if (Test-Path (Join-Path $mountPath "sources\install.wim")) 
	{
		Copy-Item $mountPath "$src_temp\" -Recurse
	}
}

Test-WinIsoExists

Test-WsusOfflineBin

Test-mkisofs

Test-ImDisk

Test-geteltorito

Download-WsusUpdates

Remove-IgnoredKbs

try
{
	$mountPath = Mount-Iso $win_iso_filename

	Copy-IsoContents
}
finally 
{ 
	Dismount-Iso $mountPath 
}

Extract-BootBin

Update-WimImage

Build-UpdatedIso

