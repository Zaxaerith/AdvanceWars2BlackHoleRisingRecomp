# Third-Party Notices

This repository contains integration code, metadata, configuration, and tools for building a native executable from a legally owned copy of **Advance Wars 2: Black Hole Rising (USA)** using the [GBARecomp](https://github.com/mstan/gbarecomp) static recompiler framework.

No proprietary ROM data, GBA BIOS binary, or generated ROM-derived C++ code is shipped in this repository.

---

## 1. GBARecomp Framework

* **Project**: [GBARecomp](https://github.com/mstan/gbarecomp)
* **Copyright**: (c) Matthew Stanley
* **License**: PolyForm Noncommercial License 1.0.0
* **Usage**: Used as the underlying GBA static recompilation framework and runtime engine. The framework is consumed as an external build dependency and is not redistributed in this repository.

---

## 2. SDL2

* **Project**: Simple DirectMedia Layer (SDL2)
* **Copyright**: (c) Sam Lantinga and contributors
* **License**: zlib License (<https://www.libsdl.org/license.php>)
* **Usage**: Windowing, display, audio output, and gamepad/keyboard input.

---

## 3. toml++

* **Project**: [toml++](https://github.com/marzer/tomlplusplus)
* **Copyright**: (c) Mark Gillard
* **License**: MIT License
* **Usage**: TOML configuration parsing for `game.toml`.

---

## 4. Decompilation Research (`Eebit/aw2bhr`)

* **Project**: [Eebit/aw2bhr](https://github.com/Eebit/aw2bhr)
* **Notice**: The upstream repository currently does not include an explicit public open-source license. Consequently, decompiled C/ASM from this project is **not redistributed** in this repository. The decompilation tree is consulted strictly as a local reference for function addresses, symbols, and hardware memory layout (`aw2bhr.lds`).

---

## 5. Game Assets & Trademarks

Advance Wars 2: Black Hole Rising is copyright (c) 1990–2003 Nintendo / Intelligent Systems. All trademarks and copyrights belong to their respective owners. This project is an independent recompilation integration intended solely for non-commercial research, personal study, and preservation purposes.
