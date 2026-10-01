import socket
import subprocess
import time
import json
import os
import sys
from PIL import Image

def log(msg):
    t = time.strftime("%H:%M:%S")
    print(f"[{t}] {msg}", flush=True)

root_dir = r"D:\Project\GameRecomp\AdvanceWars2BlackHoleRisingRecomp"
exe_path = os.path.join(root_dir, r"build\host\AdvanceWars2BlackHoleRisingRecomp.exe")
rom_path = "Advance Wars 2 - Black Hole Rising (USA).gba"
bios_path = r"D:\Project\GameRecomp\gbarecomp-cli-windows-x86_64\gbabios\gba_bios.bin"
config_path = "game.toml"
playable_state_path = os.path.join(root_dir, r"logs\map-playable.state")
log_file = os.path.join(root_dir, r"logs\test_gameplay.log")

port = 19848

# GBA Keyinput definitions (active-low: bit=0 pressed, bit=1 released)
# 0x03FF = no buttons pressed
KEY_A      = 0x03FE
KEY_B      = 0x03FD
KEY_SELECT = 0x03FB
KEY_START  = 0x03F7
KEY_RIGHT  = 0x03EF
KEY_LEFT   = 0x03DF
KEY_UP     = 0x03BF
KEY_DOWN   = 0x037F
KEY_NONE   = 0x03FF

def send_cmd(sock, c):
    msg = json.dumps(c) + "\n"
    sock.sendall(msg.encode('utf-8'))
    data = b""
    while not data.endswith(b"\n"):
        chunk = sock.recv(65536)
        if not chunk:
            break
        data += chunk
    return json.loads(data.decode('utf-8').strip())

def take_screenshot(sock, out_path):
    resp = send_cmd(sock, {"cmd": "screenshot"})
    if resp.get("ok"):
        w = resp.get("w", 240)
        h = resp.get("h", 160)
        raw_hex = resp.get("data", "")
        raw_bytes = bytes.fromhex(raw_hex)
        img = Image.frombytes("RGB", (w, h), raw_bytes)
        img.save(out_path)
        log(f"Screenshot saved: {out_path} (frame={resp.get('frame')})")
        return True
    else:
        log(f"Screenshot failed: {resp}")
        return False

def step_keys(sock, keys, frames_per_key=10, release_frames=15):
    """Step through a sequence of key presses and releases."""
    for k in keys:
        send_cmd(sock, {"cmd": "step_frames", "frames": frames_per_key, "keyinput": k})
        send_cmd(sock, {"cmd": "step_frames", "frames": release_frames, "keyinput": KEY_NONE})

def run_test():
    if not os.path.exists(playable_state_path):
        log(f"Error: {playable_state_path} does not exist yet!")
        return False

    cmd = [
        exe_path,
        "--tcp", str(port),
        "--rom", rom_path,
        "--bios", bios_path,
        "--config", config_path
    ]

    env = os.environ.copy()
    env["GBARECOMP_SELFHEAL_RECOMPILE"] = "0"
    env["GBARECOMP_COVERAGE_JSON"] = "NUL"
    env["GBARECOMP_MISS_FRAG"] = "NUL"

    log(f"Starting game with TCP port {port}...")
    p = subprocess.Popen(cmd, cwd=root_dir, env=env)
    time.sleep(3)

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(30.0)
            s.connect(('127.0.0.1', port))
            log("Connected to TCP server.")

            # Load playable state
            log(f"Loading savestate: {playable_state_path}...")
            r = send_cmd(s, {"cmd": "savestate_load", "path": playable_state_path})
            log(f"Load result: {r}")

            st = send_cmd(s, {"cmd": "run_status"})
            log(f"Initial status: {st}")

            # Baseline screenshot
            take_screenshot(s, os.path.join(root_dir, r"logs\gameplay_01_playable.png"))

            # Step 1: Select Unit under cursor (Andy's unit)
            log("Action 1: Pressing A to select unit...")
            step_keys(s, [KEY_A], frames_per_key=8, release_frames=20)
            take_screenshot(s, os.path.join(root_dir, r"logs\gameplay_02_unit_selected.png"))

            # Step 2: Move unit right 2 tiles
            log("Action 2: Moving unit Right 2 tiles...")
            step_keys(s, [KEY_RIGHT, KEY_RIGHT], frames_per_key=10, release_frames=15)
            take_screenshot(s, os.path.join(root_dir, r"logs\gameplay_03_moving.png"))

            # Step 3: Confirm move destination (opens action menu: Wait / etc.)
            log("Action 3: Pressing A to confirm destination tile...")
            step_keys(s, [KEY_A], frames_per_key=8, release_frames=20)
            take_screenshot(s, os.path.join(root_dir, r"logs\gameplay_04_action_menu.png"))

            # Step 4: Confirm action (Wait)
            log("Action 4: Pressing A to confirm action (Wait)...")
            step_keys(s, [KEY_A], frames_per_key=8, release_frames=30)
            take_screenshot(s, os.path.join(root_dir, r"logs\gameplay_05_unit_waited.png"))

            # Save state after moving unit
            log("Saving state: map-after-move.state...")
            send_cmd(s, {
                "cmd": "savestate_save",
                "path": os.path.join(root_dir, r"logs\map-after-move.state")
            })

            # Step 5: Move cursor to empty tile and open Map Menu
            log("Action 5: Navigating to empty tile and opening Map Menu...")
            step_keys(s, [KEY_UP, KEY_UP], frames_per_key=10, release_frames=15)
            step_keys(s, [KEY_A], frames_per_key=8, release_frames=20)
            take_screenshot(s, os.path.join(root_dir, r"logs\gameplay_06_map_menu.png"))

            # Step 6: Select "End Turn" (Item 1 in Map Menu) and confirm
            log("Action 6: Selecting End Turn and confirming...")
            step_keys(s, [KEY_A], frames_per_key=8, release_frames=20)   # Select "End Turn"
            take_screenshot(s, os.path.join(root_dir, r"logs\gameplay_07_end_turn_prompt.png"))
            step_keys(s, [KEY_A], frames_per_key=8, release_frames=30)   # Confirm "Yes"

            # Step 7: Wait for Enemy turn and Day 2 transition
            log("Action 7: Stepping 120 frames for enemy turn / Day 2 banner...")
            send_cmd(s, {"cmd": "step_frames", "frames": 120, "keyinput": KEY_NONE})
            take_screenshot(s, os.path.join(root_dir, r"logs\gameplay_08_day2.png"))

            # Step 8: Save game in Day 2
            log("Saving state: map-day2.state...")
            send_cmd(s, {
                "cmd": "savestate_save",
                "path": os.path.join(root_dir, r"logs\map-day2.state")
            })

            # Clean exit
            log("Test completed successfully! Sending quit...")
            send_cmd(s, {"cmd": "quit"})
            return True

    except Exception as e:
        log(f"Test error: {e}")
        return False
    finally:
        if p.poll() is None:
            try:
                p.wait(timeout=5)
            except Exception:
                p.kill()

if __name__ == "__main__":
    run_test()
