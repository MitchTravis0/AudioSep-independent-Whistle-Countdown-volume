# AudioSep uninstaller for MECCHA CHAMELEON.
# Removes dwmapi.dll and the ue4ss\ folder (this package's self-contained UE4SS)
# from the game's Win64 folder. Finds the install the same way install.ps1 does.

$ErrorActionPreference = "Stop"
$rel = "Chameleon\Binaries\Win64"
$exe = "PenguinHotel-Win64-Shipping.exe"

function Get-SteamPath {
    foreach ($key in @("HKCU:\Software\Valve\Steam", "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam")) {
        try { $p = (Get-ItemProperty -Path $key -ErrorAction Stop).SteamPath; if ($p) { return $p.Replace("/", "\") } } catch {}
    }
    return $null
}

$libraries = New-Object System.Collections.Generic.List[string]
$steam = Get-SteamPath
if ($steam) {
    $libraries.Add($steam)
    $vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
    if (Test-Path $vdf) {
        foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s*"([^"]+)"')) {
            $libraries.Add($m.Groups[1].Value.Replace("\\", "\"))
        }
    }
}

$gameWin64 = $null
foreach ($lib in $libraries | Select-Object -Unique) {
    $cand = Join-Path $lib "steamapps\common\MECCHA CHAMELEON\$rel"
    if (Test-Path (Join-Path $cand $exe)) { $gameWin64 = $cand; break }
}
if (-not $gameWin64) {
    $manual = Read-Host "Could not auto-locate the game. Paste ...\MECCHA CHAMELEON\$rel (or blank to abort)"
    if ($manual -and (Test-Path (Join-Path $manual $exe))) { $gameWin64 = $manual }
    else { Write-Host "Aborting." -ForegroundColor Red; exit 1 }
}

Write-Host "Removing AudioSep + UE4SS from: $gameWin64" -ForegroundColor Yellow
foreach ($item in @("dwmapi.dll", "ue4ss", "UE4SS.log")) {
    $path = Join-Path $gameWin64 $item
    if (Test-Path $path) { Remove-Item $path -Recurse -Force; Write-Host "  removed $item" }
}
Write-Host "Done. The game is back to stock." -ForegroundColor Green
