param(
	[String]$CustomInstallLocation
)

$ErrorActionPreference = 'Stop'

$lastMessage = 'Nothing'

# Used to keep track of game directory
$currentInstallPath = $null
$validInstallPath = $false


# Determine the install directory
$exeName = 'JustCause2.exe'
$defaultInstallDir = 'C:\Program Files (x86)\Steam\steamapps\common\Just Cause 2\'
if ((Test-Path -Path ($defaultInstallDir + $exeName)) -or (Test-Path -Path ($CustomInstallLocation + $exeName)) ) {
	$validInstallPath = $true

	# Make sure the current install path is not just a root drive, container = 'directory' or 'folder
	$currentInstallPath = (Test-Path -Path $defaultInstallDir  -PathType Container -IsValid )? $defaultInstallDir : $CustomInstallLocation
}
else {
	Write-Host 'Did not find default install directory, please specify with the -CustomInstallLocation parameter'
}

## Utility

Function Test-InstallDir {
 Write-Host 'Current game install status:'($validInstallPath ? ("found at $currentInstallPath") : 'not found :(')
}

<#
.SYNOPSIS
Gets information used to verify mods, in the case there are issues.

.DESCRIPTION
Gets the structure of the folders in the github resposity, along with file names and sizes to verify agaisnt.

.NOTES
If I change my github username or the repository name this will break
#>
Function Verify-ModIntegrity {

	$baseUri = 'https://api.github.com/repos/tadghh/Just-Cause-2-Patches/contents'
	$uri = "$baseUri?ref=main"

	$response = Invoke-RestMethod -Uri $uri -Method Get

	$folderStructure = New-Object System.Collections.ArrayList

	foreach ($folder in $response | Where-Object { $_.type -eq 'dir' }) {
		$folderName = $folder.name
		$folderUri = $folder.url

		$files = Invoke-RestMethod -Uri $folderUri -Method Get

		$folderFiles = foreach ($file in $files) {
			[PSCustomObject]@{
				FileName = $file.name
				Size     = $file.size
			}
		}

		$folderObject = [PSCustomObject]@{
			FolderName = $folderName
			Files      = $folderFiles
		}

		[void]$folderStructure.Add($folderObject)
	}

	return $folderStructure
}

<#
.SYNOPSIS
Uninstalls a mod/patch based on its install files.

.DESCRIPTION
Will gather similar folders and files found inside the passed in parameter. The files and folders will be removed
Folders wont be removed if non matching files are leftover inside, providing comptability across intersecting mods.

.PARAMETER modFolderLocation
The install directory (downloaded zip file) of the mod/patch

.EXAMPLE
Uninstall-FromDropzone ".\Mods\Better Blood"

#>
Function Uninstall-FromDropzone {
	param(
		[string]$modFolderLocation
	)

	$dropZonePath = $currentInstallPath + '\dropzone'
	if (Test-Path -Path $dropZonePath) {
		$filesToRemove = Get-ChildItem -Path $modFolderLocation -Recurse
		$dropzoneFiles = Get-ChildItem -Path $dropZonePath -Recurse

		$matchingDropzoneFiles = $dropzoneFiles | Where-Object { $_.Name -in $filesToRemove.Name -and $_.LastWriteTime -in $filesToRemove.LastWriteTime }

		foreach ($matchingFile in $matchingDropzoneFiles) {
			if ($matchingFile.PSIsContainer) {
				$childItems = Get-ChildItem -Path $matchingFile.FullName -Recurse
				if ($childItems.Count -eq 0) {
					Remove-Item $matchingFile.FullName -Force
					Write-Host "Removed folder $($matchingFile.FullName)"
				}
				else {
					Write-Host "Skipped removing non-empty folder $($matchingFile.FullName) (Might be in use from other mods/patches)"
				}
			}
			else {
				Remove-Item $matchingFile.FullName -Force
				Write-Host "Removed file $($matchingFile.FullName)"
			}
		}
	}
	else {
		Write-Host 'Dropzone folder not found in JC2 Root directory.'
	}
}

<#
.SYNOPSIS
Files and folders in contained in $modFolderLocation are copied into the dropzone folder

.DESCRIPTION
Files and folders in contained in $modFolderLocation are copied into the dropzone folder.
If the dropzone folder doesnt exist it will be created and the function will recall itself.

.PARAMETER modFolderLocation
The mods folder

.EXAMPLE
An example Install-IntoDropzone ".\Mods\Better Blood"

