# baserom.md — required base ROM

This project is a **recompilation**, not a ROM distribution. No ROM, no GBA BIOS
and no ROM-derived generated code is stored in the repository. The user supplies
the base ROM locally; every generation and validation run starts by re-verifying
the bytes below.

## Required input

| item | value |
| --- | --- |
| file | `Advance Wars 2 - Black Hole Rising (USA).gba` in `PROJECT_ROOT` (the only `*.gba` there) |
| region | USA |
| game code | `AW2E` |
| internal title | `ADVANCEWARS2` |
| maker code | `01` |
| software version (`0xBC`) | `0x00` |
| size | 8,388,608 bytes (`0x00800000`) |
| MD5 | `46599031ef71117c587bd3666c326c07` |
| SHA-1 | `14dd0b22c894865867aff89e8116b2dffae25605` |
| SHA-256 | `ef3cc89273f9df88020f07751ea6306b25c39df01893822fe431550eedf9b134` |
| CRC32 | `0xF3A10E24` |
| ARM entry point | file offset `0x000` = `0xEA00002E` → `0x080000C0` |

The SHA-1 matches the `Eebit/aw2bhr` target ROM (`aw2bhr.sha1`) and the
no-intro USA dump, so decomp addresses from that tree are valid version
references for this image.

## How the identity is enforced

| gate | where |
| --- | --- |
| hard hash check inside the generator | `game.toml` `[identity] sha1 = "14dd0b22c894865867aff89e8116b2dffae25605"` |
| ROM SHA-1 before generation | `tools/regen.ps1` |
| runtime ROM re-hash | `game.toml` `[rom] sha1` |

A mismatch aborts before anything is generated; the runtime refuses to boot a
different image.

## Save hardware

Evidence, not guesswork:

* ASCII `FLASH_V126` at file offset `0x485480` (bare `FLASH_V`, no `512`/`1M` prefix).
* Framework ROM-signature detector maps bare `FLASH_V` → Flash 64 KB (512 Kbit)
  (`gbarecomp-main/src/gba/gba_rom_header.cpp`).
* No `SRAM_V*`, `FLASH512_V*`, `FLASH1M_V*` or `EEPROM_V*` strings in the image.

`game.toml` therefore starts at `type = "flash512"` / `size = 65536`. This is
**not** yet validated by a full in-game save → restart → load cycle; if the
cartridge driver probes a 1 Mbit chip at runtime, switch to `flash1m` / `131072`
after confirming against actual save traffic.

## BIOS

The GBA BIOS is **not** in this repository. `bios/gba_bios.bin` (16,384 bytes,
SHA-1 `300c20df6731a33952ded8c436f7f186d25d3492`) is a local, git-ignored copy.
A verified dump is available locally at
`D:\Project\GameRecomp\gbarecomp-cli-windows-x86_64\gbabios\gba_bios.bin`.

## Decompilation

`Eebit/aw2bhr`, pinned commit `63a26942a9a1249fe4e02c4c2ec0b3d2ee6b16cb`
(local clone `third_party/aw2bhr`, gitignored). Early-stage tree
(`src/crt0.s`, `src/proc.c`, `src/rom-header.s`, `src/title-screen.c`,
`asm/`, `data/`, `aw2bhr.lds`). Used for names / boundaries / address facts —
never as an execution oracle. **No public LICENSE at upstream root**: any
copied C/ASM stays local-only and is not re-licensed by this project.

## Local-only material (never committed)

ROM, BIOS, saves, `build/`, `generated/`, `recomp_cache/`, debug dumps, traces.
See `.gitignore`.
