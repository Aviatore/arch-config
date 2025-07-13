# Configure time
echo "--- Configure time ---"
ln -sf /usr/share/zoneinfo/Europe/Warsaw /etc/localtime
hwclock --systohc # It will create the /etc/adjtime file
tiomedatectl set-ntp true

# Configure the locale
echo "--- Configure the locale ---"
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Network configuration
echo "--- Network configuration ---"
echo "myarch" > /etc/hostname

# Create the initramfs
echo "--- Create the initramfs ---"
pacman -S lvm2
sed -i 's/HOOKS/#HOOKS/' /etc/mkinitcpio.conf
echo "HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt lvm2 filesystems fsck)" >> /etc/mkinitcpio.conf
mkinitcpio -P

# Set the root password
echo "--- Set the root password ---"
passwd

# Install the grub package
echo "--- Install the grub package ---"
pacman -S grub

# Configure the boot loader
echo "--- Configure the boot loader ---"
uuid=`blkid -s UUID -o value /dev/sda5`
sed -i "s#GRUB_CMDLINE_LINUX=.*#GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${uuid}:sda5_crypt root=/dev/mapper/vgArch-root\"#" /etc/default/grub
sed -i "s#GRUB_PRELOAD_MODULES=.*#GRUB_PRELOAD_MODULES=\"part_gpt part_msdos lvm\"#" /etc/default/grub
sed -i "s#GRUB_ENABLE_CRYPTODISK=.*#GRUB_ENABLE_CRYPTODISK=y#" /etc/default/grub

# Update crypttab
echo "--- Update crypttab ---"
echo "LUKS_BOOT UUID=$(blkid -s UUID -o value /dev/sda1) none luks,discard" >> /etc/crypttab
echo "sda5_crypt UUID=$(blkid -s UUID -o value /dev/sda5) none luks,discard" >> /etc/crypttab

# Install grub
echo "--- Install grub ---"
grub-install /dev/sda

# Create the grub config file
echo "--- Create the grub config file ---"
grub-mkconfig -o /boot/grub/grub.cfg