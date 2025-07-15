# Check the system clock
```bash
timedatectl
```

```bash
timedatectl --set-timezone Europe/Warsaw
```

# Set up of the encrypted partitions
```bash
echo ""

echo "--- Recreating partition table ---"

sgdisk --zap-all $DEV
sgdisk --new=1:0:+768M $DEV
sgdisk --new=2:0:+2M $DEV
sgdisk --new=3:0:+128M $DEV
sgdisk --new=5:0:0 $DEV
sgdisk --typecode=1:8301 --typecode=2:ef02 --typecode=3:ef00 --typecode=5:8301 $DEV
sgdisk --change-name=1:/boot --change-name=2:GRUB --change-name=3:EFI-SP --change-name=5:rootfs $DEV
sgdisk --hybrid 1:2:3 $DEV

echo ""

echo "--- New partition structure ---"
sgdisk --print $DEV

echo ""

echo "--- Encrypt /boot partition ---"
cryptsetup luksFormat --type=luks1 ${DEVP}1

echo ""

echo "--- Encrypt operating system partition ---"
cryptsetup luksFormat ${DEVP}5

echo ""

echo "--- Opening encrypted partitions ---"
cryptsetup open ${DEVP}1 LUKS_BOOT
cryptsetup open ${DEVP}5 ${DM}5_crypt

echo "--- Formatting the boot partition ---"
mkfs.ext4 -L boot /dev/mapper/LUKS_BOOT

echo "--- Formatting the EFI partition ---"
mkfs.vfat -F 16 -n EFI-SP ${DEVP}3

echo "--- Configuring the LVM ---"
pvcreate /dev/mapper/${DM}5_crypt
vgcreate vgArch /dev/mapper/${DM}5_crypt
lvcreate -L ${RAM}G -n swap_1 vgArch
lvcreate -l 80%FREE -n root vgArch

echo "--- Formatting the root partition ---"
mkfs.ext4 /dev/mapper/vgArch-root
```

# Install Arch
```bash
echo "--- Initialize the swap partition ---"
swapon /dev/mapper/vgArch-swap_1

echo "--- Mounting the partitions ---"
mount /dev/mapper/vgArch-root /mnt
mount /dev/mapper/LUKS_BOOT /mnt/boot

echo "--- Install essential packages ---"
pacstrap -K /mnt base linux linux-firmware

echo "--- Generate the fstab file ---"
genfstab -U /mnt >> /mnt/etc/fstab
```

# Chroot
```bash
arch-chroot /mnt
```

# Configure time
```bash
ln -sf /usr/share/zoneinfo/Europe/Warsaw /etc/localtime
hwclock --systohc # It will create the /etc/adjtime file
```

## Configure the time synchronization
[https://wiki.archlinux.org/title/Systemd-timesyncd](https://wiki.archlinux.org/title/Systemd-timesyncd)

```bash
timedatectl set-ntp true
```

# Configure the locale
1. Edit the file: `/etc/locale.gen` and uncomment `en_US.UTF-8 UTF-8`.
2. Generate the locales by running: `locale-gen`.
3. Create the `/etc/locale.conf` file and set the LANG variable:
```bash
LANG=en_US.UTF-8
```

# Network configuration
Create he `/etc/hostname` file and add the hostname.

# Create the `initramfs`
1. Install the `lvm2`: `pacman -S lvm2`.
2. Edit the `/etc/mkinitcpio.conf` file by adding the hooks: `encrypt` and `lvm2` into the `HOOKS` (between the `block` and `filesystems`)
3. Create the `initramfs`: `mkinitcpio -P`

# Set the root password
```bash
passwd
```

# Configure the boot loader
1. Edit the `/etc/default/grub` file by adding/modifying the following lines:
  - `GRUB_CMDLINE_LINUX="cryptdevice=UUID=<UUID of the encrypted partition where the root exists, e.g. /dev/sda5>:sda5_crypt root=/dev/mapper/vgArch-root"`
  - `GRUB_PRELOAD_MODULES="part_gpt part_msdos lvm"`
  - `GRUB_ENABLE_CRYPTODISK=y`
2. Edit the `/etc/crypttab` file:
```bash
echo "LUKS_BOOT UUID=$(blkid -s UUID -o value ${DEVP}1) none luks,discard" >> /etc/crypttab
echo "${DM}5_crypt UUID=$(blkid -s UUID -o value ${DEVP}5) none luks,discard" >> /etc/crypttab
```
3. Install the `grub` package: `packman -S grub`.
4. Install grub
```bash
grub-install /dev/sda
```
5. Create the grub config file
```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

# Post-installation
1. Edit the `/etc/resolv.conf` file.
2. Configure the systemd-networkd to get access to internet.
3. Install NetworkManager (next stop systemd-networkd).
4. Install sudo: `pacman -S sudo`.
5. Edit the `/etc/sudoers` file by uncommenting the line: `%wheel ALL=(ALL:ALL) ALL`.
6. Create a new user: `useradd -m -G wheel -s /usr/bin/bash aviatore`.
