#requires -version 3.0

$ErrorActionPreference = "Stop"
$scriptRoot=Resolve-Path "."

$wsusoffline_zip="wsusoffline97.zip"
$wsusoffline_url="http://download.wsusoffline.net/$wsusoffline_zip"
$wsusoffline_dir="$scriptRoot\wsusoffline"
$wsusoffline_bin="$wsusoffline_dir\UpdateGenerator.exe"
$wsusoffline_cmd="$wsusoffline_dir\cmd\DownloadUpdates.cmd"
$wsusoffline_up="$wsusoffline_dir\cmd\UpdateOU.cmd"

$imdisk_url="http://www.ltr-data.se/files/imdiskinst.exe"

$x64_image=$true
$win_iso_filename="en_windows_7_enterprise_n_with_sp1_x64_dvd_u_677704.iso"
# TODO : detect from target iso?
if ($x64_image) { $wsus_target="w61-x64" } else { $wsus_target="w61" }

$buildDate=(Get-Date).ToString("yyyyMMdd") # -HHmmss.ffff
$new_iso_filename="en_windows_7_enterprise_n_with_sp1_x64_dvd_$buildDate.iso"

$kb_dir=(Join-Path $wsusoffline_dir "\client\$wsus_target\glb")
$dism_temp="$scriptRoot\dismmount"
$src_temp="$scriptRoot\src"
$sources_temp="$src_temp\sources"
$wim_temp="$sources_temp\install.wim"
$etfsboot=(Join-Path $src_temp "boot\etfsboot.com")

# TODO : check admin priveleges

function Download-Extract($url,[bool]$createSubdir = $false)
{
	$filename = [System.IO.Path]::GetFileName($url)
	$file = [System.IO.Path]::Combine($pwd.Path, $filename)
	Write-Host "Downloading $filename from $url"
	
	(New-Object System.Net.WebClient).DownloadFile($url,$file)

	$targetFolder = $scriptRoot
	if ($createSubdir) {
	$folderName = [System.IO.Path]::GetFileNameWithoutExtension($filename)
	$targetFolder = (Join-Path $scriptRoot $folderName) }
	
	[System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')
	[System.IO.Compression.ZipFile]::ExtractToDirectory($file, $targetFolder)
}

function Test-WsusOfflineBin
{
	IF (-not (Test-Path $wsusoffline_bin)) 
	{
		Download-Extract $wsusoffline_url
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
		
		(New-Object System.Net.WebClient).DownloadFile($imdisk_url,$imdiskinst)
		
		$env:IMDISK_SILENT_SETUP = 1
		
		$process=Start-Process -file $imdiskinst -arg "-y" -passthru
		$process.WaitForExit()
	}
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
	$indexOutput = & dism /get-wiminfo /wimfile:$wim_temp
	$indexCount = ($indexOutput | Select-String "Index" -AllMatches).Matches.Count

	if ($indexCount -gt 1) {
		Write-Host $indexOutput
		return (Read-Host "Please enter an index from the list to update")
	} else {
		return 1
	}
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
	$ignored_kbs=@("KB2506143","KB2533552","KB2819745")
	Get-ChildItem $kb_dir | where { 
	$_.Name -Match ($ignored_kbs -join "|") } | foreach {
		Write-Host "Removing ignored update $($_.Name)"
		$kbfile=Join-Path $kb_dir $_.Name
		if (Test-Path $kbfile -PathType Leaf) { rm $kbfile }
	}
}

function Exclude-IgnoredKbs
{
Write-Output "kb2819745
kb2506143
kb2533552"| Out-File -FilePath (Join-Path $wsusoffline_dir "\exclude\custom\ExcludeList-w61-x64.txt") -Encoding "UTF8"
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
	& $wsusoffline_up
}

function Determine-LatestKB
{
	# $latestkb = 
	# get latest file in $kb_dir
	# kb(d\+)
	# = 2957689
	
	# $new_iso_filename=
	# $win_iso_filename strip extension
	# strip u_(d\+_)
	# add u_$latestkb
}

function Build-UpdatedIso
{
	. .\New-IsoFile.ps1
	echo "Building Updated ISO $new_iso_filename"
	dir $src_temp | New-IsoFile -Path "$new_iso_filename" -Title $buildDate -BootFile $etfsboot -Force
}

function Copy-IsoContents
{
	IF (Test-Path $src_temp) 
	{
		echo "Removing Previous $src_temp"
		Remove-Item $src_temp -Recurse -Force
	}
	
	if (Test-Path (Join-Path $mountPath "sources\install.wim")) 
	{
		echo "Copying $mountPath to $src_temp"
		Copy-Item $mountPath "$src_temp\" -Recurse
	}
}

Test-WinIsoExists

Test-WsusOfflineBin

Test-ImDisk

#Update-WsusOffline

Exclude-IgnoredKbs

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

Update-WimImage

Build-UpdatedIso
