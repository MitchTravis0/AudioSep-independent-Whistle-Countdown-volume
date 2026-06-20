# AudioSep — independent Whistle / Countdown volume for MECCHA CHAMELEON

A small [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) Lua mod that lets you set the
**countdown-timer** volume and the **whistle** volume **independently**, instead of
both moving together under the in-game SFX slider. Adjust them from two native
sliders in **Settings → Sound**, from hotkeys, or from the console — and your
levels are saved between sessions.

> **Game:** MECCHA CHAMELEON (Steam App `4704690`) · **Engine:** Unreal Engine 5.6.0 · **Tested:** patch 1.1.0
> **Scope:** client-side, hear-only. Use it in private lobbies.

---

## Features

- 🔊 Separate **Countdown Volume** and **Whistle Volume**, each `0%–100%` (boost to 400% via console).
- 🎚️ Two native sliders injected into **Settings → Sound** (built from the game's own slider widget).
- ⌨️ Hotkeys and console commands as a backup / for fine control.
- 💾 Levels persist in `levels.txt` and reload on launch.
- 🔁 Changes apply to sounds that are **already playing**, not just the next time they trigger.
- 🧰 Bundles UE4SS + the required UE 5.6 signature fix, plus a one-click installer.

---

## Requirements

- Windows + the **Steam** version of MECCHA CHAMELEON.
- Built and tested against **patch 1.1.0 / UE 5.6.0**. A future game patch can rename
  cues or shift the executable signature — see [Troubleshooting](#troubleshooting).
- Everything else (UE4SS, signature fix) is bundled. Nothing else to install.

---

## Installation

### Easy (recommended)

1. Download **`AudioSep-MecchaChameleon.zip`** from the [Releases](../../releases) page.
2. Extract it anywhere.
3. Make sure the game is **closed**, then double-click **`Install AudioSep.bat`**.
   - It auto-locates your Steam install (it reads your Steam library list and finds
     the one that actually contains the game) and copies everything in.
   - If Windows SmartScreen warns (“Windows protected your PC”), click
     **More info → Run anyway**. UE4SS-based mods commonly trip this; it is a false
     positive. You may scan the files first if you prefer.
4. Launch the game through Steam.

### Manual

Copy the **contents of `Win64\`** from the package into:

```
...\steamapps\common\MECCHA CHAMELEON\Chameleon\Binaries\Win64\
```

so that `dwmapi.dll` sits next to `PenguinHotel-Win64-Shipping.exe`. Final layout:

```
Chameleon\Binaries\Win64\
├── dwmapi.dll                                   (UE4SS proxy loader)
├── PenguinHotel-Win64-Shipping.exe              (the game)
└── ue4ss\
    ├── UE4SS.dll
    ├── UE4SS-settings.ini                       (console pre-enabled)
    ├── UE4SS_Signatures\
    │   └── StaticConstructObject.lua            (REQUIRED UE 5.6 signature fix)
    └── Mods\
        ├── mods.txt / mods.json                 (AudioSep registered & enabled)
        └── AudioSep\
            ├── enabled.txt
            ├── levels.txt                        (your saved volumes)
            ├── README.txt
            └── Scripts\main.lua                  (the mod)
```

### Uninstall

Double-click **`Uninstall AudioSep.bat`** (removes `dwmapi.dll` and the `ue4ss\` folder),
or delete those two from the `Win64` folder by hand.

---

## Usage

Open a **private** match, then:

- **Settings → Sound:** use the **Countdown Volume** and **Whistle Volume** sliders.
- **Hotkeys:**
  - `F1` / `F2` — countdown volume down / up
  - `F3` / `F4` — whistle volume down / up
  - `F8` — print current levels to the UE4SS console
- **Console** (open with the `` ` `` / `~` key):
  - `cdvol <0..4>` — set countdown volume (e.g. `cdvol 0.5`)
  - `whistlevol <0..4>` — set whistle volume (e.g. `whistlevol 1.0`)
  - `audiosep` — show current levels

`0.0` = silent, `1.0` = normal, up to `4.0` to boost. Values are written to
`ue4ss\Mods\AudioSep\levels.txt` and restored on the next launch.

---

## How it works

In UE5 every sound belongs to a Sound Class that feeds the master mix, so a single
SFX slider scales every cue in that class together. In this game the relevant cues
share the default class, so AudioSep instead intercepts the **individual cues** as
they play and applies a per-cue volume multiplier:

- It hooks the common play paths (`PlaySound2D`, `SpawnSound2D`,
  `PlaySoundAtLocation`, `SpawnSoundAtLocation`, `SpawnSoundAttached`) and
  `UAudioComponent:Play`, matching the target cues by name.
- For one-shot cues it sets the play-time `VolumeMultiplier`; for cues already
  playing it calls `SetVolumeMultiplier` on the live audio component so changes are
  heard immediately.
- The Settings sliders reuse the game's own `WBP_SettingSlider` widget and drive the
  same values, so the UI, hotkeys, console, and `levels.txt` all stay in sync. No
  engine memory is mutated directly from Lua (the saving is plain-text), which avoids
  a known crash class.

The cue names are configured at the top of `Scripts\main.lua`
(`COUNTDOWN_MATCH` / `WHISTLE_MATCH`).

---

## Troubleshooting

**No UE4SS console / it hangs on `PS Scan attempt N (Phase 2)`**
The UE 5.6 signature fix is missing or misplaced. Confirm
`ue4ss\UE4SS_Signatures\StaticConstructObject.lua` exists.

**The mod didn't load**
Check the UE4SS console (or `Win64\UE4SS.log`) for `[AudioSep] active …`. Verify
`ue4ss\Mods\AudioSep\enabled.txt` exists and `AudioSep` is listed in `mods.txt`.

**A slider doesn't appear in Settings → Sound**
Open Settings → Sound, then type `audiosepdump` in the UE4SS console and report the
output — it prints the live settings-page path and container. The hotkeys/console
work regardless of the sliders.

**A sound isn't being affected (wrong cue, or a game update renamed it)**
Open `Scripts\main.lua` and:
- set `local DEBUG = true` to log (once) every sound the mod actually scales, **or**
- set `local DISCOVER = true` to log every sound that plays with its name and play
  function.

Reproduce the sound, read the name from the console / `UE4SS.log`, and put a
distinctive substring of it into `COUNTDOWN_MATCH` or `WHISTLE_MATCH`. Then set the
flag back to `false`.

---

## Building / editing from source

This is plain Lua — no build step. Edit
`ue4ss\Mods\AudioSep\Scripts\main.lua` and restart the game (or use UE4SS
hot-reload). The matched cue names and default gains are constants at the top of the
file.

---

## Credits & acknowledgements

- **[UE4SS / RE-UE4SS](https://github.com/UE4SS-RE/RE-UE4SS)** — the scripting runtime (bundled).
- **[MecchaChameleon-FOVControl](https://github.com/TakoKylo/MecchaChameleon-FOVControl)** by *Amikiir* — reference for the settings-slider injection pattern and the source of the bundled UE 5.6 signature fix.
- Signature fix origin: [UE4SS issue #1197](https://github.com/UE4SS-RE/RE-UE4SS/issues/1197).

## License & disclaimer

The AudioSep scripts in this repository are released freely — use, modify, and
redistribute them. Bundled UE4SS retains its own license (see `ue4ss/LICENSE`).

This is an unofficial, fan-made mod, not affiliated with or endorsed by the
developer. It only rebalances the relative volume of two cues **you already hear**,
so it gives no information other players lack — but it is still a third-party
modification: run it in **private lobbies** and at your own risk.
