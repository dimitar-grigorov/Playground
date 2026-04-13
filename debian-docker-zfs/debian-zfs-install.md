# Debian Trixie — ZFS Root Homelab Server Guide

Based on the official OpenZFS guide:
https://openzfs.github.io/openzfs-docs/Getting%20Started/Debian/Debian%20Trixie%20Root%20on%20ZFS.html

This is a corrected and extended version. The original guide works but has several
gaps that will bite you on a real install. This document covers Part 1 — the OS
installation. Part 2 covers Docker, data disks, automatic snapshots, and remote
backups.

---

## What you'll end up with

You have a mini PC, old laptop, or repurposed desktop sitting somewhere and you
want to actually use it. Run Nextcloud, Home Assistant, Frigate, whatever. Have
things not break catastrophically when you mess something up. Be able to roll back
accidentally deleted files. Send backups somewhere else automatically. Recover
after a disk dies without starting from scratch.

ZFS makes most of that possible out of the box. The tricky part is getting Debian
to boot from it, which is what this guide is for.

After Part 1 you'll have a working Debian 13 server booting off ZFS. After Part 2
you'll have:
- Docker volumes that can be snapshotted hourly and rolled back with one command
- Snapshots automatically replicated to a remote machine over SSH
- A recovery path that actually works after hardware failure

**Hardware:** any x86-64 machine, single SSD as system disk, minimum 2 GB RAM
(4 GB+ recommended). Additional data disks are set up in Part 2.

---

## Part 1 — OS Installation

---

## Step 1 — Prepare Live Environment

Boot from Debian Live ISO (64-bit, GUI), open a terminal.

```bash
sudo -i

echo "deb http://deb.debian.org/debian trixie main contrib non-free-firmware" \
    > /etc/apt/sources.list
apt update

apt install --yes linux-headers-generic debootstrap gdisk \
    zfsutils-linux dosfstools parted

# If using GNOME desktop, disable automount to prevent interference with target disk
gsettings set org.gnome.desktop.media-handling automount false
```

---

## Step 2 — Set Disk Variable

Always use `/dev/disk/by-id/` paths. `/dev/sda` style names can change between
reboots — by-id paths are tied to the hardware and stay stable.

```bash
ls -la /dev/disk/by-id/ | grep -v part | grep -v wwn
# Find the alias for your target disk

DISK=/dev/disk/by-id/ata-YOUR_DISK_ID
echo $DISK   # verify before continuing
```

---

## Step 3 — Partition the Disk

```bash
swapoff --all
wipefs -a $DISK
blkdiscard -f $DISK
sgdisk --zap-all $DISK

sgdisk -a1 -n1:24K:+1000K  -t1:EF02 $DISK   # BIOS legacy fallback
sgdisk     -n2:1M:+512M     -t2:EF00 $DISK   # EFI partition
sgdisk     -n3:0:+2G        -t3:BF01 $DISK   # ZFS boot pool
sgdisk     -n4:0:0          -t4:BF00 $DISK   # ZFS root pool

partprobe $DISK
sleep 2
lsblk $DISK
```

---

## Step 4 — Format EFI Partition

Do this now, in the live environment. The original guide puts it inside chroot,
where `mkdosfs` may not be available yet.

```bash
mkdosfs -F 32 -s 1 -n EFI ${DISK}-part2
```

---

## Step 5 — Create ZFS Pools

```bash
# Boot pool — limited feature set required by GRUB2
zpool create \
    -o ashift=12 -o autotrim=on \
    -o compatibility=grub2 \
    -o cachefile=/etc/zfs/zpool.cache \
    -O devices=off \
    -O acltype=posixacl -O xattr=sa \
    -O compression=lz4 \
    -O normalization=formD \
    -O relatime=on \
    -O canmount=off -O mountpoint=/boot -R /mnt \
    bpool ${DISK}-part3

# Root pool — full features
# zstd is preferred over lz4 since ZFS 2.0: better ratio, similar speed on modern CPUs
# bpool above must stay lz4 — grub2 compatibility mode doesn't include zstd
zpool create \
    -o ashift=12 -o autotrim=on \
    -O acltype=posixacl -O xattr=sa -O dnodesize=auto \
    -O compression=zstd \
    -O normalization=formD \
    -O relatime=on \
    -O canmount=off -O mountpoint=/ -R /mnt \
    rpool ${DISK}-part4
```

