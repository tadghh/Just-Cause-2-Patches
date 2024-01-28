# Find install path
param(
	[String]$CustomInstallLocation
)

$ErrorActionPreference = 'Stop'

# Used to keep track of directory
$currentInstallPath = $null
$validInstallPath = $false

$exeName = 'JustCause2.exe'

# Default install directory
$defaultInstallDir = 'C:\Program Files (x86)\Steam\steamapps\common\Just Cause 2\'
if (Test-Path -Path ($defaultInstallDir + $exeName) -or Test-Path -Path ($CustomInstallLocation + $exeName) ) {
	$validInstallPath = $true

	$currentInstallPath = Test-Path -Path $defaultInstallDir ? $defaultInstallDir : $CustomInstallLocation
}
else {
	Write-Host 'Did not find default install directory, please specify with the -CustomInstallLocation parameter'
}

Function Apply-Patches() {

	$gameCompletionPatches = $PSScriptRoot + '\Patches\Completion'
	$weaponPatches = $PSScriptRoot + '\Patches\Bullseye Rifle Fix'
	if (Test-Path -Path $gameCompletionPatches -and Test-Path -Path $currentInstallPath+"\archives_win32") {
		Copy-Item $gameCompletionPatches\* $currentInstallPath"\archives_32" -Recurse
		Write-Host 'Copied patch files'
	}
	else {
		Write-Host 'Could not find local patches folder or JC2 archives_32 directory'
	}
	# Bullseye Rifle
	if (Test-Path -Path $weaponPatches -and Test-Path -Path $currentInstallPath+"\DLC") {
		$sourceFiles = Get-ChildItem -Path $weaponPatches -File -Recurse

		foreach ($file in $sourceFiles) {
			$destinationFile = Join-Path -Path $currentInstallPath"\DLC" -ChildPath $file.Name

			if (Test-Path -Path $destinationFile) {
				$backupFile = $destinationFile + '.bak'
				Copy-Item -Path $destinationFile -Destination $backupFile -Force
   }

			Copy-Item -Path $file.FullName -Destination $destinationFile -Force
		}

		Write-Host 'Patch files copied with backups.'
	}
	else {
		Write-Host 'Source directory or destination directory not found.'
	}

}
function Remove-Filmgrain {
	# Check for dropzone folder
	$filmgrainPatch = $PSScriptRoot + '\Patches\Filmgrain'
	if (!Test-Path -Path $currentInstallPath+"\dropzone" ) {
		New-Item -ItemType 'directory' -Path $currentInstallPath+"\dropzone"
		Write-Host 'Created dropzone folder'
	}
	if (Test-Path -Path $currentInstallPath+"\dropzone" ) {

		Copy-Item $filmgrainPatch\"filmgrain.dds" $currentInstallPath -Force

	}

}

function Revert-Patches() {
	$filesToRemove = @(
		'x_Jusupov_100percent',
		'x_worldbin'
	)
	if (Test-Path -Path $currentInstallPath+"\archives_win32") {
		foreach ($file in $filesToRemove) {
			$fileToRemovePath = Join-Path -Path $currentInstallPath -ChildPath "archives_win32\$file"
			if (Test-Path -Path $fileToRemovePath) {
				Remove-Item -Path $fileToRemovePath -Force
				Write-Host "Removed file: $fileToRemovePath"
			}
			else {
				Write-Host "File not found: $fileToRemovePath"
			}
		}
		Write-Host 'Patch files removed.'
	}
	else {
		Write-Host 'The directory archives_win32 does not exist.'
	}
	# unfix bullseye rifle
	if (Test-Path -Path $weaponPatches -and Test-Path -Path $currentInstallPath+"\DLC") {
		$sourceFiles = Get-ChildItem -Path $weaponPatches -File -Recurse
		foreach ($file in $sourceFiles) {
			$destinationFile = Join-Path -Path $currentInstallPath"\DLC" -ChildPath $file.Name
			if (Test-Path -Path $destinationFile+ '.bak') {
				Rename-Item -Path $destinationFile -NewName ($destinationFile -replace '\.bak$', '')
				Write-Host "Backup restored for $($file.Name)"
			}
		}
		Write-Host 'Reverted Bullseye rifle fix.'
	}
	else {
		Write-Host 'Source directory or destination directory not found.'
	}
}

# Delete directx folder

# /FramerateCap=enabled
# /RefreshRate=N
# Stability changes
# # Disable dualcore optimiations for async10
# Download Nvidia Profile Inspector.
# From the Profiles drop-down menu, select "Just Cause 2" profile.
# Click on "Show unknown settings from NVIDIA predefined profiles".
# Find option "ASYNC10_ENABLE" (Under "8 - Extra" section).
# Set it to "0x53850673 OFF - Disable dual core optimizations".
# Click on "Apply changes"

# This should allow the "Decals" option to be enabled without crashes.
# Significantly impacts performance, recommended only on faster machines.
# Check install locations

#
# Download dxvk-"version number".tar.gz.
# Extract dxgi.dll d3d11.dll and d3d10core.dll to the game installation folder.

# This should allow the "Decals" option to be enabled without crashes and overall makes the game less prone to crashing.

# Bokeh filter and GPU water simulation effects will become unavailable.


# #Remove file grain
# Use mod

#     Download No More Filmgrain!.
#     Create dropzone folder into <path-to-game>.
#     Extract and place filmgrain.dss into dropzone folder.
function Disable-FilmGrain {

	# test dlc folder
	# Check for pc_00.arc and pc_00.tab
	if (Test-Path -Path $PWD+"\Patches" -and Test-Path -Path $currentInstallPath+"\DLC") {
		Copy-Item .\Patches\* $currentInstallPath"\archives_32" -Recurse
		Write-Host 'Copied patch files'
	}
	else {
		Write-Host 'Could not find local patches folder or JC2 archives_32 directory'
	}
}