# ---------------------------------------------------------------------------
# AdvanceWars2BlackHoleRisingRecomp — host executable.
#
# Shape (thin host, shared local framework):
#   ../gbarecomp-main     framework source (read-only, add_subdirectory)
#   generated/cart        cartridge translation   (tools/regen.ps1, local-only)
#   generated/bios        BIOS translation        (tools/regen.ps1, local-only)
#   src/main.cpp          game-specific host layer
#
# Configure (MinGW + Ninja, matching sibling projects):
#   cmake -S . -B build/host -G Ninja -DCMAKE_BUILD_TYPE=Release
#   cmake --build build/host
# ---------------------------------------------------------------------------
cmake_minimum_required(VERSION 3.20)
project(AdvanceWars2BlackHoleRisingRecomp C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

# ---------------------------------------------------------------- framework
if(NOT GBARECOMP_ROOT)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/reference/gbarecomp/CMakeLists.txt")
        set(GBARECOMP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/reference/gbarecomp")
    elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../gbarecomp-main/CMakeLists.txt")
        set(GBARECOMP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../gbarecomp-main")
    else()
        set(GBARECOMP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/gbarecomp")
    endif()
endif()
if(NOT EXISTS "${GBARECOMP_ROOT}/CMakeLists.txt")
    message(FATAL_ERROR "GBARECOMP_ROOT not found: ${GBARECOMP_ROOT}")
endif()
message(STATUS "AW2Recomp: framework ${GBARECOMP_ROOT}")

set(GBARECOMP_GENERATED_BIOS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/generated/bios"
    CACHE PATH "Local BIOS translation")

# ----------------------------------------------------------------- generated
file(GLOB CART_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/generated/cart/*.cpp")
if(NOT CART_SOURCES)
    message(FATAL_ERROR
        "No cartridge translation in generated/cart. Run tools/regen.ps1 first.")
endif()
if(NOT EXISTS "${GBARECOMP_GENERATED_BIOS_DIR}/bios_recompiled.cpp")
    message(FATAL_ERROR
        "No BIOS translation in ${GBARECOMP_GENERATED_BIOS_DIR}. Run tools/regen.ps1 first.")
endif()

# --------------------------------------------------------------------- SDL2
set(_gba_sdl2_candidates
    "${GBARECOMP_MINGW_PREFIX_UNIX}"
    "$ENV{SDL2_ROOT}"
    "${CMAKE_CURRENT_SOURCE_DIR}/.deps/sdl2/x86_64-w64-mingw32"
    "D:/Project/GameRecomp/_sdl2/SDL2-2.32.8/x86_64-w64-mingw32"
    "C:/msys64/mingw64"
)
file(GLOB _gba_sdl2_siblings "${CMAKE_CURRENT_SOURCE_DIR}/../_sdl2/SDL2-*/x86_64-w64-mingw32")
list(APPEND _gba_sdl2_candidates ${_gba_sdl2_siblings})
set(_gba_sdl2_root "")
foreach(_cand IN LISTS _gba_sdl2_candidates)
    if(_cand AND EXISTS "${_cand}/include/SDL2/SDL.h")
        set(_gba_sdl2_root "${_cand}")
        break()
    endif()
endforeach()
if(NOT GBARECOMP_MINGW_PREFIX_UNIX)
    if(_gba_sdl2_root)
        set(GBARECOMP_MINGW_PREFIX_UNIX "${_gba_sdl2_root}" CACHE PATH
            "SDK root used by the framework to locate SDL2" FORCE)
    else()
        message(WARNING "No SDL2 SDK found; host_window may compile as a stub.")
    endif()
endif()
if(_gba_sdl2_root)
    message(STATUS "AW2Recomp: SDL2 SDK root ${_gba_sdl2_root}")
endif()

if(NOT GBARECOMP_MINGW_RUNTIME_BIN AND MINGW)
    get_filename_component(_gba_mingw_bin "${CMAKE_CXX_COMPILER}" DIRECTORY)
    set(GBARECOMP_MINGW_RUNTIME_BIN "${_gba_mingw_bin}" CACHE PATH
        "Directory holding MinGW runtime DLLs")
endif()

# ----------------------------------------------------------------- framework
add_subdirectory("${GBARECOMP_ROOT}" framework EXCLUDE_FROM_ALL)

# ---------------------------------------------------------------- executable
add_executable(AdvanceWars2BlackHoleRisingRecomp WIN32 src/main.cpp ${CART_SOURCES})
target_link_gbarecomp_runtime_stack(AdvanceWars2BlackHoleRisingRecomp)

# Interpreter-bridge paths can nest deeply on IRQ + SWI + game call chains;
# the MinGW default 1 MiB stack overflows around frame 334 (0xC00000FD).
# 128 MiB: diagnostic ceiling while the static-ABI nest is still unbounded.
if(MINGW)
    target_link_options(AdvanceWars2BlackHoleRisingRecomp PRIVATE
        "-Wl,--stack,134217728")
endif()

# Generated shards: translation output, but they ARE the guest CPU hot path.
# -O2: -O1 measured ~85 ms/frame even on a FULLY_STATIC BIOS intro.
set(_gba_shards ${CART_SOURCES})
list(FILTER _gba_shards INCLUDE REGEX "/recompiled_[0-9]+\\.cpp$")
if(_gba_shards)
    if(MSVC)
        set_source_files_properties(${_gba_shards} PROPERTIES COMPILE_OPTIONS "/O2")
    else()
        set_source_files_properties(${_gba_shards} PROPERTIES COMPILE_OPTIONS "-O2;-g0")
    endif()
endif()
