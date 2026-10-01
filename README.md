# AdvanceWars2BlackHoleRisingRecomp

> **Status: Experimental Preview**  
> Decomp-assisted static recompilation of **Advance Wars 2: Black Hole Rising (USA, Game Code: AW2E)** via [GBARecomp](https://github.com/mstan/gbarecomp) targeting native Windows x64.

This repository provides the **game integration layer**: recompiler configuration, host integration, hardware bindings, and build automation. It does **not** distribute copyrighted ROM files, GBA BIOS dumps, or ROM-derived generated C++ code. Users provide their own legally acquired game ROM locally.

---

## Verified Milestones & Current Status

* [x] **Clean Native Build**: 64-bit Windows binary built with MinGW-w64, CMake, and Ninja (`AdvanceWars2BlackHoleRisingRecomp.exe`).
* [x] **BIOS / Cold Boot**: LLE BIOS reset and boot verified (`gba_bios.bin`).
* [x] **Title Screen**: Nintendo / Intelligent Systems intro logos and Title Screen ("PRESS START!") verified (`logs/frame-3600.png`).
* [x] **Main Menu & Prologue**: Main menu navigation and Campaign prologue ("Macro Land...") verified (`logs/frame-menu.png`).
* [x] **World Map & CO Select**: Campaign world map and CO selection screen (Andy) verified (`logs/frame-21k.png`).
* [x] **Playable Map (Mission 1)**: First campaign mission reached with intro dialogue (`logs/to-map.png`) and in-mission command menu (CO / Intel / Options / Save / End) confirmed (`logs/frame-map.png`).
* [x] **Audio System**: m4a / MP2K sound driver running stably with dedicated interpreter bridge bounds; no host call-return stack overflow.
* [x] **Save Hardware**: Cartridge Flash 64 KB (512 Kbit) header signature recognized and mapped to persistent disk storage (`saves/aw2bhr_usa.sav`).

### Scope & Untested Areas (Community Testing)

This project prioritizes rapid playable integration over exhaustive brute-force test coverage. The following areas remain open for community testing:
* Extensive multi-mission campaign playthroughs.
* Hard Campaign and War Room scenarios.
* Multiplayer / Link Cable emulation.
* Full edge-case battle animation scripts.

---

## Prerequisites

1. **Base ROM**:
   * Advance Wars 2: Black Hole Rising (USA)
   * SHA-1: `14dd0b22c894865867aff89e8116b2dffae25605`
   * Place the `.gba` file in the project root directory. See [baserom.md](baserom.md) for full identity details.
2. **GBA BIOS**:
   * Verified GBA BIOS dump (16,384 bytes, SHA-1 `300c20df6731a33952ded8c436f7f186d25d3492`).
3. **Build Environment**:
   * MinGW-w64 (GCC 13+ or Clang with C++20 support)
   * CMake 3.20+ and Ninja
   * SDL2 development libraries for MinGW (`x86_64-w64-mingw32`)
   * [GBARecomp](https://github.com/mstan/gbarecomp) framework and CLI generator (`gba_recompile.exe`)

---

## Quick Start

### 1. Regeneration

Run the automated regeneration script to verify ROM SHA-1 and generate the static translation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\regen.ps1
```

### 2. Compilation

Configure and build the native executable using CMake:

```powershell
cmake -S . -B build\host -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build\host --target AdvanceWars2BlackHoleRisingRecomp --parallel
```

### 3. Launching

Launch the recompiled executable:

```powershell
.\build\host\AdvanceWars2BlackHoleRisingRecomp.exe
```

---

## Repository Structure

```text
AdvanceWars2BlackHoleRisingRecomp/
├── .gitignore               # Ignores ROMs, BIOS, saves, generated code, build trees
├── CMakeLists.txt           # Build definition linking gbarecomp runtime & host
├── LICENSE                  # PolyForm Noncommercial License 1.0.0
├── README.md                # Project documentation & status
├── THIRD_PARTY_NOTICES.md   # Third-party component attributions & decomp licensing audit
├── baserom.md               # ROM / BIOS identity specifications & verification
├── game.toml                # Core recompiler & runtime configuration
├── src/
│   └── main.cpp             # Host entry point and hardware hooks
├── tests/
│   └── input/               # Replay route key sequences for deterministic smoke testing
└── tools/
    ├── regen.ps1            # Hash-gated code generation runner
    └── run-to-map.cmd       # Deterministic headless route runner
```

---

## Licenses & Third-Party Code

* **Integration Code**: Licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE).
* **Framework**: Built on [GBARecomp](https://github.com/mstan/gbarecomp) by Matthew Stanley.
* **Decompilation Reference**: Function names, symbols, and layout informed by [Eebit/aw2bhr](https://github.com/Eebit/aw2bhr). No copyrighted decomp code is distributed.
* **Game Copyright**: Advance Wars 2: Black Hole Rising is (c) 1990–2003 Nintendo / Intelligent Systems.
* See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for full notices and acknowledgments.
