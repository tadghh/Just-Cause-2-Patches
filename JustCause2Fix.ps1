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
if ((Test-Path -Path ($defaultInstallDir + $exeName)) -or (Test-Path -Path ($CustomInstallLocation + $exeName)) ) {
	$validInstallPath = $true

	$currentInstallPath = (Test-Path -Path $defaultInstallDir )? $defaultInstallDir : $CustomInstallLocation
}
else {
	Write-Host 'Did not find default install directory, please specify with the -CustomInstallLocation parameter'
}

function Show-MainMenu {
	param (
		[string]$Title = 'Main'
	)
	Clear-Host
	Write-Host "================ $Title ================"

	Write-Host '1: View patches.'
	Write-Host '2: View mods.'
	Write-Host "Press 'Q' to quit."
}

function Main-Menu {
	do {
		Show-Menu
		$selection = Read-Host 'Please make a selection'
		switch ($selection) {
			'1' {
				Show-MainMenu
			} '2' {
				'You chose option #2'
			} '3' {
				'You chose option #3'
			}
		}

	}
	until ($selection -eq 'q')
}

# only enable decals when dxck
# User needs to add these to steam or launch with a shortcut/ Justcause.exe /commands here
$userLaunchParameters = @{
	LODFactor    = 1
	VSync        = 0
	frameratecap = 60
	dxadapter    = 0
	FilmGrain    = 0
	fovfactor    = 1.0
	decals       = 0
}

Function Apply-Patches {

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

Function Revert-Patches {

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

	Install-IntoDropzone $landscapeTexturePath
}


function Show-PatchMenu {
	Clear-Host
	Write-Host '================ Patches ================'

	Write-Host '1: Apply all.'
	Write-Host '2: Revert 100 percent compilation.'
	Write-Host '3: Revert Bullseye Rifle fix.'
	Write-Host '4: Main menu.'
	Write-Host "Press 'Q' to quit."
}

function Patch-Menu {
	do {
		Show-PatchMenu
		$selection = Read-Host 'Please make a selection'
		switch ($selection) {
			'1' {
				Apply-Patches
			} '2' {
				'You chose option #2'
			} '4' {
				Show-Menu
			}
		}

	}
	until ($selection -eq 'q')
}

Function Install-IntoDropzone {
	param(
		[string]$modFolderLocation
	)

	# A very clear statement for handling the recursive tripped variable
	if (-not (Get-Variable -Name 'tripped' -Scope 1)) {
		$tripped = $false
	}

	$dropZonePath = $currentInstallPath + '\dropzone'
	if ( Test-Path -Path $dropZonePath) {
		Copy-Item $modFolderLocation\* $dropZonePath -Recurse
		Write-Host 'Copied files'
	}
	else {
		New-Item -ItemType 'directory' -Path $dropZonePath

		# Lets not end up in an infinte loop, its not that deep brah
		if (-not $tripped) {
			$tripped = true
			Install-IntoDropzone -modFolderLocation
		}
	}
}
### Mods

Function Apply-RebalancedMod {
	$filesToRemove = @(
		'gen_ext_a.seq',
		'gen_ext_b.seq',
		'gen_ext_c.seq',
		'gen_ext_d.seq',
		'gen_ext_seq.seq'
	)
	Write-Host 'Removing Black market cutscene skip, Rebalanced has its own implementation'
	$dropZonePath = $currentInstallPath + '\dropzone'

	foreach ($file in $filesToRemove) {
		$filePath = Join-Path -Path $dropZonePath -ChildPath $file
		if (Test-Path -Path $filePath) {
			Remove-Item -Path $filePath -Force
			Write-Host "Removed file $file from dropzone"
		}
	}

	Install-IntoDropzone $PSScriptRoot + '\Mods\Rebalanced'
}

Function Apply-BetterTraffic {
	Install-IntoDropzone $PSScriptRoot + '\Mods\Better Traffic'
}

function Apply-Wildlife {
	param(
		[int]$amount
	)
	$response = switch ($amount) {
		2 { 'medium' }
		3 { 'high' }
		4 { 'very high' }
		default { 'low' }
	}
	Install-IntoDropzone "$PSScriptRoot\Mods\More Wildlife\$response"
}

function Apply-CutsceneBMSkip {
	if (Test-Path -Path $CustomInstallLocation+"\dropzone\serviceMods") {
		Write-Host 'Rebalanced Black Market skip is still installed. Skipping.'
	}
	else {
		Install-IntoDropzone $PSScriptRoot + '\Mods\No Blackmarket Cutscene'
	}
}

Function Apply-SkyRetexture {
	Install-IntoDropzone "$PSScriptRoot\Mods\Realistic Skys"
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