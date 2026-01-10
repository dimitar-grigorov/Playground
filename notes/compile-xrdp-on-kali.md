# Building xRDP 0.10+ on Kali Linux

Kali's default xRDP package is stuck at version 0.9.24, which lacks the GFX graphics pipeline that significantly improves performance. This guide shows how to build the latest xRDP with H.264 codec support for better remote desktop performance.

## Why build from source?

- **GFX support**: Modern graphics pipeline for smoother performance
- **H.264 codec**: Hardware-accelerated video encoding
- **Better compression**: Lower bandwidth usage, faster screen updates
- **Audio support**: Multiple codec options (MP3, Opus, AAC)

## Prerequisites

Remove the old package first:
```bash
sudo apt remove xrdp
```

Install build dependencies:
```bash
sudo apt update
sudo apt install -y build-essential git autoconf libtool pkg-config \
    libssl-dev libpam0g-dev libjpeg-dev libx11-dev libxfixes-dev libxrandr-dev \
    nasm libfuse-dev libmp3lame-dev libopus-dev libfdk-aac-dev \
    libx264-dev libpixman-1-dev libimlib2-dev libfuse3-dev libxkbfile-dev
```

## Build xRDP

```bash
cd ~/source
git clone --recursive https://github.com/neutrinolabs/xrdp.git
cd xrdp
./bootstrap
./configure --with-systemdsystemunitdir=/usr/lib/systemd/system \
    --enable-ipv6 --enable-jpeg --enable-fuse --enable-mp3lame \
    --enable-fdkaac --enable-opus --enable-rfxcodec --enable-painter \
    --enable-pixman --enable-utmp --with-imlib2 --with-freetype2 \
    --enable-x264 --enable-vsock --enable-sound
make -j$(nproc)
sudo make install
```

## Build xorgxrdp

```bash
cd ~/source
git clone --recursive https://github.com/neutrinolabs/xorgxrdp.git
cd xorgxrdp
sudo apt install xserver-xorg-dev
./bootstrap
./configure --with-simd
make -j$(nproc)
sudo make install
```

## Start the service

```bash
sudo systemctl daemon-reload
sudo systemctl enable xrdp
sudo systemctl start xrdp
```

Verify installation:
```bash
xrdp --version
```

## Performance tips

Disable window compositing for better performance:
```bash
xfconf-query -c xfwm4 -p /general/use_compositing -t bool -s false
```
## Notes
- Default port is 3389
- TLS encryption enabled by default
- Compatible with Windows built-in RDP client (mstsc.exe)