AudioSep - independent whistle / countdown volume for MECCHA CHAMELEON
=====================================================================

WHAT IT DOES
  Sets the countdown-timer volume and the whistle volume separately, instead of
  both moving together with the in-game SFX slider.

CONFIGURED MAPPING (confirmed in-game, patch 1.1.0)
  Whistle   -> SC_Provoaction                 (the provoke/whistle cue)
  Countdown -> SC_cLeon_HideTime              (hide-phase timer)
               SC_cLen_SearchStart            (search-start stinger)
               SC_cLeon_Search                (search-phase background music)
  Matched as lowercase substrings in COUNTDOWN_MATCH / WHISTLE_MATCH in
  Scripts/main.lua. Everything else is left untouched.

CONTROLS
  Hotkeys:   F1 / F2  = countdown volume down / up
             F3 / F4  = whistle  volume down / up
             F8       = print current levels to the UE4SS console
  Console:   cdvol <n>        e.g.  cdvol 0.5
             whistlevol <n>   e.g.  whistlevol 1.0
             audiosep         show current levels
  ( open the UE4SS console with the ~ / backtick key, or read UE4SS.log )

  0.0 = silent, 1.0 = normal, up to 4.0 to boost. Values save to levels.txt
  next to this file and reload on launch.

NOTE ON LOOPING SOUNDS
  Changing a volume also updates any matching sound that is currently playing
  (the hide timer and the looping search music), so adjustments are heard right
  away, not just on the next round.

RE-RUNNING DISCOVERY
  If a future game patch renames the cues, set DISCOVER = true at the top of
  main.lua, reproduce the sounds, and read the [AudioSep] lines in the console.

NOTE
  Client-side and hear-only. Develop and test in private lobbies.
