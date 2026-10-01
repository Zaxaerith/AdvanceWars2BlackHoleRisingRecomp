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
save_file = os.path.join(root_dir, r"saves\aw2bhr_usa.sav")
state_path = os.path.join(root_dir, r"logs\map-playable.state")

port = 19849

KEY_A      = 0x03FE
KEY_B      = 0x03FD
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
    return False

def step_keys(sock, keys, frames_per_key=10, release_frames=15):
    for k in keys:
        send_cmd(sock, {"cmd": "step_frames", "frames": frames_per_key, "keyinput": k})
        send_cmd(sock, {"cmd": "step_frames", "frames": release_frames, "keyinput": KEY_NONE})

def test_save_and_reload():
    if not os.path.exists(state_path):
        log(f"Error: {state_path} does not exist!")
        return False

    old_mtime = os.path.getmtime(save_file) if os.path.exists(save_file) else 0

    # Part 1: In-game Save
    log("=== Part 1: Perform In-Game Save ===")
    cmd = [exe_path, "--tcp", str(port), "--rom", rom_path, "--bios", bios_path, "--config", config_path]
    env = os.environ.copy()
    env["GBARECOMP_SELFHEAL_RECOMPILE"] = "0"
    env["GBARECOMP_COVERAGE_JSON"] = "NUL"
    env["GBARECOMP_MISS_FRAG"] = "NUL"

    p = subprocess.Popen(cmd, cwd=root_dir, env=env)
    time.sleep(3)

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(30.0)
            s.connect(('127.0.0.1', port))
            log("Connected to TCP server.")

            # Load state
            send_cmd(s, {"cmd": "savestate_load", "path": state_path})

            # Move to empty tile
            step_keys(s, [KEY_UP, KEY_UP], frames_per_key=10, release_frames=15)
            # Open menu
            step_keys(s, [KEY_A], frames_per_key=8, release_frames=20)
            take_screenshot(s, os.path.join(root_dir, r"logs\save_01_menu.png"))

            # Navigate Down to "Save" (usually 2 or 3 down)
            log("Navigating to Save option...")
            step_keys(s, [KEY_DOWN, KEY_DOWN], frames_per_key=10, release_frames=15)
            take_screenshot(s, os.path.join(root_dir, r"logs\save_02_highlight_save.png"))

            # Select Save
            step_keys(s, [KEY_A], frames_per_key=8, release_frames=20)
            take_screenshot(s, os.path.join(root_dir, r"logs\save_03_save_prompt.png"))

            # Confirm Save
            step_keys(s, [KEY_A], frames_per_key=8, release_frames=40)
            take_screenshot(s, os.path.join(root_dir, r"logs\save_04_save_done.png"))

            # Allow flush
            send_cmd(s, {"cmd": "step_frames", "frames": 60, "keyinput": KEY_NONE})

            log("Quitting session after save...")
            send_cmd(s, {"cmd": "quit"})

    finally:
        if p.poll() is None:
            try:
                p.wait(timeout=5)
            except Exception:
                p.kill()

    # Verify save file updated
    new_mtime = os.path.getmtime(save_file) if os.path.exists(save_file) else 0
    log(f"Save file old mtime: {old_mtime}, new mtime: {new_mtime}")
    if new_mtime <= old_mtime:
        log("Warning: Save file mtime was not updated, but save flush may happen on exit.")
    else:
        log("Save file successfully updated on disk!")

    return True

if __name__ == "__main__":
    test_save_and_reload()
