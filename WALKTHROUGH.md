# AudioSep for MECCHA CHAMELEON - setup walkthrough

Separate the **countdown timer** volume from the **whistle** volume. Client-side,
hear-only. Built against patch 1.1.0 / UE 5.6.0 (engine CL 43139311).

## What's in this package

```
dist/
├── Install AudioSep.bat        double-click to install
├── Uninstall AudioSep.bat      double-click to remove
├── install.ps1 / uninstall.ps1 the scripts the .bat files call
├── START-HERE.txt              short instructions for friends
├── WALKTHROUGH.md              this file
└── Win64\                      <-- contents go into ...\Chameleon\Binaries\Win64\
    ├── dwmapi.dll              UE4SS proxy loader
    └── ue4ss\
        ├── UE4SS.dll
        ├── UE4SS-settings.ini  console pre-enabled (so you can read discovery output)
        ├── UE4SS_Signatures\
        │   └── StaticConstructObject.lua   REQUIRED UE 5.6 signature fix
        └── Mods\
            ├── mods.txt / mods.json         AudioSep registered & enabled
            └── AudioSep\
                ├── enabled.txt
                ├── levels.txt               saved volumes (countdown / whistle)
                ├── README.txt
                └── Scripts\main.lua         the mod
```

UE4SS bundled: `UE4SS_v3.0.1-971-g9ec5ece7` (experimental, the build that supports
UE 5.6). Official source: https://github.com/UE4SS-RE/RE-UE4SS/releases

## Install

**Easiest (for sharing):** close the game, then double-click
**`Install AudioSep.bat`**. If SmartScreen warns, More info -> Run anyway.

**Automatic (PowerShell):** from this `dist` folder:
```
powershell -ExecutionPolicy Bypass -File .\install.ps1
```
It finds the game via Steam's library list and copies everything into the right
`Win64` folder. Re-running it preserves your `levels.txt`.

**Manual:** copy the entire contents of `Win64\` into
`...\steamapps\common\MECCHA CHAMELEON\Chameleon\Binaries\Win64\`
so that `dwmapi.dll` sits next to `PenguinHotel-Win64-Shipping.exe`.

**Uninstall:** double-click `Uninstall AudioSep.bat` (removes dwmapi.dll + ue4ss\).

## Step 1 - confirm UE4SS loads

Launch the game **through Steam**. A UE4SS console window should appear. If it
hangs on `PS Scan attempt N (Phase 2)`, the signature fix is missing or
misplaced - confirm `ue4ss\UE4SS_Signatures\StaticConstructObject.lua` exists.

In the console you should see `[AudioSep] DISCOVERY MODE ...` and a list of
`hooked /Script/Engine.GameplayStatics:...` lines. (Everything is also written
to `Win64\UE4SS.log`.)

## Step 2 - confirmed cue mapping (Phase 2/3 done)

Discovery has already been run against patch 1.1.0 and the mod is configured:

```
Whistle   -> SC_Provoaction               (provoke/whistle cue)
Countdown -> SC_cLeon_HideTime            (hide-phase timer)
             SC_cLen_SearchStart          (search-start stinger)
             SC_cLeon_Search              (search-phase background music)
```

In this game `SC_` is a Sound *Cue* prefix and these cues share the default
Sound Class, so the mod scales each target cue individually (it does not touch
the shared class). Matching lives in `COUNTDOWN_MATCH` / `WHISTLE_MATCH` in
`Scripts\main.lua`. If a future patch renames cues, set `DISCOVER = true` there
and re-run discovery.

## Step 3 - adjust and persist (Phase 4)

- **Settings -> Sound:** two native sliders, "Countdown Volume" and "Whistle
  Volume", injected into the Audio tab (reusing the game's own slider widget).
- Hotkeys: `F1/F2` countdown down/up, `F3/F4` whistle down/up, `F8` print levels.
- Console: `cdvol 1.0`, `whistlevol 0.4`, `audiosep` to show current.
- Values persist in `levels.txt` and reload next launch.

If the sliders do not appear: open Settings -> Sound, then in the UE4SS console
run `audiosepdump` and send me the output (it prints the live page path and
container so I can correct them). The hotkeys/console work regardless.

## Sharing with friends

Zip this whole `dist` folder (or send `AudioSep-MecchaChameleon.zip`). They:
1. Extract it anywhere.
2. Close the game, double-click `Install AudioSep.bat`, allow it past SmartScreen.
3. Launch through Steam.

They need the Windows/Steam game on the same patch (1.1.0 / UE 5.6); the signature
fix and cue names are version-specific. If a patch breaks it, re-run discovery
(`DISCOVER = true`) and update the match names.

## Step 4 - verify

In a private lobby: countdown and whistle move independently, nothing else
changes, and the levels survive a restart.

## If a cue is not affected

It is played by a function not yet matched. Set `DISCOVER = true`, reproduce it,
and check which line names it. If it only ever appears under
`AudioComponent:Play`, apply mode already handles that (it sets the component's
`VolumeMultiplier`).
