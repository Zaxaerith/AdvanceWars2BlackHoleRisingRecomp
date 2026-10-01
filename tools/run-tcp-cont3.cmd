@echo off
setlocal
set ROOT=D:\Project\GameRecomp\AdvanceWars2BlackHoleRisingRecomp
set EXE=%ROOT%\build\host\AdvanceWars2BlackHoleRisingRecomp.exe
cd /d %ROOT%
set GBARECOMP_SELFHEAL_RECOMPILE=0
set GBARECOMP_COVERAGE_JSON=NUL
set GBARECOMP_MISS_FRAG=NUL
set GBARECOMP_INPUT_REPLAY=%ROOT%\tests\input\state-cont3.keyinput.txt
"%EXE%" --tcp 19845 --rom "Advance Wars 2 - Black Hole Rising (USA).gba" --bios "D:\Project\GameRecomp\gbarecomp-cli-windows-x86_64\gbabios\gba_bios.bin" --config "game.toml" --load-state "%ROOT%\logs\map3.state"
