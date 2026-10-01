# smoke-map.ps1 — post-map smoke tests using logs/map.state.
# Usage: .\tools\smoke-map.ps1 [-State logs\map.state] [-Case unit|save|both]

param(
    [string]$State = "",
    [ValidateSet('unit','save','both')]
    [string]$Case = 'both'
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if (-not $State) { $State = Join-Path $Root 'logs\map.state' }
if (-not (Test-Path $State)) { throw "missing savestate $State (run tools/boot-map-state.ps1 first)" }

$exe = Join-Path $Root 'build\host\AdvanceWars2BlackHoleRisingRecomp.exe'
$rom = 'Advance Wars 2 - Black Hole Rising (USA).gba'
$bios = 'D:\Project\GameRecomp\gbarecomp-cli-windows-x86_64\gbabios\gba_bios.bin'
$sav = Join-Path $Root 'saves\aw2bhr_usa.sav'
$savPre = "$sav.pre"

function Run-Case([string]$name, [string]$replay, [string]$png) {
    $env:GBARECOMP_SELFHEAL_RECOMPILE = '0'
    $env:GBARECOMP_COVERAGE_JSON = Join-Path $Root "logs\smoke-$name-cov.json"
    $env:GBARECOMP_MISS_FRAG = 'NUL'
    $env:GBARECOMP_INPUT_REPLAY = $replay
    $out = Join-Path $Root "logs\smoke-$name-out.txt"
    Write-Host "==> $name  replay=$(Split-Path $replay -Leaf)"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    & $exe --rom $rom --bios $bios --config 'game.toml' --load-state $State --frames 3000 --dump-png $png 2>&1 |
        Tee-Object -FilePath $out | Select-String 'final_pc|pal_nonzero|overflow|save_' | ForEach-Object { Write-Host "  $_" }
    $sw.Stop()
    Write-Host "  elapsed $([math]::Round($sw.Elapsed.TotalSeconds,1))s"
    if (Test-Path $png) { Write-Host "  png $png ($((Get-Item $png).Length) bytes)" }
}

if ($Case -in @('unit','both')) {
    Run-Case 'unit' (Join-Path $Root 'tests\input\map-from-state.keyinput.txt') (Join-Path $Root 'logs\smoke-unit.png')
}
if ($Case -in @('save','both')) {
    if (Test-Path $savPre) { Copy-Item $savPre $sav -Force }
    $before = (Get-FileHash $sav -Algorithm SHA1).Hash
    Run-Case 'save' (Join-Path $Root 'tests\input\map-save.keyinput.txt') (Join-Path $Root 'logs\smoke-save.png')
    $after = (Get-FileHash $sav -Algorithm SHA1).Hash
    Write-Host "save hash before=$before"
    Write-Host "save hash after =$after"
    if ($before -ne $after) { Write-Host 'SAVE FILE CHANGED (good sign)' } else { Write-Host 'SAVE FILE UNCHANGED' }
}

Write-Host 'smoke-map done'