---

## Step 6 — Create ZFS Datasets

In ZFS, datasets are like independent filesystems inside a pool. Each one has its
own snapshot history, compression settings, and quotas. The reason you split
directories into separate datasets is so you can manage them independently — snapshot
`/var/log` without touching the OS, roll back Docker data while keeping your home
directory intact, or prevent a runaway log from filling the entire root.

```bash
# Organisational containers — not mounted themselves
zfs create -o canmount=off -o mountpoint=none rpool/ROOT
zfs create -o canmount=off -o mountpoint=none bpool/BOOT

# Root and boot filesystems
zfs create -o canmount=noauto -o mountpoint=/ rpool/ROOT/debian
zfs mount rpool/ROOT/debian
zfs create -o mountpoint=/boot bpool/BOOT/debian

# Home directories — separate dataset per user allows per-user snapshots/quotas
zfs create                     rpool/home
zfs create -o mountpoint=/root rpool/home/root
chmod 700 /mnt/root

# /var — split so logs and cache don't share snapshot history with the OS
zfs create -o canmount=off     rpool/var
zfs create -o canmount=off     rpool/var/lib
zfs create                     rpool/var/log

# /var/tmp is persistent temp storage (survives reboots, unlike /tmp which is tmpfs).
# Package managers dump large files here during upgrades — excluding it from
# snapshots prevents those from showing up in your backup history.
zfs create -o com.sun:auto-snapshot=false rpool/var/tmp
chmod 1777 /mnt/var/tmp

# Cache is always safe to wipe and gets rebuilt automatically
zfs create -o com.sun:auto-snapshot=false rpool/var/cache

# Docker images, container layers, and build cache live here by default.
# If you move data-root to /srv/docker in Part 2, this dataset becomes stale
# and can be destroyed to reclaim space (see Part 2, Step 2).
zfs create -o com.sun:auto-snapshot=false rpool/var/lib/docker

# Docker compose files and SSD-backed volumes live here
zfs create                     rpool/srv

# tmpfs for /run (required before entering chroot)
mkdir /mnt/run
mount -t tmpfs tmpfs /mnt/run
mkdir /mnt/run/lock
```

**What the original guide includes that we skipped:**

- `rpool/var/spool` — print spooler and cron tables. No printing on a headless server, and cron jobs are a handful of tiny text files.
- `rpool/var/mail` — local mail delivery. Nobody uses this on a homelab Docker server. Alerts come from your containers, not the local MTA.
- `rpool/var/snap` — no snap packages, by choice.
- `rpool/var/www` — serving via Docker, not host Apache.
- `/tmp` dataset — Debian Trixie uses tmpfs for `/tmp` by default, no dataset needed.

---

## Step 7 — Install Base System

```bash
debootstrap trixie /mnt

mkdir /mnt/etc/zfs
cp /etc/zfs/zpool.cache /mnt/etc/zfs/
```

---

## Step 8 — Pre-chroot Configuration

Write the EFI fstab entry and hostname here, before entering chroot. The `$DISK`
variable doesn't carry over into the chroot environment, and trying to do this
inside chroot is one of the most common ways this installation fails.

```bash
# Hostname — replace with your hostname
hostname your-hostname
echo "your-hostname" > /mnt/etc/hostname
echo "127.0.1.1   your-hostname" >> /mnt/etc/hosts

# Network — check your interface name with: ip link show
cat > /mnt/etc/network/interfaces.d/eno1 << 'EOF'
auto eno1
iface eno1 inet dhcp
EOF

# Apt sources
cat > /mnt/etc/apt/sources.list << 'EOF'
deb http://deb.debian.org/debian trixie main contrib non-free-firmware
deb http://deb.debian.org/debian-security trixie-security main contrib non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free-firmware
EOF

# EFI fstab entry — must be written while $DISK is still defined
echo /dev/disk/by-uuid/$(blkid -s UUID -o value ${DISK}-part2) \
    /boot/efi vfat defaults 0 0 >> /mnt/etc/fstab

# Bind mounts for chroot
mount --rbind /dev  /mnt/dev
mount --rbind /proc /mnt/proc
mount --rbind /sys  /mnt/sys

chroot /mnt /bin/bash --login
```

