<#
    tools/regen.ps1 — regenerate cartridge and BIOS translation from verified inputs.

    Gates before any generation:
      1. exactly one *.gba in the project root
      2. its MD5/SHA-1/SHA-256 match baserom.md / game.toml
      3. the BIOS dump's SHA-1 matches game.toml [bios].sha1

    Outputs (local-only, gitignored):
        generated/cart/   recompiled_*.cpp, dispatch_table.cpp, ...
        generated/bios/   bios_recompiled.cpp, bios_dispatch_table.cpp, ...
#>
[CmdletBinding()]
param(
    [string]$Bios,
    [string]$Generator,
    [int]$MaxFunctions = 65536,
    [switch]$CartOnly
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$LogDir = Join-Path $Root 'logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Step($m) { Write-Host "==> $m" }
function Fail($m) { throw $m }

# ---------------------------------------------------------------- ROM identity
$roms = @(Get-ChildItem -LiteralPath $Root -Filter '*.gba' -File)
if ($roms.Count -ne 1) { Fail "Expected exactly one .gba in $Root, found $($roms.Count)." }
$rom = $roms[0].FullName

$wantSha1 = '14dd0b22c894865867aff89e8116b2dffae25605'
$wantMd5  = '46599031ef71117c587bd3666c326c07'
$wantSha256 = 'ef3cc89273f9df88020f07751ea6306b25c39df01893822fe431550eedf9b134'
$wantSize = 8388608

$have = @{
    md5    = (Get-FileHash $rom -Algorithm MD5).Hash.ToLower()
    sha1   = (Get-FileHash $rom -Algorithm SHA1).Hash.ToLower()
    sha256 = (Get-FileHash $rom -Algorithm SHA256).Hash.ToLower()
}
if ($have.md5 -ne $wantMd5)    { Fail "ROM md5 mismatch: $($have.md5)" }
if ($have.sha1 -ne $wantSha1)  { Fail "ROM sha1 mismatch: $($have.sha1)" }
if ($have.sha256 -ne $wantSha256) { Fail "ROM sha256 mismatch: $($have.sha256)" }
$size = (Get-Item $rom).Length
if ($size -ne $wantSize) { Fail "ROM size mismatch: $size" }
Step "ROM verified: $([System.IO.Path]::GetFileName($rom))  sha1=$($have.sha1)"

# ------------------------------------------------------------------- generator
if (-not $Generator) {
    $candidates = @(
        (Join-Path $Root '.deps\gba_recompile.exe'),
        (Join-Path (Split-Path -Parent $Root) 'gbarecomp-main\build-vs\Release\gba_recompile.exe'),
        (Join-Path (Split-Path -Parent $Root) 'gbarecomp-main\build-mingw\gba_recompile.exe')
    )
    $Generator = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $Generator -or -not (Test-Path $Generator)) {
    Fail 'gba_recompile.exe not found. Build gbarecomp-main target gba_recompile, or pass -Generator.'
}
Step "generator: $Generator"

# ------------------------------------------------------------------------ BIOS
if (-not $Bios) {
    $shared = Split-Path -Parent $Root
    $candidates = @(
        (Join-Path $Root 'bios\gba_bios.bin'),
        (Join-Path $shared 'gbarecomp-cli-windows-x86_64\gbabios\gba_bios.bin')
    )
    $Bios = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $CartOnly) {
    if (-not $Bios) { Fail 'No BIOS dump. Pass -Bios <path> or place bios/gba_bios.bin.' }
    $biosSha1 = (Get-FileHash $Bios -Algorithm SHA1).Hash.ToLower()
    if ($biosSha1 -ne '300c20df6731a33952ded8c436f7f186d25d3492') {
        Fail "BIOS SHA-1 mismatch: $biosSha1"
    }
    Step "BIOS verified: $Bios"
}

$config = Join-Path $Root 'game.toml'
$frameworkBiosToml = Join-Path (Split-Path -Parent $Root) 'gbarecomp-main\bios\gba_bios.toml'

# ----------------------------------------------------------------- cartridge
$cartOut = Join-Path $Root 'generated\cart'
if (Test-Path $cartOut) {
    Get-ChildItem -LiteralPath $cartOut -Force | Remove-Item -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $cartOut | Out-Null
$cartLog = Join-Path $LogDir 'host-cart-generation.log'
Step "cartridge generation -> $cartOut"
& $Generator --rom $rom --config $config --out $cartOut --max-functions $MaxFunctions *>&1 |
    Tee-Object -FilePath $cartLog
if ($LASTEXITCODE -ne 0) { Fail "Cartridge generation failed (exit $LASTEXITCODE); see $cartLog" }
foreach ($f in @('recompiled.h', 'dispatch_table.cpp')) {
    if (-not (Test-Path (Join-Path $cartOut $f))) { Fail "Cartridge generation produced no $f" }
}
$shards = @(Get-ChildItem -LiteralPath $cartOut -Filter 'recompiled_*.cpp' -File)
if ($shards.Count -lt 1) { Fail 'Cartridge generation produced no recompiled_*.cpp shard' }
Step "cartridge shards: $($shards.Count)"

# ----------------------------------------------------------------------- BIOS
if (-not $CartOnly) {
    $biosOut = Join-Path $Root 'generated\bios'
    if (Test-Path $biosOut) {
        Get-ChildItem -LiteralPath $biosOut -Force | Remove-Item -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $biosOut | Out-Null
    $biosLog = Join-Path $LogDir 'host-bios-generation.log'
    Step "BIOS generation -> $biosOut"
    & $Generator --bios $Bios --config $frameworkBiosToml --out $biosOut *>&1 |
        Tee-Object -FilePath $biosLog
    if ($LASTEXITCODE -ne 0) { Fail "BIOS generation failed (exit $LASTEXITCODE); see $biosLog" }
    if (-not (Test-Path (Join-Path $biosOut 'bios_recompiled.cpp'))) {
        Fail 'BIOS generation produced no bios_recompiled.cpp'
    }
    $tailMacros = Join-Path (Split-Path -Parent $Root) 'gbarecomp-main\src\runtime\generated_bios\codegen_tail_macros.h'
    if (Test-Path $tailMacros) {
        Copy-Item $tailMacros (Join-Path $biosOut 'codegen_tail_macros.h') -Force
    }
    Step 'BIOS translation ready'
}

Step 'regeneration complete'
