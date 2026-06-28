## Raspberry PI setup

### DietPi installation
Follow the official [instruction](https://dietpi.com/docs/install/).

### Enable DRM (Direct Rendering Manager) framebuffer
```bash
dietpi-config
```
Select `Display Options`, and make sure the `KMS/DRM` is `[On]`.

### Swift installation
Follow the official [instruction](https://www.swift.org/install/linux/swiftly/).
<br>
DietPI is Debian, choose `Debian` option when prompted. Make sure to install requested dependencies at the end of the installation process.

> [!NOTE]
> Install swift under `dietpi` user. 

### RayLib compilation (optional)
1. Install `cmake` and build essentials
    ```bash
    sudo apt install cmake build-essential
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

### Enable I2C bus
```bash
dietpi-config
```
Select `Advances Options`, and make sure the `I2C state` is `[On]`.

### APP run
1. Clone repository
    ```bash
    git clone --depth 1 https://github.com/nikuz/calendar-clock-swift.git
    ```
2. Install missing dependencies
    ```bash
    sudo apt-get install -y libdrm-dev libgbm-dev libgles2-mesa-dev libegl-dev
    ```
3. Add current user to `video` and `render` groups
    ```bash
    sudo usermod -a -G video,render $USER
    sudo reboot
    ```
4. Build
    ```bash
    cd calendar-clock-swift
    swift build -c release
    ```
5. Run
    ```bash
    .build/release/CalendarClock
    ```
