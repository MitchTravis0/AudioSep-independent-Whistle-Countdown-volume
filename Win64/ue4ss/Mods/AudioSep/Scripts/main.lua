-- AudioSep - independent whistle / countdown volume for MECCHA CHAMELEON
--
-- Two modes, switched by DISCOVER below:
--   DISCOVER = true  (Phase 2): logs every sound that plays, which engine
--                    function played it, and the sound's Sound Class. Use this
--                    to find the REAL countdown / whistle asset names, then fill
--                    them into the match tables and flip DISCOVER to false.
--   DISCOVER = false (Phase 3/4): applies an independent volume multiplier to
--                    the countdown and whistle cues. Adjust live with hotkeys or
--                    console commands; values persist in levels.txt.
--
-- Why per-asset interception: in UE5 a Sound Class feeds the master mix, so the
-- SFX slider scales every cue in that class together. We instead scale the two
-- target cues individually at the moment they play, leaving everything else
-- untouched. This works whether a cue is played through GameplayStatics or
-- through a UAudioComponent.
--
-- Crash-safety rule (learned from the FOVControl mod): never create or mutate
-- engine containers (TMap/TArray/FString/FText) from Lua. We only write plain
-- float values that the engine owns (a function parameter, or a component's
-- VolumeMultiplier float), which is safe.

------------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------------

local DISCOVER = false  -- set to true to re-log sound names (Phase 2)
local DEBUG    = false  -- set to true to log (once) every sound the mod scales

-- Volume multipliers (0.0 = silent, 1.0 = unchanged, >1.0 = louder).
local countdownGain = 1.0
local whistleGain   = 0.5

