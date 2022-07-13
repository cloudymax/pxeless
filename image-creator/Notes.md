# 22.04 update

based on [THIS](https://askubuntu.com/questions/1289400/remaster-installation-image-for-ubuntu-20-10) reply by Thomas Schmitt

1. downloading the image

```bash
wget "https://cdimage.ubuntu.com/ubuntu-server/jammy/daily-live/current/jammy-live-server-amd64.iso"
```

2. Inspect the image file

```bash
# Linux only
fdisk -l jammy-live-server-amd64.iso

Disk jammy-live-server-amd64.iso: 1.37 GiB, 1469347840 bytes, 2869820 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: 87D86EB3-DE36-41CA-980F-B41C4BA7268F

Device                         Start     End Sectors  Size Type
jammy-live-server-amd64.iso1      64 2860659 2860596  1.4G Microsoft basic data
jammy-live-server-amd64.iso2 2860660 2869155    8496  4.1M EFI System
jammy-live-server-amd64.iso3 2869156 2869755     600  300K Microsoft basic data
```

3. Extract MBR and EFI partition image from the original ISO

```bash
export ORIGINAL=jammy-live-server-amd64.iso
export MBR=jammy-live-server-amd64.mbr
export EFI=jammy-live-server-amd64.efi

# Extract the MBR template
dd if="$ORIGINAL" bs=1 count=446 of="$MBR"

# Extract EFI partition image
export START_BLOCK=$(fdisk -l "$ORIGINAL" | fgrep '.iso2 ' | awk '{print $2}')

export SECTORS=$(fdisk -l "$ORIGINAL" | fgrep '.iso2 ' | awk '{print $4}')

dd if="$ORIGINAL" bs=512 skip="$START_BLOCK" count="$SECTORS" of="$EFI"
```

4. ???

5. Re-package ISO

```bash
FINAL_IMAGE=custom-boot.iso

# mkisofs  -r: Generate rationalized Rock Ridge directory information

# -V: Set Volume ID

# -J: Generate Joliet directory information

# -joliet-long : Allow Joliet file names to be 103 Unicode characters

# -l: Allow full 31 character filenames for ISO9660 names

# -iso-level 3: Specify the ISO 9660 version which defines the limitations of file naming and data file size. The naming restrictions do not apply to the Rock Ridge names but only to the low-level ISO 9660 names. There are three conformance levels: Level 3 allows ISO names with up to 32 characters and file size of up to 400 GiB - 200 KiB. 

# -partition_offset 16: Cause a partition table with a single partition that begins at the given block address.

# --grub2-mbr: Install disk_path in the System Area and treat it as modern GRUB2 MBR. 

# --mbr-force-bootable: Enforce an MBR partition with "bootable/active" flag if options like --protective-msdos-label or --grub2-mbr are given.

# -append_partition 2 0xEF "$efi" : Cause a prepared filesystem image to be appended to the ISO image and to be described by a partition table entry in a boot block at the start of the emerging ISO image.

# -appended_part_as_gpt : Marks partitions from -append_partition in GPT rather than in MBR. In this case the MBR shows a single partition of type 0xee which covers the whole output data. 

# -c : Set the address of the El Torito boot catalog file within the image. 

# -b : Specify the boot image file which shall be mentioned in the current entry of the El Torito boot catalog. It will be marked as suitable for PC-BIOS. Requires -c , -no-emul-boot , -boot-load-size 4 , -boot-info-table.

# -no-emul-boot : Mark the boot image in the current catalog entry as not emulating floppy or hard disk. 

# -boot-load-size : Set the number of 512-byte blocks to be loaded at boot time from the boot image in the current catalog entry

# -boot-info-table : Overwrite bytes 8 to 63 in the current boot image.

# --grub2-boot-info : Overwrite bytes 2548 to 2555 in the current boot image by the address of that boot image.

# -eltorito-alt-boot : Finalize the current El Torito boot catalog entry and begin a new one. 

# -e : Specify the boot image file which shall be mentioned in the current entry of the El Torito boot catalog. 

# -o : Set the output file address for the emerging ISO image.

export DISK_TITLE="custom-jammy-live-server-amd64"
export ORIGINAL=jammy-live-server-amd64.iso
export MBR=jammy-live-server-amd64.mbr
export EFI=jammy-live-server-amd64.efi


xorriso -as mkisofs \
  -r -V "$DISK_TITLE" -J -joliet-long -l \
  -iso-level 3 \
  -partition_offset 16 \
  --grub2-mbr "$MBR" \
  --mbr-force-bootable \
  -append_partition 2 0xEF "$EFI" \
  -appended_part_as_gpt \
  -c /boot.catalog \
  -b /boot/grub/i386-pc/eltorito.img \
    -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
  -eltorito-alt-boot \
  -e '--interval:appended_partition_2:all::' \
    -no-emul-boot \
  -o "$FINAL_IMAGE" \
  unpackedImageDirectory
```

sudo docker build -t isogen . && \
sudo docker run -it --mount type=bind,source="$(pwd)",target=/app isogen
