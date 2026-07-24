## App setup
Add essential config files:
```bash
calendar-gcloud-service-account.json
calendar-ids.json
ngrok-credentials.json
```

`calendar-gcloud-service-account.json`:
```json
{
  "type": "...",
  "project_id": "...",
  "private_key_id": "...",
  "private_key": "...",
  "client_email": "...",
  "client_id": "...",
  "auth_uri": "...",
  "token_uri": "...",
  "auth_provider_x509_cert_url": "...",
  "client_x509_cert_url": "...",
  "universe_domain": "..."
}

```
`calendar-ids.json` is a list of emails:
```json
[
    "my_first_email@gmail.com",
    "my_second_email@gmail.com"
]
```

`ngrok-credentials.json`:
```json
{
    "domainURL": "your_ngrok_public_domain_url",
    "user": "basic_auth_user",
    "password": "basic_auth_password"
}
```

## Docker setup
To build this application we need an ARM debian docker container. Building directly on a Raspberry PI board is too slow.

### Create, run, and shell into a Docker container
```bash
docker create -it --name raspberry_debian --platform linux/arm64 debian:latest /bin/bash
docker start raspberry_debian
docker exec -it -w /root raspberry_debian /bin/bash -l
```

### Swift installation
Follow the official [instruction](https://www.swift.org/install/linux/swiftly/).
<br>
DietPI is Debian, choose `Debian` option when prompted. Make sure to install requested dependencies at the end of the installation process. Also install all the required dependencies it will list at the end of the installation process.

### Install build essentials
```bash
sudo apt install build-essential
```

### RayLib compilation (optional)
1. Install `cmake`
    ```bash
    sudo apt install cmake
    ```
2. Clone RayLib
    ```bash
    git clone --depth 1 https://github.com/raysan5/raylib.git
    ```
3. Compile the library with `DRM` platform flag
    ```bash
    cd raylib && mkdir build && cd build
    cmake .. -DBUILD_SHARED_LIBS=OFF -DPLATFORM=DRM
    make
    ```

### Generate new SSH key
```bash
ssh-keygen -t ed25519 -C "your@email.com"
```

### Build the APP
1. Clone repository
    ```bash
    git clone --depth 1 https://github.com/nikuz/calendar-clock-swift.git
    ```
2. Install missing dependencies
    ```bash
    sudo apt-get install -y libdrm-dev libgbm-dev libgles2-mesa-dev libegl-dev
    ```
3. Build
    ```bash
    cd calendar-clock-swift
    . build.sh
    ```
    This should build the app and copy it to the Raspberry PI board by ssh

## Raspberry PI setup

### DietPi installation
Follow the official [instruction](https://dietpi.com/docs/install/).

### Enable DRM (Direct Rendering Manager) framebuffer
```bash
dietpi-config
```
Select `Display Options`, and make sure the `KMS/DRM` is `[On]`.

### Enable audio
```bash
dietpi-config
```
Navigate to `Audio Options`, and select `Enable: Install ALSA to enable audio capabilities`. Wait for the next screen and select `Sound card` option. On the next screen select `Onboard 3.5mm output`. 

Head back to the previous screen and make sure that the `Auto-conversion` is enabled. Exit the config and reboot.

Correct the `dtoverlay` entry in the config.txt
```bash
sudo nano /boot/firmware/config.txt
```
```diff
-dtoverlay=vc4-kms-v3d,noaudio
+dtoverlay=vc4-fkms-v3d
```

Reboot.

Make sure that `Headphones` are listed by the `aplay -l` command:
```bash
aplay -l
**** List of PLAYBACK Hardware Devices ****
card 0: Headphones [bcm2835 Headphones], device 0: bcm2835 Headphones [bcm2835 Headphones]
  Subdevices: 7/8

```

### Switch to OpenSSH for `scp` support
```bash
dietpi-software
```
Select `SSH Server` -> `OpenSSH Server`. Confirm in the prompt modal. Then select `Install` on the main DietPi-Software screen. And confirm on the next screen.

### Enable I2C bus
```bash
dietpi-config
```
Select `Advances Options`, and make sure the `I2C state` is `[On]`.

### Install missing dependencies
```bash
sudo apt-get install -y libdrm-dev libgbm-dev libgles2-mesa-dev libegl-dev
```

### Add current user to missing groups
```bash
sudo usermod -aG video,render,i2c $USER
sudo reboot
```

### Set timezone
```bash
dietpi-config
```
Select `Language/Regional Options`, and set appropriate `Timezone`

### Add Docker container SSH key to authorized_keys on the Raspberry PI board

### Install and setup ngrok
1. Follow installation [instruction](https://ngrok.com/docs/guides/device-gateway/raspberry-pi)
2. Update config to add default endpoint
    ```yaml
    version: "3"
    agent:
        authtoken: ***
    endpoints:
    - name: default
        url: https://default.internal
        upstream:
        url: 8080
    ```
3. Install auto run service
    ```bash
    sudo ngrok service install --config $HOME/.config/ngrok/ngrok.yml
    sudo ngrok service start
    ```

### Setup virtual keyboard
Raylib fails to detect Bluetooth keyboards connected after the application has launched. As a workaround, we need to set up a virtual keyboard that remains permanently available.

1. Install `python3-evdev`
    ```bash
    sudo apt install python3-evdev
    ```
2. Copy `virtual-keyboard.py` to `/home/dietpi/calendar-clock-swift`
3. Add systemd service: copy `virtual-keyboard.service` to `/etc/systemd/system/virtual-keyboard.service`
4. Enable the service
    ```bash
    sudo systemctl daemon-reload
    sudo systemctl enable virtual-keyboard.service
    sudo systemctl start virtual-keyboard.service
    ```

### Connect Bluetooth keyboard
1. Enable Bluetooth
    ```bash
    dietpi-config
    ```
    Go to `Advanced Options` and make sure that Bluetooth is `On`.
2. Pair bluetooth keyboard
    ```bash
    bluetoothctl
    scan on
    pair YOUR_DEVICE_MAC
    trust YOUR_DEVICE_MAC
    connect YOUR_DEVICE_MAC
    ```
5. Check the keyboard is working:
    ```bash
    evtest
    ```
    Select your keyboard ID and press keyboard keys to see their codes.

### Copy config files 
from repository to `/home/dietpi/calendar-clock-swift/config`

### Setup application auto run

1. Add systemd service: copy `autostart.service` to `/etc/systemd/system/calendar-clock-swift.service`
2. Enable the service
    ```bash
    sudo systemctl daemon-reload
    sudo systemctl enable calendar-clock-swift.service
    sudo systemctl start calendar-clock-swift.service
    ```