-- Substrings matched (case-insensitive) against USoundBase:GetFullName().
--   Whistle   : SC_Provoaction (the provoke/whistle cue; dev's spelling).
--   Countdown : the actual TIMER sound. The cLeon cues are phase BGM (they live
--               in /cLeon/bgm/), not the timer, so we target the ticking-clock
--               SoundWave that plays on the round/storm countdown plus the asset
--               literally named "Countdown". If neither is the sound you hear,
--               set DEBUG=true (or DISCOVER=true) and watch the console while the
--               timer plays to get its real name, then put it here.
local COUNTDOWN_MATCH = { "clock-ticking-tension", "countdown" }
local WHISTLE_MATCH   = { "sc_provoaction" }

-- Hotkey step and persistence file.
local STEP        = 0.1
local CONFIG_PATH = "ue4ss\\Mods\\AudioSep\\levels.txt"

------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------

local function Log(fmt, ...)
    print(string.format("[AudioSep] " .. fmt .. "\n", ...))
end

local function clamp01(v)
    if v < 0.0 then return 0.0 end
    if v > 4.0 then return 4.0 end   -- allow boosting, cap to something sane
    return v
end

-- In discovery mode, log each distinct sound only once so the two target cues
-- are not buried under repeating footstep/ambient spam.
local seen = {}
local function logOnce(label, name, cls)
    local key = label .. "|" .. name
    if seen[key] then return end
    seen[key] = true
    Log("%-20s | %s | class=%s", label, name, cls)
end

-- When DEBUG is on, log each distinct sound the mod actually scales (once), so
-- you can confirm in the console that the right cue is being targeted.
local dbgSeen = {}
local function dbgScaled(name)
    if not DEBUG or dbgSeen[name] then return end
    dbgSeen[name] = true
    Log("scaled -> %s", name)
end

local function matchesAny(lowerName, list)
    for _, sub in ipairs(list) do
        if lowerName:find(sub, 1, true) then return true end
    end
    return false
end

-- Read a sound's Sound Class name if one is assigned (override or default).
local function soundClassName(s)
    local cls = "(default)"
    pcall(function()
        local sc = s.SoundClassOverride
        if sc and sc:IsValid() then cls = sc:GetFullName() end
    end)
    return cls
end

------------------------------------------------------------------------
-- persistence (plain text, our own file - never the game save)
------------------------------------------------------------------------

local function SaveLevels()
    local f = io.open(CONFIG_PATH, "w")
    if not f then return end
    f:write(string.format("countdown=%.3f\nwhistle=%.3f\n", countdownGain, whistleGain))
    f:close()
end

local function LoadLevels()
    local f = io.open(CONFIG_PATH, "r")
    if not f then return end
    for line in f:lines() do
        local k, v = line:match("^%s*([%w_]+)%s*=%s*([%d%.]+)")
        if k == "countdown" then countdownGain = clamp01(tonumber(v) or countdownGain) end
        if k == "whistle"   then whistleGain   = clamp01(tonumber(v) or whistleGain)   end
    end
    f:close()
end

------------------------------------------------------------------------
-- the actual work: decide a gain for a sound, log it, or apply it
------------------------------------------------------------------------

-- Returns the gain to apply for this sound, or nil if it is not a target.
local function gainFor(lowerName)
    if matchesAny(lowerName, COUNTDOWN_MATCH) then return countdownGain end
    if matchesAny(lowerName, WHISTLE_MATCH)   then return whistleGain end
    return nil
end

-- soundParam / volParam are UE4SS RemoteUnrealParam objects. volParam may be nil
-- (e.g. SpawnSoundAttached path we only log, or component plays handled elsewhere).
local function handleStatic(label, soundParam, volParam)
    pcall(function()
        local s = soundParam:get()
        if not s or not s:IsValid() then return end
        local name = s:GetFullName()

        if DISCOVER then
            logOnce(label, name, soundClassName(s))
            return
        end

        local g = gainFor(name:lower())
        if g then
            dbgScaled(name)
            if volParam then volParam:set(g) end
        end
    end)
end

------------------------------------------------------------------------
-- hooks: cover every common play path
------------------------------------------------------------------------
-- Param indexes are the UFunction arguments in order; arg 1 of the Lua callback
-- is the object the function was called on (the GameplayStatics CDO here).

local function tryHook(path, fn)
    local ok, err = pcall(function() RegisterHook(path, fn) end)
    if ok then Log("hooked %s", path) else Log("could not hook %s (%s)", path, tostring(err)) end
end

-- PlaySound2D(WorldContext, Sound, VolumeMultiplier, Pitch, StartTime, Conc, Owner, bUI)
tryHook("/Script/Engine.GameplayStatics:PlaySound2D",
function(self, WorldContext, Sound, VolumeMultiplier)
    handleStatic("PlaySound2D", Sound, VolumeMultiplier)
end)

-- SpawnSound2D(WorldContext, Sound, VolumeMultiplier, Pitch, StartTime, Conc, ...)
tryHook("/Script/Engine.GameplayStatics:SpawnSound2D",
function(self, WorldContext, Sound, VolumeMultiplier)
    handleStatic("SpawnSound2D", Sound, VolumeMultiplier)
end)

-- PlaySoundAtLocation(WorldContext, Sound, Location, Rotation, VolumeMultiplier, ...)
tryHook("/Script/Engine.GameplayStatics:PlaySoundAtLocation",
function(self, WorldContext, Sound, Location, Rotation, VolumeMultiplier)
    handleStatic("PlaySoundAtLocation", Sound, VolumeMultiplier)
end)

-- SpawnSoundAtLocation(WorldContext, Sound, Location, Rotation, VolumeMultiplier, ...)
tryHook("/Script/Engine.GameplayStatics:SpawnSoundAtLocation",
function(self, WorldContext, Sound, Location, Rotation, VolumeMultiplier)
    handleStatic("SpawnSoundAtLocation", Sound, VolumeMultiplier)
end)

-- SpawnSoundAttached(Sound, AttachComp, Point, Loc, Rot, LocType, bStop, VolumeMultiplier, ...)
tryHook("/Script/Engine.GameplayStatics:SpawnSoundAttached",
function(self, Sound, AttachComp, Point, Loc, Rot, LocType, bStop, VolumeMultiplier)
    handleStatic("SpawnSoundAttached", Sound, VolumeMultiplier)
end)

-- Component-played cues: the sound lives on the component, not in a param. We
-- read self.Sound and, in apply mode, set the component's VolumeMultiplier
-- (a plain float, safe to write) before it plays.
tryHook("/Script/Engine.AudioComponent:Play",
function(self)
    pcall(function()
        local comp = self:get()
        if not comp or not comp:IsValid() then return end
        local s = comp.Sound
        if not s or not s:IsValid() then return end
        local name = s:GetFullName()

        if DISCOVER then
            logOnce("AudioComponent:Play", name, soundClassName(s))
            return
        end

        local g = gainFor(name:lower())
        if g then dbgScaled(name); comp.VolumeMultiplier = g end
    end)
end)

------------------------------------------------------------------------
-- live controls (apply mode)
------------------------------------------------------------------------

-- Re-apply gains to sounds that are ALREADY playing. One-shot cues (whistle,
-- search-start) pick up a new value on their next play, but the hide-timer and
-- search music are long-running AudioComponents started once per round, so a
-- mid-round change is only heard if we push it to the live component too.
local function reapplyLive()
    pcall(function()
        local comps = FindAllOf("AudioComponent") or {}
        for _, comp in ipairs(comps) do
            pcall(function()
                if not comp:IsValid() then return end
                local s = comp.Sound
                if not s or not s:IsValid() then return end
                local name = s:GetFullName()
                local g = gainFor(name:lower())
                if g then dbgScaled(name); comp:SetVolumeMultiplier(g) end
            end)
        end
    end)
end

local function setCountdown(v)
    countdownGain = clamp01(v)
    SaveLevels()
    reapplyLive()
    Log("countdown volume = %.2f", countdownGain)
end

local function setWhistle(v)
    whistleGain = clamp01(v)
    SaveLevels()
    reapplyLive()
    Log("whistle volume = %.2f", whistleGain)
end

-- Hotkeys (F5/F6/F7 are used by FOVControl, so we use F1-F4 + F8).
RegisterKeyBind(Key.F1, function() setCountdown(countdownGain - STEP) end)
RegisterKeyBind(Key.F2, function() setCountdown(countdownGain + STEP) end)
RegisterKeyBind(Key.F3, function() setWhistle(whistleGain - STEP) end)
RegisterKeyBind(Key.F4, function() setWhistle(whistleGain + STEP) end)
RegisterKeyBind(Key.F8, function()
    Log("levels: countdown=%.2f whistle=%.2f (DISCOVER=%s)", countdownGain, whistleGain, tostring(DISCOVER))
end)

-- Console commands: cdvol <n> / whistlevol <n> / audiosep
RegisterConsoleCommandHandler("cdvol", function(_, parameters, out)
    local v = tonumber(parameters[1])
    if v then setCountdown(v); out:Log(string.format("countdown volume set to %.2f", countdownGain))
    else out:Log(string.format("countdown volume is %.2f (usage: cdvol <0..4>)", countdownGain)) end
    return true
end)

RegisterConsoleCommandHandler("whistlevol", function(_, parameters, out)
    local v = tonumber(parameters[1])
    if v then setWhistle(v); out:Log(string.format("whistle volume set to %.2f", whistleGain))
    else out:Log(string.format("whistle volume is %.2f (usage: whistlevol <0..4>)", whistleGain)) end
    return true
end)

RegisterConsoleCommandHandler("audiosep", function(_, _, out)
    out:Log(string.format("AudioSep: countdown=%.2f whistle=%.2f DISCOVER=%s",
        countdownGain, whistleGain, tostring(DISCOVER)))
    return true
end)

------------------------------------------------------------------------
-- Settings UI: two sliders under the Audio tab (WBP_ConfigSound)
------------------------------------------------------------------------
-- Reuses the game's own WBP_SettingSlider widget and its bound value events
-- (same pattern the FOVControl mod proved on this game). The sliders only
-- drive countdownGain / whistleGain (and thus levels.txt); they do not need the
-- game's settings save, so we never write engine containers from Lua. Volume is
-- the simple case: the inner slider's 0..1 value is the gain directly.

if not DISCOVER then
  pcall(function()
    local UEHelpers = require("UEHelpers")

    local SLIDER_CLASS = "/Game/UI/Settings/WBP_SettingSlider.WBP_SettingSlider_C"
    local SOUND_PAGE   = "/Game/UI/Settings/WBP_ConfigSound.WBP_ConfigSound_C"
    local EV_DRAG  = SLIDER_CLASS .. ":BndEvt__WBP_SettingSlider_WBP_NavSlider_Penguin_K2Node_ComponentBoundEvent_0_OnValueChangeEvery__DelegateSignature"
    local EV_FINAL = SLIDER_CLASS .. ":BndEvt__WBP_SettingSlider_WBP_NavSlider_Penguin_K2Node_ComponentBoundEvent_4_OnValueChangedEvent__DelegateSignature"

    local SLIDER_MAX = 1.0          -- gain 0..1 ; row number reads 0..100
    local CD_KEY = "AudioSepCD"     -- our SaveValueKeys (only used to tag our rows)
    local WH_KEY = "AudioSepWhistle"

    local function gainForKey(key)
        if key == CD_KEY then return countdownGain end
        if key == WH_KEY then return whistleGain end
        return nil
    end
    local function applyKey(key, raw)
        if key == CD_KEY then setCountdown(raw)
        elseif key == WH_KEY then setWhistle(raw) end
    end

    local function readInner(widget)
        local raw
        pcall(function() raw = widget.WBP_NavSlider_Penguin.Slider:GetValue() end)
        return raw
    end
    local function setLabel(widget, text)
        pcall(function()
            local ktl = StaticFindObject("/Script/Engine.Default__KismetTextLibrary")
            widget.ConfigItem_Text:SetText(ktl:Conv_StringToText(text))
        end)
    end

    -- one set of value-change hooks covers every slider; filter to our two keys
    local hooksDone = false
    local function registerHooks()
        if hooksDone then return end
        local function onChange(Context)
            local widget = Context:get()
            local key = ""
            pcall(function() key = widget.SaveValueKey:ToString() end)
            if key ~= CD_KEY and key ~= WH_KEY then return end
            local raw = readInner(widget)
            if raw then applyKey(key, raw * SLIDER_MAX) end
        end
        hooksDone = pcall(function()
            RegisterHook(EV_DRAG,  function(Context) onChange(Context) end)
            RegisterHook(EV_FINAL, function(Context) onChange(Context) end)
        end)
        Log("settings slider hooks %s", hooksDone and "registered" or "FAILED")
    end

    -- find the settings list container; ScrollBox_0 matches the page template,
    -- with a widget-tree walk as a fallback if the name ever differs.
    local function findScrollIn(w, sbClass, depth)
        if depth > 8 or not w or not w:IsValid() then return nil end
        local isSb = false
        pcall(function() isSb = w:IsA(sbClass) end)
        if isSb then
            local c = 0; pcall(function() c = w:GetChildrenCount() end)
            if c > 0 then return w end
        end
        local n = 0; pcall(function() n = w:GetChildrenCount() end)
        for i = 0, n - 1 do
            local child; pcall(function() child = w:GetChildAt(i) end)
            local r = findScrollIn(child, sbClass, depth + 1)
            if r then return r end
        end
        return nil
    end
    local function findScroll(page)
        local scroll
        pcall(function()
            if page.ScrollBox_0 and page.ScrollBox_0:IsValid() then scroll = page.ScrollBox_0 end
        end)
        if scroll then return scroll end
        pcall(function()
            local sbClass = StaticFindObject("/Script/UMG.ScrollBox")
            scroll = findScrollIn(page.WidgetTree.RootWidget, sbClass, 0)
        end)
        return scroll
    end

    local function injectOne(page, scroll, key, label)
        for i = 0, scroll:GetChildrenCount() - 1 do
            local child = scroll:GetChildAt(i)
            local k = ""
            pcall(function() k = child.SaveValueKey:ToString() end)
            if k == key then return end   -- already injected into this page
        end
        local cls = StaticFindObject(SLIDER_CLASS)
        local wbl = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        if not (cls and cls:IsValid() and wbl and wbl:IsValid()) then
            Log("slider class / WidgetBlueprintLibrary not loaded"); return
        end
        local widget = wbl:Create(page, cls, UEHelpers.GetPlayerController())
        if not (widget and widget:IsValid()) then Log("create failed (%s)", key); return end
        widget.SaveValueKey = FName(key)
        widget.MaxValue = SLIDER_MAX
        widget.StepValue = 0.05
        pcall(function() widget["Update Config Item"](widget) end)
        scroll:AddChild(widget)
        -- finish after AddChild re-runs the widget's construct (FOVControl note)
        ExecuteWithDelay(120, function()
            ExecuteInGameThread(function()
                pcall(function()
                    local nav = widget.WBP_NavSlider_Penguin
                    local sld = nav.Slider
                    if sld and sld:IsValid() then
                        sld:SetValue((gainForKey(key) or 1.0) / SLIDER_MAX)
                        pcall(function() nav:HandleOnSliderValueChanged(sld:GetValue()) end)
                    end
                end)
                setLabel(widget, label)
            end)
        end)
        Log("injected '%s' slider", label)
    end

    NotifyOnNewObject(SOUND_PAGE, function(page)
        ExecuteWithDelay(250, function()
            ExecuteInGameThread(function()
                registerHooks()
                local scroll = findScroll(page)
                if not scroll then
                    Log("Audio page has no scrollbox - run 'audiosepdump' and send me the output")
                    return
                end
                injectOne(page, scroll, CD_KEY, "Countdown Volume")
                injectOne(page, scroll, WH_KEY, "Whistle Volume")
            end)
        end)
    end)
    Log("audio-settings slider injection armed (open Settings -> Sound)")
  end)

  -- diagnostic: confirms the real page path / container if sliders don't appear
  RegisterConsoleCommandHandler("audiosepdump", function(_, _, out)
      local function report(shortName)
          local insts = {}
          pcall(function() insts = FindAllOf(shortName) or {} end)
          for _, w in ipairs(insts) do
              local full, sb = "?", "no ScrollBox_0"
              pcall(function() full = w:GetFullName() end)
              pcall(function()
                  if w.ScrollBox_0 and w.ScrollBox_0:IsValid() then
                      sb = "ScrollBox_0 children=" .. tostring(w.ScrollBox_0:GetChildrenCount())
                  end
              end)
              out:Log(full .. " | " .. sb)
          end
          if #insts == 0 then out:Log("(no loaded " .. shortName .. ")") end
      end
      report("WBP_ConfigSound_C")
      report("WBP_ConfigGameGeneral_C")
      return true
  end)
end

------------------------------------------------------------------------
-- boot
------------------------------------------------------------------------

LoadLevels()
if DISCOVER then
    Log("DISCOVERY MODE - play a countdown and blow the whistle, then read the")
    Log("lines above starting with [AudioSep]. Copy the countdown/whistle names.")
else
    Log("active - countdown=%.2f whistle=%.2f | F1/F2 cd -/+, F3/F4 whistle -/+, console: cdvol/whistlevol",
        countdownGain, whistleGain)
end
