This PowerShell script was created to easily patch/fix issues in Just Cause 2. Including optional changes to "rebalance" the game or make it feel more active.

## Fixes

- 100% Completion patch
  - Missing Water Tower
  - Missing side quest reward
- Bullseye Rifle fix
  - Ammo type
  - Zoom/Scope
- Slingshot momentum
  - When the framerate is above 60, no momentum will be generated
- Mouse Aiming
  - 1:1 input
- Stability Improvments
  - Reduced crashes
- Changing the FOV
- Low quality landscape textures

## Mods (Optional)

- JC2 Rebalanced
- Increased Traffic
- More Wildlife
- Sky Retexture
- Blackmarket Cutscene Skip

### Notes

> [!TIP]
> Make sure to add the generated launch parameters in steam, this can also be done per this [guide](https://www.digitalcitizen.life/shortcut-arguments-parameters-windows/)

> [!WARNING]
> Beware, bugs may occur.

### Example

Providing a custom install directory.

```pwsh
.\JustCause2Fix.ps1 -CustomInstallLocation 'C:\Path\to\folder\JustCause2\'
#or
.\JustCause2Fix.ps1 'C:\Path\to\folder\JustCause2\'
```

Using with a default(steam) install.

```pwsh
.\JustCause2Fix.ps1
```

> [!TIP]
> The above commands are assuming your are in the directory of the extracted zip file from this repository.
> [!TIP]
> Here is a [guide](https://superuser.com/a/106363) explaining how to run PS scripts.

### Credits

- [Better Blood](https://videogamemods.com/justcause2/mods/better-blood-mod/)
- [Better Traffic](https://videogamemods.com/justcause2/mods/traffic-control/)
- [More Wildlife](https://videogamemods.com/justcause2/mods/improved-creatures-1-2/)
- [No Blackmarket Cutscene](https://videogamemods.com/justcause2/mods/no-blackmarket-cutscenes-v2/)
- [Realistic Skies](https://videogamemods.com/justcause2/mods/realistic-sky-and-cloud-v-1/)
- [JC2 Rebalanced Mod](https://videogamemods.com/justcause2/mods/jc2-rebalanced-v1-02/)
- [Bullseye Rifle Fix](https://videogamemods.com/justcause2/mods/bullseye-rifle-fix/)
- [100% Completion Fix](https://videogamemods.com/justcause2/mods/100-percent-completion/)
- [Landscape Textures](https://videogamemods.com/justcause2/mods/sharper-landscape-textures/)
- [Mouse Aim Fix](https://videogamemods.com/justcause2/mods/mouse-aiming-fix-negative-acceleration/)
- [Guide](https://www.pcgamingwiki.com/wiki/Just_Cause_2)
