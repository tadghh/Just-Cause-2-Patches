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

	# Make sure the current install path is not just a root drive, container = 'directory' or 'folder
	$currentInstallPath = (Test-Path -Path $defaultInstallDir  -PathType Container -IsValid )? $defaultInstallDir : $CustomInstallLocation
}
else {
	Write-Host 'Did not find default install directory, please specify with the -CustomInstallLocation parameter'
}

function Test-InstallDir {
 Write-Host 'Current game install status:'($validInstallPath ? ("found at $currentInstallPath") : 'not found :(')
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

Function Install-Patches {
	Apply-BullseyeRiflePatch
	Apply-GameCompletionPatch
	Apply-LandscapeTextures
	Apply-MouseFix
}

function Install-GameCompletionPatch {
	$gameCompletionPatches = $PSScriptRoot + '\Patches\Completion'
	if (Test-Path -Path $gameCompletionPatches -and Test-Path -Path $currentInstallPath+"\archives_win32") {
		Copy-Item $gameCompletionPatches\* $currentInstallPath"\archives_32" -Recurse
		Write-Host 'Copied patch files'
	}
	else {
		Write-Host 'Could not find local patches folder or JC2 archives_32 directory'
	}
}

function Install-BullseyeRiflePatch {
	$weaponPatches = $PSScriptRoot + '\Patches\Bullseye Rifle Fix'

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

	# Get the folder name created from extracting tar
	$assetName = $assetName.substring(0, $assetName.IndexOf('tar') - 1)
	if (Test-Path -Path $assetName) {
		Write-Host $assetName
		Remove-Item -Recurse $assetName\"x64"
		Remove-Item $assetName\"x32"\d3d9.dll
		Copy-Item $assetName\"x32"\* $currentInstallPath -Recurse
	}
}

Function Install-LandscapeTextures {
	$landscapeTexturePath = $PSScriptRoot + '\Patches\Landscape Textures'

	Install-IntoDropzone $landscapeTexturePath
}

Function Install-MouseFix {
	# Extract to root, force
	$mouseAimFixFiles = $PSScriptRoot + '\Patches\Mouse Aim Fix Negative Accel'
	if (Test-Path -Path $mouseAimFixFiles) {
		Copy-Item $currentInstallPath\"PathEngine.dll" $currentInstallPath\"PathEngine_orig.dll"
		Copy-Item $mouseAimFixFiles\* $currentInstallPath -Recurse
	}
}

Function Uninstall-Patches {
	Uninstall-MouseFix
	Uninstall-Bullseye
	Uninstall-GameCompletionPatch
	Uninstall-DVXK
}

Function Uninstall-MouseFix {
	# Extract to root, force
	$mouseAimFixFiles = $PSScriptRoot + '\Patches\Mouse Aim Fix Negative Accel'
	if (Test-Path -Path $currentInstallPath+"JC2MouseFix.dll") {
		Remove-Item $currentInstallPath+"JC2MouseFix.dll"
		Remove-Item $currentInstallPath+"PathEngine.dll"
		Rename-Item -Path $currentInstallPath\"PathEngine_orig.dll" -NewName ($currentInstallPath -replace '_orig', '') -Force
	}
}

Function Uninstall-GameCompletionPatch {
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

Function Uninstall-Bullseye {
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
		Write-Host 'Uninstalled Bullseye rifle fix.'
	}
	else {
		Write-Host 'Source directory or destination directory not found.'
	}
}

function Uninstall-DVXK {
	$filesToRemove = @(
		'dxgi.dll',
		'd3d11.dll',
		'd3d10core.dll'
	)

	foreach ($file in $filesToRemove) {
		$fileToRemovePath = Join-Path -Path $currentInstallPath -ChildPath $file
		if (Test-Path -Path $fileToRemovePath) {
			Remove-Item -Path $fileToRemovePath -Force
			Write-Host "Removed file: $fileToRemovePath"
		}
		else {
			Write-Host "File not found: $fileToRemovePath"
		}
	}
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

Function Install-RebalancedMod {
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

Function Install-BetterTraffic {
	Install-IntoDropzone $PSScriptRoot + '\Mods\Better Traffic'
}

function Install-Wildlife {
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

function Install-CutsceneBMSkip {
	if (Test-Path -Path $CustomInstallLocation+"\dropzone\serviceMods") {
		Write-Host 'Rebalanced Black Market skip is still installed. Skipping.'
	}
	else {
		Install-IntoDropzone $PSScriptRoot + '\Mods\No Blackmarket Cutscene'
	}
}
Function Install-SkyRetexture {
	Install-IntoDropzone "$PSScriptRoot\Mods\Realistic Skys"
}

function Show-Menu {
	param (
		[array]$MenuItems
	)

	Clear-Host
	Write-Host '================ Menu ================'

	foreach ($menuItem in $MenuItems) {
		$index = $MenuItems.IndexOf($menuItem) + 1
		Write-Host "${index}: $($menuItem['Title'])"
	}

	Write-Host "Press 'Q' to quit."
}

function Select-MenuOption {
	param (
		[array]$MenuItems
	)

	$isFocused = $true
	$index = 0
	do {
		Show-Menu -MenuItems $MenuItems
		$selection = Read-Host 'Please make a selection'

		if (($selection -eq 'q') ) { break }

		$index = [int]$selection - 1

		if ($index -ge 0 -and $index -lt $MenuItems.Count) {
			if ($MenuItems[$index].title -eq 'Main menu.') {
				$isFocused = $false
			}
			else {
				& $MenuItems[$index].Action
			}
		}
		else {
			Write-Host 'Invalid selection. Please select a valid option.'
			Start-Sleep -Seconds 2
		}
	} until (!$isFocused)

	# fallout of loop for menus, still gotta call the action. Akin to a "trust fall"
	if (!$isFocused) {
		$MenuItems[$index].Action
	}

}

#
$patchMenuItems = @(
	@{ Title = 'Apply all.'; Action = { Install-Patches } },
	@{ Title = 'Apply Stability fixes (DXVK).'; Action = { Get-DXVK } },
	@{ Title = 'Apply Mouse Fix.'; Action = { Install-MouseFix } },
	@{ Title = 'Apply 100% Completion Patch.'; Action = { Install-GameCompletionPatch } },
	@{ Title = 'Apply Bullseye Rifle Patch.'; Action = { Install-BullseyeRiflePatch } },
	@{ Title = 'Uninstall Bullseye Rifle fix.'; Action = { Uninstall-Bullseye } },
	@{ Title = 'Uninstall Stability fixes (DXVK).'; Action = { Uninstall-DVXK } },
	@{ Title = 'Uninstall Mouse Fix.'; Action = { Uninstall-MouseFix } },
	@{ Title = 'Uninstall 100% Completion Patch.'; Action = { Uninstall-GameCompletionPatch } },
	@{ Title = 'Main menu.'; Action = { Select-MenuOption -MenuItems $mainMenuItems } }
)
#
$mainMenuItems = @(
	@{ Title = 'Open patch menu.'; Action = { Select-MenuOption -MenuItems $patchMenuItems } },
	@{ Title = 'Open mod menu.'; Action = { Write-Host 'I thinky this should be doing something' } }

)

# Call the function with the patch menu items
Select-MenuOption -MenuItems $mainMenuItems