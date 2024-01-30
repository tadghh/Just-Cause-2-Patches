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

# only enable decals when dxck
# User needs to add these to steam or launch with a a shortcut/ Justcause.exe /commands here
$userLaunchParameters = @{
	LODFactor    = 1
	VSync        = 0
	frameratecap = 60
	dxadapter    = 0
	FilmGrain    = 0
	fovfactor    = 1.0
	decals       = 0
}

# TODO:
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

Function Revert-Patches() {

	Revert-Bullseye
}

Function Revert-100PFix {
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
}

Function Revert-Bullseye {
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

# Bokeh filter and GPU water simulation effects will become unavailable.
# This should allow the "Decals" option to be enabled without crashes and overall makes the game less prone to crashing.
Function Get-DXVK {
	$latestReleaseApiUrl = 'https://api.github.com/repos/doitsujin/dxvk/releases/latest'
	$latestRelease = Invoke-RestMethod -Uri $latestReleaseApiUrl
	$tagName = $latestRelease.tag_name

	# Releases have other similar filtypes so we need to filter those out
	# Regex is slow so we look for filenames that dont include the word "native" aka nat.
	$asset = $latestRelease.assets | Where-Object { $_.name -like '*.tar.gz' -and $_.name -notlike '*-nat*' }

	# Constructing the URL of the asset
	$assetUrl = $asset.browser_download_url

	# Extracting the asset name from the URL
	$assetName = $assetUrl -split '/' | Select-Object -Last 1

	# Downloading the asset
	Invoke-WebRequest -Uri $assetUrl -OutFile $assetName

	# Create a directory to extract to
	$dxvkFolder = $PSScriptRoot + '\' + $assetName
	# Extracting the archive (tar.gz) using tar
	tar -xvzf $assetName
	if (Test-Path -Path $dxvkFolder) {
		Remove-Item $dxvkFolder\d3d9.dll
		Copy-Item $dxvkFolder\* $currentInstallPath -Recurse
		Write-Host 'Copied dxvk  files'
	}
}

Function Apply-MouseFix {
	# Extract to root, force
	$mouseAimFixFiles = $PSScriptRoot + '\Patches\Mouse Aim Fix Negative Accel'
	if (Test-Path -Path $mouseAimFixFiles) {
		Copy-Item $currentInstallPath\"PathEngine.dll" $currentInstallPath\"PathEngine.dll.bak"
		Copy-Item $mouseAimFixFiles\* $currentInstallPath -Recurse
		<# Action to perform if the condition is true #>
	}
}

Function Revert-MouseFix {
	# Extract to root, force
	$mouseAimFixFiles = $PSScriptRoot + '\Patches\Mouse Aim Fix Negative Accel'
	if (Test-Path -Path $currentInstallPath+"JC2MouseFix.dll") {
		Remove-Item $currentInstallPath+"JC2MouseFix.dll"
		Remove-Item $currentInstallPath+"PathEngine.dll"
		Rename-Item -Path $currentInstallPath\"PathEngine.dll.bak" -NewName ($currentInstallPath -replace '\.bak$', '')
	}
}

Function Apply-LandscapeTextures {
	$landscapeTexturePath = $PSScriptRoot + '\Patches\Landscape Textures'

	if ( Test-Path -Path $currentInstallPath"\dropzone") {
		Copy-Item $landscapeTexturePath\* $currentInstallPath"\dropzone" -Recurse
		Write-Host 'Copied patch files'
	}
	else {
		New-Item -ItemType 'directory' -Path $currentInstallPath+"\dropzone"
		if (-not $tripped) {
			$tripped = true
			Apply-LandscapeTextures
		}
	}
}

### Mods

Function Apply-RebalancedMod {

}

Function Apply-BetterTraffic {

}

function Apply-Wildlife {

}

function Apply-CutsceneBMSkip {
 # Disable if Rebalenced mod is active
}

Function Apply-SkyRetexture {

}



##### Unused

# The launch parameter can be used instead
# function Remove-Filmgrain {
# 	# Check for dropzone folder
# 	$filmgrainPatch = $PSScriptRoot + '\Patches\Filmgrain'
# 	if (!Test-Path -Path $currentInstallPath+"\dropzone" ) {
# 		New-Item -ItemType 'directory' -Path $currentInstallPath+"\dropzone"
# 		Write-Host 'Created dropzone folder'
# 	}
# 	if (Test-Path -Path $currentInstallPath+"\dropzone" ) {

# 		Copy-Item $filmgrainPatch\"filmgrain.dds" $$currentInstallPath+"\dropzone" -Force
# 		Write-Host 'Applied Filmgrain removal patch'
# 	}

# }
# function Reapply-Filmgrain {
# 	# Check for dropzone folder
# 	if (Test-Path -Path $currentInstallPath+"\dropzone\filmgrain.dds" ) {
# 		Remove-Item $currentInstallPath+"\dropzone\filmgrain.dds" -Force
# 		Write-Host 'Applied Filmgrain removal patch'
# 	}
# }