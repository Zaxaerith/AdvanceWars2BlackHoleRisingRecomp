# boot-map-state.ps1 — boot AW2 to the first map and capture a savestate.
#
# Headless runs measure ~85 ms/frame, so boot-to-map (~21000 frames) takes
# ~30 minutes. This script starts the game with --tcp, continues, waits, then
# writes logs/map.state via the TCP savestate_save command. Subsequent runs use
# --load-state logs/map.state to skip the boot.

param(
    [int]$Port = 19842,
    [int]$WaitSeconds = 2400,
    [string]$StatePath = ""
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if (-not $StatePath) { $StatePath = Join-Path $Root 'logs\map.state' }
$exe = Join-Path $Root 'build\host\AdvanceWars2BlackHoleRisingRecomp.exe'
$rom = 'Advance Wars 2 - Black Hole Rising (USA).gba'
$bios = 'D:\Project\GameRecomp\gbarecomp-cli-windows-x86_64\gbabios\gba_bios.bin'
$replay = Join-Path $Root 'tests\input\campaign-to-map.keyinput.txt'
New-Item -ItemType Directory -Force -Path (Split-Path $StatePath) | Out-Null

function Send-DbgCmd([string]$cmd, [int]$timeoutMs = 20000) {
    $c = New-Object Net.Sockets.TcpClient
    $c.Connect('127.0.0.1', $Port)
    $c.ReceiveTimeout = $timeoutMs
    $s = $c.GetStream()
    $w = New-Object IO.StreamWriter($s); $w.NewLine = "`n"; $w.AutoFlush = $true
    $w.WriteLine($cmd)
    $line = (New-Object IO.StreamReader($s)).ReadLine()
    $c.Close()
    return $line
}

Write-Host "==> starting $exe --tcp $Port"
$env:GBARECOMP_SELFHEAL_RECOMPILE = '0'
$env:GBARECOMP_COVERAGE_JSON = 'NUL'
$env:GBARECOMP_MISS_FRAG = 'NUL'
$env:GBARECOMP_INPUT_REPLAY = $replay
$p = Start-Process -FilePath $exe -ArgumentList @(
    '--tcp', "$Port",
    '--rom', $rom,
    '--bios', $bios,
    '--config', 'game.toml'
) -WorkingDirectory $Root -PassThru
Write-Host "==> pid $($p.Id); waiting for TCP..."
Start-Sleep -Seconds 3

Write-Host '==> continue'
try { Send-DbgCmd '{"cmd":"continue"}' | Out-Null } catch { Write-Host "continue: $_" }

Write-Host "==> waiting $WaitSeconds s for boot-to-map"
$deadline = (Get-Date).AddSeconds($WaitSeconds)
while ((Get-Date) -lt $deadline) {
    if ($p.HasExited) { Write-Host "process exited early code=$($p.ExitCode)"; break }
    Start-Sleep -Seconds 30
    Write-Host "  t=$((Get-Date).ToString('HH:mm:ss')) still running"
}

if (-not $p.HasExited) {
    Write-Host "==> savestate_save -> $StatePath"
    try {
        $r = Send-DbgCmd ('{"cmd":"savestate_save","path":"' + ($StatePath -replace '\\','\\') + '"}')
        Write-Host "  $r"
    } catch { Write-Host "save failed: $_" }
    Write-Host '==> screenshot'
    try {
        $r = Send-DbgCmd '{"cmd":"screenshot"}'
        if ($r) {
            $j = $r | ConvertFrom-Json
            Write-Host "  screenshot ok=$($j.ok) $($j.w)x$($j.h) frame=$($j.frame)"
        }
    } catch { Write-Host "screenshot: $_" }
    Write-Host "==> stopping pid $($p.Id)"
    $p.Kill()
}

if (Test-Path $StatePath) {
    Write-Host "STATE OK: $StatePath ($((Get-Item $StatePath).Length) bytes)"
} else {
    Write-Host "STATE MISSING"
}
