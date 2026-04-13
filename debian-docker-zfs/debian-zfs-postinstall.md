# Debian Trixie — Homelab Docker Platform

Part 1 (OS + ZFS installation): `debian-zfs-install.md`

---

- [x] System tools
- [x] Docker + daemon.json
- [x] Directory structure + Git
- [x] Additional disk (ZFS pool)
- [x] Volumes & secrets
- [ ] Sanoid — automatic ZFS snapshots
- [ ] Syncoid — remote replication

---

## Step 1 — System Tools

```bash
sudo apt install --yes htop nmon tmux iotop ncdu lm-sensors \
    net-tools git unzip dnsutils lsof smartmontools rsync tree
```

```bash
# Answer YES at the final "add to /etc/modules?" prompt
sudo sensors-detect && sensors
```

---

## Step 2 — Docker

Official guide: https://docs.docker.com/engine/install/debian/

```bash
sudo apt install --yes ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
    -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources << EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install --yes docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER   # log out and back in after this
```

### daemon.json

Move Docker's data root to `/srv/docker` — volumes then land at predictable paths
under `rpool/srv`, aligning with ZFS datasets and snapshots.

```bash
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "storage-driver": "overlay2",
  "data-root": "/srv/docker",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

sudo systemctl restart docker
docker info | grep -E "Storage Driver|Docker Root Dir"
docker run --rm hello-world
```

> Use `overlay2`, not the `zfs` storage driver — the zfs driver creates a ZFS clone
> per image layer and Docker itself advises against it.

### Clean up stale ZFS dataset (Debian ZFS-on-root only)

The Debian ZFS installer pre-creates `rpool/var/lib/docker`. Once `data-root` is moved
to `/srv/docker`, this dataset holds stale data and is never written to again.

```bash
sudo systemctl stop docker
sudo zfs destroy rpool/var/lib/docker
sudo systemctl start docker
docker info | grep "Docker Root Dir"   # must still show /srv/docker
```

`rpool/var/lib` must be kept — it holds `/var/lib/apt`, `/var/lib/dpkg`, etc.

---

## Step 3 — Directory Structure

```
/srv/
├── compose/       # compose files + .env (Git repo)
└── docker/        # Docker data-root — managed by Docker
    ├── volumes/   # named volumes
    ├── overlay2/  # image layers
    └── ...

/mnt/<pool>/docker/
└── volumes/       # volumes for data-heavy containers (optional second disk)
```

```bash
sudo mkdir -p /srv/compose
sudo chown -R $USER:$USER /srv/compose /srv/docker
```

### Global .env

Paths and timezone only — safe to commit. Credentials go in per-stack `.env` files.

```bash
cat > /srv/compose/.env << 'EOF'
TZ=Region/City      # timedatectl list-timezones
VOLUMES_NVME=/mnt/nvme-1tb/docker/volumes   # only needed if you have a second disk
EOF
```

Set `COMPOSE_ENV_FILES` so every `docker compose` command loads it automatically:

```bash
echo 'export COMPOSE_ENV_FILES=/srv/compose/.env' >> ~/.bashrc
source ~/.bashrc
```

### Git repo

```bash
cd /srv/compose
git init
git config user.name "your-name"
git config user.email "your@email.com"

cat > .gitignore << 'EOF'
secrets/
*.secret
*/.env
.DS_Store
*.swp
EOF

git add . && git commit -m "init"
```

---

## Step 4 — Additional Disk (ZFS Pool)

Works for NVMe, SATA SSD, or HDD — only the by-id path differs.

```bash
# List disks — exclude partition entries
ls -la /dev/disk/by-id/ | grep -v part
```

Always use by-id paths — `/dev/sdX` and `/dev/nvmeXn1` can shift across reboots:

```bash
DATADISK=/dev/disk/by-id/<your-disk-id>
lsblk -f $DATADISK    # verify it's the right disk
wipefs $DATADISK      # list signatures — no changes yet
```

```bash
wipefs -a $DATADISK   # wipe — ZFS will refuse a disk with existing signatures

# ashift=12 = 4K sectors, correct for most modern SSDs and NVMe.
# ashift=9 = 512B, only for old HDDs with true 512B sectors.
sudo zpool create \
    -o ashift=12 -o autotrim=on \
    -O devices=off \
    -O compression=zstd \
    -O acltype=posixacl -O xattr=sa \
    -O normalization=formD -O relatime=on \
    -O dnodesize=auto \
    -O mountpoint=/mnt/nvme-1tb \
    nvme-1tb $DATADISK

sudo zfs create nvme-1tb/docker
sudo mkdir -p /mnt/nvme-1tb/docker/volumes
sudo chown -R $USER:$USER /mnt/nvme-1tb/docker

zpool status nvme-1tb && zfs list nvme-1tb
```

On a live system `zed` updates `/etc/zfs/zfs-list.cache/nvme-1tb` automatically —
this is what lets systemd order mounts correctly at boot.

```bash
cat /etc/zfs/zfs-list.cache/nvme-1tb
# If empty: touch /etc/zfs/zfs-list.cache/nvme-1tb && zfs set mountpoint=/mnt/nvme-1tb nvme-1tb
```

---

## Step 5 — Volumes & Secrets

Two volume types:
- **SSD** — plain named volume, Docker manages the path under `data-root`
- **NVMe** — `driver_opts` bind-mount to second disk. Create the dir first — Docker won't.

