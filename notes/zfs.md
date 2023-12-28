# Notes about using ZFS on Linux

```bash
# List pools
zpool status
# List datasets
zfs list
# List datasets and snapshots
zfs list -t all
# Create a snapshot
zfs snapshot tank/home@2020-01-01
# Transfer a snapshot to another pool
zfs send tank/home@2020-01-01 | zfs receive external/home
# Delete a snapshot
zfs destroy tank/home@2020-01-01
# Dry run of a snapshot deletion
zfs destroy -n -v tank/home@2020-01-01
```