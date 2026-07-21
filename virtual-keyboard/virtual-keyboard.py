import evdev 
import time

# The exact name of your Bluetooth keyboard (find this by running 'cat /proc/bus/inp
BT_KB_NAME = "ERGO K860 Keyboard"

# Create the always-on virtual keyboard
ui = evdev.UInput(name="Raylib Virtual Keyboard")

def find_keyboard():
    devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
    for device in devices:
        if BT_KB_NAME in device.name:
            return device
    return None

print("Starting Virtual Keyboard Proxy...")

while True:
    kb = find_keyboard()
    if kb:
        print(f"Connected to {kb.name}")
        try:
            # Grab the device to exclusively read from it
            kb.grab()
            # Forward events to the virtual keyboard
            for event in kb.read_loop():
                if event.type == evdev.ecodes.EV_KEY:
                    ui.write(event.type, event.code, event.value)
                    ui.syn()
        except (IOError, evdev.device.EvdevError):
            print ("Keyboard disconnected, Waiting for reconnect...")

    # Wait before checking again
    time.sleep(2)