#>
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

Function Install-GameCompletionPatch {
	$gameCompletionPatches = $PSScriptRoot + '\Patches\Completion'
	if (Test-Path -Path $gameCompletionPatches -and Test-Path -Path $currentInstallPath+"\archives_win32") {
		Copy-Item $gameCompletionPatches\* $currentInstallPath"\archives_32" -Recurse
		Write-Host 'Copied patch files'
	}
	else {
		Write-Host 'Could not find local patches folder or JC2 archives_32 directory'
	}
}

Function Install-BullseyeRiflePatch {
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
Function Install-DXVK {
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

Function Install-Patches {
	Install-BullseyeRiflePatch
	Install-DXVK
	Install-GameCompletionPatch
	Install-LandscapeTextures
	Install-MouseFix
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

Function Uninstall-DVXK {
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

Function Uninstall-Patches {
	Uninstall-MouseFix
	Uninstall-Bullseye
	Uninstall-GameCompletionPatch
	Uninstall-DVXK
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

Function Install-Wildlife {
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

Function Install-CutsceneBMSkip {
	if (Test-Path -Path $CustomInstallLocation+"\dropzone\serviceMods") {
		Write-Host 'Rebalanced Black Market skip is installed. Skipping.'
	}
	else {
		Install-IntoDropzone $PSScriptRoot + '\Mods\No Blackmarket Cutscene'
	}
}

Function Install-SkyRetexture {
	Install-IntoDropzone "$PSScriptRoot\Mods\Realistic Skys"
}

## Launch functions

# only enable decals when dxck
# User needs to add these to steam or launch with a shortcut/ Justcause.exe /commands here
$userLaunchParameters = @{
	decals       = 1
	dxadapter    = 0
	FilmGrain    = 1
	fovfactor    = 1.0
	frameratecap = 60
	LODFactor    = 1
	VSync        = 0
}


function Set-FilmGrain {
	$userLaunchParameters.FilmGrain = ($userLaunchParameters.FilmGrain -eq 1) ? 0 : 1
}


function Set-Decals {
	$userLaunchParameters.decals = ($userLaunchParameters.decals -eq 1) ? 0 : 1
}

function Set-LODFactor {
	do {
		Write-Host 'Please enter a number between 0 - 3 (closest, furthest), or "q" to quit:'

		# Prompt the user for input
		$input = Read-Host 'Enter LOD'

		if ($input -eq 'q') { return }

		# Validate input
		if ($input -match '^\d+$' -and $input -ge 0 -and $input -le 3) {
			$userLaunchParameters.LODFactor = [int]$input
			Write-Host "LOD Factor set to $($userLaunchParameters.LODFactor)"
			return
		}
		else {
			# If input is invalid, display an error message and continue the loop
			Write-Host "Invalid input. Please enter a number between 0 and 3, or 'q' to quit."
		}
	} while ($true)
}

function Set-FOV {
	do {
		Write-Host 'Please enter a number between 1 - 2 (this translates to 100-200, ex 1.1 = 110), or "q" to quit:'

		# Prompt the user for input
		$input = Read-Host 'Enter FOV'

		if ($input -eq 'q') { return }

		# Validate input
		if ($input -match '^\d+(\.\d+)?$' -and $input -ge 1 -and $input -le 2) {
			$userLaunchParameters.fovfactor = [float]$input
			Write-Host "FOV set to $($userLaunchParameters.FOV * 100)"
			return
		}
		else {
			# If input is invalid, display an error message and continue the loop
			Write-Host "Invalid input. Please enter a number between 1 and 2, or 'q' to quit."
		}
	} while ($true)
}

Function Show-LaunchOptions {
	Clear-Host
	Write-Host 'Copy and paste the following as launch paramters in Steam or others.'
	Write-Host 'Steam -> Just Cause 2 -> Properties -> General -> Launch Options'`n

	foreach ($key in $userLaunchParameters.Keys) {
		Write-Host "/$key=$($userLaunchParameters[$key]) " -NoNewline
	}
	Write-Host `n
	Pause
}
## Menus
Function Show-Menu {
	param (
		[array]$MenuItems,
		[string]$MenuTitle = 'Menu'
	)

	# Build menu output
	$menuOutput = "================ $MenuTitle ================`n"
	foreach ($menuItem in $MenuItems) {
		$index = $MenuItems.IndexOf($menuItem) + 1
		$menuOutput += "${index}: $($menuItem.Title)`n"
	}
	$menuOutput += "Press 'Q' to quit.`n"

	# Clear host and display menu output
	Clear-Host
	Write-Host $menuOutput
}

Function Show-CurrentLaunchOptionsStatus {
	Write-Host 'Current launch settings:'
	$maxKeyLength = ($userLaunchParameters.Keys | Measure-Object -Property Length -Maximum).Maximum

	foreach ($key in $userLaunchParameters.Keys) {

		Write-Host "$key " -NoNewline
	}

	# Move to new line
	Write-Host
	$index = 0
	foreach ($entry in $userLaunchParameters.GetEnumerator()) {
		$index++
		$paddingTotal = $entry.Key.ToString().Length - 1
		$padding = ' ' * ($paddingTotal)
		Write-Host $entry.Value$padding -NoNewline
	}
	# Move to new line
	Write-Host
}
Function Select-MenuOption {
	param (
		[array]$MenuItems,
		[string]$MenuTitle = 'Menu'
	)

	$isFocused = $true
	$index = 0
	do {
		Show-Menu -MenuItems $MenuItems -MenuTitle $MenuTitle

		# TODO: No hardcoding
		if ($MenuTitle -eq 'Launch Parameters') {
			Show-CurrentLaunchOptionsStatus
		}

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

## Menu items

$launchItems = @(
	@{ Title = 'Enable/Disable decals'; Action = { Set-Decals } },
	@{ Title = 'Enable/Disable filmgrain'; Action = { Set-FilmGrain } },
	@{ Title = 'Set LOD Factor'; Action = { Set-LODFactor } },
	@{ Title = 'Set FOV'; Action = { Set-FOV } },
	@{ Title = 'Show Launch Options'; Action = { Show-LaunchOptions } },
	@{ Title = 'Main menu.'; Action = { Select-MenuOption -MenuItems $mainMenuItems } }
)

$patchMenuItems = @(

	@{ Title = 'Apply all.'; Action = { Install-Patches } },
	@{ Title = 'Apply Stability fixes (DXVK).'; Action = { Install-DXVK } },
	@{ Title = 'Apply Mouse Fix.'; Action = { Install-MouseFix } },
	@{ Title = 'Apply 100% Completion Patch.'; Action = { Install-GameCompletionPatch } },
	@{ Title = 'Apply Bullseye Rifle Patch.'; Action = { Install-BullseyeRiflePatch } },
	@{ Title = 'Apply Landscape Texture Patch.'; Action = { Install-LandscapeTextures } },
	@{ Title = 'Uninstall Bullseye Rifle fix.'; Action = { Uninstall-Bullseye } },
	@{ Title = 'Uninstall Stability fixes (DXVK).'; Action = { Uninstall-DVXK } },
	@{ Title = 'Uninstall Mouse Fix.'; Action = { Uninstall-MouseFix } },
	@{ Title = 'Uninstall 100% Completion Patch.'; Action = { Uninstall-GameCompletionPatch } },
	@{ Title = 'Main menu.'; Action = { Select-MenuOption -MenuItems $mainMenuItems } }
)


$modMenuItems = @(
	@{ Title = 'Apply Better Traffic.'; Action = { Install-BetterTraffic } },
	@{ Title = 'Apply More Wildlife.'; Action = { Install-Wildlife } },
	@{ Title = 'Apply Sky Retexture'; Action = { Install-SkyRetexture } },
	@{ Title = 'Apply Black Market Cutscene skip.'; Action = { Install-CutsceneBMSkip } },
	@{ Title = 'Apply Rebalanced Overhaul'; Action = { Install-RebalancedMod } },
	@{ Title = 'Main menu.'; Action = { Select-MenuOption -MenuItems $mainMenuItems } }
)

$mainMenuItems = @(
	@{ Title = 'Open patch menu.'; Action = { Select-MenuOption -MenuItems $patchMenuItems -MenuTitle 'Patches' } },
	@{ Title = 'Open mod menu.'; Action = { Select-MenuOption -MenuItems $modMenuItems -MenuTitle 'Mods' } },
	@{ Title = 'Open launch parameter menu.'; Action = { Select-MenuOption -MenuItems $launchItems -MenuTitle 'Launch Parameters' } }

)

if ($validInstallPath) {
	Select-MenuOption -MenuItems $mainMenuItems -MenuTitle 'Main Menu'
}
else {
	Write-Host 'Menu not opened, JC2 install directory not found.'
}
