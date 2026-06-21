# AudioSep installer for MECCHA CHAMELEON
# Copies the UE4SS + AudioSep payload (.\Win64\*) into the game's
# ...\Chameleon\Binaries\Win64\ folder. Finds the install automatically by
# reading Steam's library list and probing each library for the game exe.
#
# Run from PowerShell:   .\install.ps1
# (if blocked:  powershell -ExecutionPolicy Bypass -File .\install.ps1 )

$ErrorActionPreference = "Stop"
$rel = "Chameleon\Binaries\Win64"
$exe = "PenguinHotel-Win64-Shipping.exe"

function Get-SteamPath {
    foreach ($key in @("HKCU:\Software\Valve\Steam", "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam")) {
        try {
            $p = (Get-ItemProperty -Path $key -ErrorAction Stop).SteamPath
            if ($p) { return $p.Replace("/", "\") }
        } catch {}
    }
    return $null
}

# Collect candidate Steam library roots.
$libraries = New-Object System.Collections.Generic.List[string]
$steam = Get-SteamPath
if ($steam) { $libraries.Add($steam) }

if ($steam) {
    $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
    if (Test-Path $vdf) {
        foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s*"([^"]+)"')) {
            $libraries.Add($m.Groups[1].Value.Replace("\\", "\"))
        }
    }
}

# Probe each library for the actual game exe.
$gameWin64 = $null
foreach ($lib in $libraries | Select-Object -Unique) {
    $cand = Join-Path $lib "steamapps\common\MECCHA CHAMELEON\$rel"
    if (Test-Path (Join-Path $cand $exe)) { $gameWin64 = $cand; break }
}

if (-not $gameWin64) {
    Write-Host "Could not auto-locate MECCHA CHAMELEON." -ForegroundColor Yellow
    $manual = Read-Host "Paste the full path to ...\MECCHA CHAMELEON\$rel (or blank to abort)"
    if ($manual -and (Test-Path (Join-Path $manual $exe))) { $gameWin64 = $manual }
    else { Write-Host "Aborting: install path not found." -ForegroundColor Red; exit 1 }
}

Write-Host "Found game at: $gameWin64" -ForegroundColor Green

$src = Join-Path $PSScriptRoot "Win64"
if (-not (Test-Path (Join-Path $src "dwmapi.dll"))) {
    Write-Host "Payload .\Win64\dwmapi.dll missing - run this script from the dist folder." -ForegroundColor Red
    exit 1
}

# Preserve existing volume levels across a re-install.
$levels = Join-Path $gameWin64 "ue4ss\Mods\AudioSep\levels.txt"
$saved = $null
if (Test-Path $levels) { $saved = Get-Content $levels -Raw }

Copy-Item -Path (Join-Path $src "*") -Destination $gameWin64 -Recurse -Force
if ($saved) { Set-Content -Path $levels -Value $saved -NoNewline }

Write-Host ""
Write-Host "Installed. Layout:" -ForegroundColor Green
Write-Host "  $gameWin64\dwmapi.dll"
Write-Host "  $gameWin64\ue4ss\ (UE4SS + signature fix)"
Write-Host "  $gameWin64\ue4ss\Mods\AudioSep\"
Write-Host ""
Write-Host "Next: launch the game through Steam. The UE4SS console window should"
Write-Host "appear. AudioSep is active immediately - see README.md for usage."
