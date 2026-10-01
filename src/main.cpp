// Advance Wars 2: Black Hole Rising (USA, AW2E) — host integration entry point.
//
// Thin host layer: the framework runtime owns the window, audio device, input
// mapping, save handling, launcher UI, debug TCP server and the ARM
// CPU/bus/PPU lifecycle. See gbarecomp-main/src/runtime/runtime.h.

#include "runtime.h"
#include "runtime_arm.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>

#ifdef _WIN32
#include <windows.h>
#include <shellapi.h>
#endif

namespace {

// ---------------------------------------------------------------------------
// Recursion probe.
//
// The static backend nests runtime_dispatch -> entry->fn() on the host stack.
// An unbounded guest call chain is an infinite C++ recursion (overflows even a
// 128 MiB stack). Sample generated-function entries so the repeating PC is
// visible before the process dies.
//
// run_game() nulls g_runtime_fn_entry_hook at startup, so the probe is
// installed lazily from the force-interp hook (which is NOT cleared on entry).
// ---------------------------------------------------------------------------

std::uint32_t g_last_fn_pc = 0;
unsigned g_fn_repeat = 0;
unsigned long long g_fn_entries = 0;

extern "C" void aw2bhr_fn_entry_hook(std::uint32_t pc) {
    ++g_fn_entries;
    if (pc == g_last_fn_pc) ++g_fn_repeat;
    else { g_last_fn_pc = pc; g_fn_repeat = 0; }

    // Tight self-recursion: same PC entered over and over without a callee.
    if (g_fn_repeat == 20000u) {
        std::fprintf(stderr,
                     "[aw2] RECURSION pc=0x%08x entries=%llu (tight)\n",
                     pc, g_fn_entries);
        std::fflush(stderr);
    }
    // Periodic sample so A->B->A->B style cycles also show up. Very sparse:
    // the hook is hot (200M+ entries per long run) and fprintf dominates.
    if ((g_fn_entries & 0x7FFFFFull) == 0) {
        std::fprintf(stderr, "[aw2] fn_entry #%llu pc=0x%08x repeat=%u\n",
                     g_fn_entries, pc, g_fn_repeat);
        std::fflush(stderr);
    }
}

extern "C" int aw2bhr_force_interp_hook(uint32_t pc, int /*thumb*/) {
    // Lazy install: run_game clears fn_entry_hook at startup.
    if (std::getenv("GBARECOMP_AW2_FN_TRACE") &&
        g_runtime_fn_entry_hook != &aw2bhr_fn_entry_hook)
        g_runtime_fn_entry_hook = &aw2bhr_fn_entry_hook;

    // Dynamic IWRAM data/scratch that has been observed as a dispatch target.
    if (pc >= 0x03000F00u && pc < 0x03001200u) return 1;
    // Stack-stub band just below crt0 system stack (0x03007E00).
    if (pc >= 0x03007C00u && pc < 0x03007E00u) return 1;
    // Dynamic EWRAM overlays / heap code (same policy as GoldenSun).
    if (pc >= 0x02000000u && pc < 0x02040000u) return 1;
    // Callback-table runners sub_08011AD8 / sub_08011B98. Required: loop-head
    // roots nested runtime_call_push_return to the 1024 cap.
    if (pc >= 0x08011AD0u && pc < 0x08011C00u) return 1;
    // m4a/MP2K SoundMain @ 0x0806FDE4 + callees. Without this the call-return
    // stack overflows at 0x0806FE24 before the first map. Cost: slow boots.
    // Keep for the one-time map.state capture; revisit after savestate exists.
    if (pc >= 0x0806F000u && pc < 0x08071000u) return 1;
    // IrqMain — required for long campaign runs (overflow after IrqMain resume).
    if (pc >= 0x080000FCu && pc < 0x08000220u) return 1;
    return 0;
}

#ifdef _WIN32
// Pre-allocated crash scratch: stack overflow leaves almost no stack.
char g_crash_line[256];

LONG WINAPI aw2bhr_vectored_handler(EXCEPTION_POINTERS* ep) {
    const DWORD code = ep->ExceptionRecord->ExceptionCode;
    if (code != EXCEPTION_STACK_OVERFLOW && code != 0xC00000FDu)
        return EXCEPTION_CONTINUE_SEARCH;
    const int n = std::snprintf(
        g_crash_line, sizeof(g_crash_line),
        "[aw2] STACK_OVERFLOW rip=0x%p last_fn=0x%08x entries=%llu repeat=%u\n",
        reinterpret_cast<void*>(ep->ContextRecord->Rip),
        g_last_fn_pc, g_fn_entries, g_fn_repeat);
    if (n > 0) {
        DWORD written = 0;
        HANDLE err = GetStdHandle(STD_ERROR_HANDLE);
        if (err && err != INVALID_HANDLE_VALUE)
            WriteFile(err, g_crash_line, static_cast<DWORD>(n), &written, nullptr);
    }
    return EXCEPTION_CONTINUE_SEARCH;
}
#endif

int run(int argc, char** argv) {
    // Quiet by default for normal play; leave diagnostics opt-in via env.
    if (!std::getenv("GBARECOMP_SELFHEAL_RECOMPILE"))
        _putenv("GBARECOMP_SELFHEAL_RECOMPILE=0");
    if (!std::getenv("GBARECOMP_MISS_FRAG"))
        _putenv("GBARECOMP_MISS_FRAG=NUL");
    if (!std::getenv("GBARECOMP_COVERAGE_JSON"))
        _putenv("GBARECOMP_COVERAGE_JSON=NUL");
    if (!std::getenv("GBARECOMP_SESSION_DIAGNOSTICS"))
        _putenv("GBARECOMP_SESSION_DIAGNOSTICS=0");

#ifdef _WIN32
    AddVectoredExceptionHandler(1, &aw2bhr_vectored_handler);
#endif

    // force_interp survives run_game's entry; fn_entry is re-installed lazily
    // and only when diagnostics are requested (the hook is extremely hot).
    g_runtime_force_interp_hook = &aw2bhr_force_interp_hook;
    if (std::getenv("GBARECOMP_AW2_FN_TRACE"))
        g_runtime_fn_entry_hook = &aw2bhr_fn_entry_hook;

    gbarecomp::RunOptions options{};
    options.builtin_game_name = "Advance Wars 2: Black Hole Rising";
    options.builtin_rom_sha1 = "14dd0b22c894865867aff89e8116b2dffae25605";
    options.builtin_rom_crc32 = 0xF3A10E24;
    options.freely_resizable_window = false;
    options.expose_assist_tools = false;
    return gbarecomp::run_game(argc, argv, options);
}

}  // namespace

#ifdef _WIN32
int WINAPI WinMain(HINSTANCE, HINSTANCE, LPSTR, int) {
    int argc = 0;
    LPWSTR* argv_w = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (!argv_w) return 1;

    char** argv = static_cast<char**>(HeapAlloc(
        GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(char*) * (argc + 1)));
    if (!argv) return 1;
    for (int i = 0; i < argc; ++i) {
        int len = WideCharToMultiByte(CP_UTF8, 0, argv_w[i], -1, nullptr, 0, nullptr, nullptr);
        argv[i] = static_cast<char*>(HeapAlloc(GetProcessHeap(), 0, static_cast<SIZE_T>(len)));
        if (!argv[i]) return 1;
        WideCharToMultiByte(CP_UTF8, 0, argv_w[i], -1, argv[i], len, nullptr, nullptr);
    }
    return run(argc, argv);
}
#else
int main(int argc, char** argv) {
    return run(argc, argv);
}
#endif
