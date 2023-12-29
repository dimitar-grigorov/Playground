# How to expand LVM without adding additional logical volume

```bash
# If you use qcow2 images, you can expand the image with qemu-img
qemu-img resize /path/to/image.qcow2 +10G
# Expand the partition with fdisk
fdisk /dev/vda3
# Expand the physical volume
pvresize /dev/vda3
# Expand the logical volume
lvextend -l +100%FREE /dev/mapper/VolGroup-lv_root
# Expand the filesystem
e2fsck -f /dev/mapper/VolGroup-lv_root
resize2fs /dev/mapper/VolGroup-lv_root
```
