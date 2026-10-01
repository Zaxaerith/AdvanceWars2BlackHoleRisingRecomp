@echo off
setlocal
set ROOT=D:\Project\GameRecomp\AdvanceWars2BlackHoleRisingRecomp
set EXE=%ROOT%\build\host\AdvanceWars2BlackHoleRisingRecomp.exe
cd /d %ROOT%
set GBARECOMP_SELFHEAL_RECOMPILE=0
set GBARECOMP_COVERAGE_JSON=%ROOT%\logs\to-map-cov.json
set GBARECOMP_MISS_FRAG=NUL
set GBARECOMP_INPUT_REPLAY=%ROOT%\tests\input\state-cont3.keyinput.txt
"%EXE%" --rom "Advance Wars 2 - Black Hole Rising (USA).gba" --bios "D:\Project\GameRecomp\gbarecomp-cli-windows-x86_64\gbabios\gba_bios.bin" --config "game.toml" --load-state "%ROOT%\logs\map3.state" --frames 13000 --dump-png "%ROOT%\logs\to-map.png"
echo EXIT=%ERRORLEVEL% > "%ROOT%\logs\to-map-exit.txt"