---

## Step 9 — Inside chroot: System Configuration

`$DISK` is gone — you're in a new shell. Redefine it before touching anything
that needs the disk path.

```bash
# Redefine DISK — needed for GRUB install in Step 12
ls -la /dev/disk/by-id/ | grep -v part | grep -v wwn
DISK=/dev/disk/by-id/ata-YOUR_DISK_ID

# Timezone
ln -sf /usr/share/zoneinfo/Europe/Sofia /etc/localtime   # timedatectl list-timezones
dpkg-reconfigure -f noninteractive tzdata

# Locale and console font — the original guide omits both and you end up
# with a system that has no configured locale and ugly console output
apt update
apt install --yes locales console-setup
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/default/locale

# Kernel and ZFS hooks in initramfs
apt install --yes linux-image-amd64 linux-headers-amd64 zfs-initramfs

# SSH
apt install --yes openssh-server

# Root password — temporary, will be locked in Step 16
passwd
```

---

## Step 10 — bpool Import Service

This is missing from most guides and will silently break your system. The boot
pool (`bpool`) runs with `cachefile=none`, which means systemd has no idea it
exists at boot time. Without a service to import it, `/boot` won't mount, and
the next time you run `update-grub` or install a kernel, it'll write to nowhere
and you'll boot into a rescue shell wondering what happened.

```bash
cat > /etc/systemd/system/zfs-import-bpool.service << 'EOF'
[Unit]
DefaultDependencies=no
Before=zfs-import-scan.service
Before=zfs-import-cache.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/zpool import -N -o cachefile=none bpool
ExecStartPre=-/bin/mv /etc/zfs/zpool.cache /etc/zfs/preboot_zpool.cache
ExecStartPost=-/bin/mv /etc/zfs/preboot_zpool.cache /etc/zfs/zpool.cache

[Install]
WantedBy=zfs-import.target
EOF

systemctl enable zfs-import-bpool.service
```

---

## Step 11 — zfs-mount-generator Cache

Without this, systemd doesn't know about any of your ZFS mount points and can't
order service startup correctly. Things like `rsyslog` or Docker can start before
`/var/log` is mounted. It's subtle and annoying to diagnose.

```bash
mkdir -p /etc/zfs/zfs-list.cache
touch /etc/zfs/zfs-list.cache/bpool
touch /etc/zfs/zfs-list.cache/rpool

# Run zed to populate the cache files
zed -F &

sleep 3
cat /etc/zfs/zfs-list.cache/bpool
cat /etc/zfs/zfs-list.cache/rpool

# If either file is still empty, nudge it manually:
zfs set canmount=on     bpool/BOOT/debian
zfs set canmount=noauto rpool/ROOT/debian

kill %1

# Strip /mnt prefix — paths need to reflect the real booted system, not the chroot
sed -Ei "s|/mnt/?|/|" /etc/zfs/zfs-list.cache/*

# Quick sanity check — paths should start with / not /mnt
cat /etc/zfs/zfs-list.cache/rpool
```

---

## Step 12 — GRUB Installation

Two things the original guide doesn't make obvious: `grub-pc` conflicts with
`grub-efi` (use `grub-pc-bin` instead for the legacy BIOS target), and
`GRUB_CMDLINE_LINUX` needs to explicitly name the root ZFS dataset or GRUB may
not find it. Also call `update-initramfs -c -k all` explicitly — relying on the
package install to trigger it isn't reliable across all kernels.

```bash
apt install --yes grub-efi-amd64 grub-efi-amd64-signed shim-signed

mkdir -p /boot/efi
mount /boot/efi

# Tell GRUB which dataset is root
sed -i 's|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX="root=ZFS=rpool/ROOT/debian"|' \
    /etc/default/grub

# Regenerate initramfs for every installed kernel
update-initramfs -c -k all

# UEFI
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
    --bootloader-id=debian --recheck --no-floppy

# Legacy BIOS fallback — grub-pc-bin only, not grub-pc
apt install --yes grub-pc-bin
grub-install --target=i386-pc $DISK

update-grub

# Verify — root=ZFS=rpool/ROOT/debian will appear twice per line, that's normal.
# GRUB's ZFS module adds it and so does GRUB_CMDLINE_LINUX. Harmless.
grep "rpool/ROOT/debian" /boot/grub/grub.cfg
```