Three credential patterns:
- **None** — `${TZ}` etc. from global `.env` via `COMPOSE_ENV_FILES`
- **env_file** — per-stack `<stack>/.env` (gitignored), loaded with `env_file: .env`
- **_FILE** — for MariaDB/PostgreSQL/Nextcloud; secrets at `/run/secrets/`, never in `docker inspect`

```yaml
services:

  # No credentials — TZ from global .env
  app:
    image: myapp:latest
    environment:
      - TZ=${TZ}
    volumes:
      - app-data:/data

  # Credentials via .env file
  app2:
    image: myapp2:latest
    env_file: .env              # <stack>/.env — gitignored, credentials only
    environment:
      - TZ=${TZ}
    volumes:
      - app2-data:/data

  # Credentials via _FILE (most secure)
  db:
    image: mariadb:11
    environment:
      MARIADB_ROOT_PASSWORD_FILE: /run/secrets/db_root_password
      MARIADB_PASSWORD_FILE: /run/secrets/db_password
      MARIADB_DATABASE: myapp
      MARIADB_USER: myapp
    secrets:
      - db_root_password
      - db_password
    volumes:
      - db:/var/lib/mysql

secrets:
  db_root_password:
    file: ./secrets/db_root_password
  db_password:
    file: ./secrets/db_password

volumes:
  app-data:                     # SSD — /srv/docker/volumes/<stack>_app-data/_data/
  app2-data:                    # SSD — same pattern
  db:                           # NVMe — bind-mount to second disk
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${VOLUMES_NVME}/<stack>_db/_data
```

NVMe dir must exist before `docker compose up`:
```bash
mkdir -p /mnt/nvme-1tb/docker/volumes/<stack>_db/_data
```

_FILE secrets dir:
```bash
mkdir -p /srv/compose/<stack>/secrets
echo "strongpassword" > /srv/compose/<stack>/secrets/db_root_password
chmod 700 /srv/compose/<stack>/secrets
chmod 600 /srv/compose/<stack>/secrets/*
```

---

## Step 6 — Automatic Snapshots with Sanoid

> **TODO**
>
> | Dataset | Hourly | Daily | Weekly | Monthly |
> |---|---|---|---|---|
> | `rpool/ROOT/debian` | — | 7 | 4 | 3 |
> | `rpool/srv` | 24 | 30 | 8 | 3 |
> | `nvme-1tb` pool | 24 | 30 | 8 | 3 |
>
> Pre-apt snapshot hook, rollback procedure, pruning old snapshots.

---

## Step 7 — Remote Replication with Syncoid

> **TODO**
>
> SSH key setup, syncoid command per pool, systemd timer, verify, recovery procedure.

---

## Notes — Internet Exposure and Firewall

Plan:

- **Reverse proxy:** Nginx Proxy Manager or Traefik (Docker-native, auto SSL via DNS challenge)
- **Firewall:** UFW — allow SSH + proxy port only, drop everything else
- **Auth middleware:** Authelia or Authentik in front of exposed services
- **SSL:** Let's Encrypt DNS challenge — no need to open port 80

When a service sits behind a reverse proxy on a shared Docker network, no `ports:` mapping
is needed on the app container — the proxy reaches it directly via the internal network.

---

## Personal — Notes & TODO

### TODO

- [ ] Transfer remaining files from old DietPi drive (`/mnt/ext-usb`)
- [ ] Samba share
- [ ] qBittorrent container with web UI
- [ ] Frigate (separate machine TBD)
- [ ] Sanoid — ZFS automatic snapshots (Step 6)
- [ ] Syncoid — remote replication (Step 7)
- [ ] Fan control

---

### DietPi Migration

Old DietPi drive mounted at `/mnt/ext-usb/dietpi_userdata/` on the new server.

Complete Steps 1–5 first, then verify:

```bash
docker info | grep -E "Storage Driver|Docker Root Dir"
# expect: overlay2 / /srv/docker

ls /srv/compose /srv/docker /mnt/nvme-1tb/docker/volumes
cat /srv/compose/.env
```

**Rsync compose files:**

```bash
rsync -av /mnt/ext-usb/dietpi_userdata/compose/ /srv/compose/
```

**Rsync volume data** (`-av` preserves ownership — never chown after):

```bash
sudo rsync -av /mnt/ext-usb/dietpi_userdata/docker-data/volumes/ /srv/docker/volumes/
```

Data lands as `/srv/docker/volumes/<stack>_<vol>/_data/` — leave it as-is.
Docker finds volumes by name at startup. No `driver_opts` needed for SSD volumes.

**Move nextcloud to NVMe:**

```bash
sudo mv /srv/docker/volumes/nextcloud-compose_db          /mnt/nvme-1tb/docker/volumes/
sudo mv /srv/docker/volumes/nextcloud-compose_nextcloud   /mnt/nvme-1tb/docker/volumes/
```

**Per-stack process:** extract credentials from `environment:` into `<stack>/.env`,
add `env_file: .env` to the service, then `docker compose up -d`.

**Skipped volumes:**

| Volume | Reason |
|---|---|
| `compose_port_data` | Stale — superseded by `portainer_port_data` |
| `fb_firebird3/4/5` | No active stack |
| `sqlvolume` | Unclear origin |
| `frigate_config`, `frigate_frigate` | Moving to different machine |

**Stacks completed:** changedetection, esphome, gitea, hass, homepage, nginxproxy, portainer, wp, nextcloud-compose
