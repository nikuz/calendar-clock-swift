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

### APP run
1. Install missing dependencies
    ```bash
    sudo apt-get install -y libdrm-dev libgbm-dev libgles2-mesa-dev libegl-dev
    ```
2. Add current user to `video` and `render` groups
    ```bash
    sudo usermod -a -G video,render $USER
    sudo reboot
    ```
3. Run
    ```bash
    .build/aarch64-unknown-linux-gnu/release/CalendarClock
    ```