---

## Step 13 — Create Admin User

The original guide creates a ZFS dataset per user home directory. Worth doing —
it means you can snapshot or quota individual users, and delete a home directory
cleanly without leaving orphaned data in the pool.

```bash
USERNAME=your-username

zfs create rpool/home/$USERNAME
adduser $USERNAME

cp -a /etc/skel/. /home/$USERNAME
chown -R $USERNAME:$USERNAME /home/$USERNAME

# netdev: needed for network tools
# plugdev: needed for USB devices (Coral USB accelerator, etc.)
usermod -a -G audio,cdrom,dip,floppy,netdev,plugdev,sudo,video $USERNAME
```

---

## Step 14 — Take Installation Snapshots

Do this before you touch anything else. If post-install configuration goes sideways
you can roll back to right here without reinstalling.

```bash
zfs snapshot bpool/BOOT/debian@install
zfs snapshot rpool/ROOT/debian@install

# To roll back (boot from live CD, import pools, then):
# zfs rollback bpool/BOOT/debian@install
# zfs rollback rpool/ROOT/debian@install

# Once the system is stable and you don't need these anymore:
# zfs destroy bpool/BOOT/debian@install
# zfs destroy rpool/ROOT/debian@install
```

---

## Step 15 — Exit and Reboot

```bash
exit   # leave chroot

mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | \
    xargs -i{} umount -lf {}
zpool export -a

reboot   # pull the USB drive during POST
```

---

## Step 16 — First Boot

```bash
# Make sure everything came up correctly
zpool status
zfs list
df -h
ip addr show

# Bring the system fully up to date
sudo apt update && sudo apt dist-upgrade --yes

# Disable root SSH login
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
grep -q "^PermitRootLogin" /etc/ssh/sshd_config || \
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config
systemctl restart ssh

# Lock the root password — use sudo from here on
usermod -p '*' root
```

---

## What's Wrong With the Original Guide

The official guide works as a starting point but has real gaps. Following it
literally will break your first kernel update or produce mysterious boot errors.

| Severity | Issue | Fix |
|---|---|---|
| Boot breaks | `zfs-import-bpool.service` missing — bpool won't mount after reboot | Step 10 |
| Boot breaks | `GRUB_CMDLINE_LINUX` not set — root dataset not explicit | Step 12 |
| Boot breaks | `update-initramfs -c -k all` not called — some kernels get wrong initramfs | Step 12 |
| Subtle | `zfs-mount-generator` cache not set up — services start before ZFS mounts | Step 11 |
| Subtle | `rpool/var/tmp` not excluded from snapshots — package temp files in backups | Step 6 |
| Missing | `mkdosfs` inside chroot where it may not exist | Step 4 |
| Missing | EFI fstab written inside chroot after `$DISK` is gone | Step 8 |
| Missing | `locales` and `console-setup` not installed | Step 9 |
| Missing | `apt update` not run before package installs in chroot | Step 9 |
| Missing | `grub-pc` conflicts with `grub-efi` — use `grub-pc-bin` | Step 12 |
| Missing | `$DISK` lost on chroot entry | Step 9 |
| Missing | User home not a ZFS dataset, incomplete group list | Step 13 |
| Missing | No install snapshots, root login not locked | Steps 14, 16 |

---

## Part 2 — Homelab Platform (separate document)

Once the OS is running, Part 2 covers everything needed to turn this into a real
homelab platform:

- **Docker** — install from the official apt repo, configure `daemon.json`,
  understand overlay2 on ZFS datasets
- **Data disk setup** — ZFS pool on second disk, mounted at `/mnt/<pool>`
- **Directory layout** — `/srv/compose/` (Git repo), `/srv/docker/` (data-root),
  `/mnt/<pool>/docker/volumes/` for data-heavy stacks, central `.env` for all paths
- **Sanoid** — automatic snapshots with hourly/daily/weekly rotation,
  pre-apt hook to snapshot before system updates
- **Syncoid** — push snapshots to a remote server over SSH, recovery from
  replicated snapshots
- **Container migration** — restore Docker volumes from backup, write
  `compose.yaml` with the `.env` path pattern, no hardcoded paths
  or passwords in compose files or Git
- **Disaster recovery** — what to actually do when a disk dies
