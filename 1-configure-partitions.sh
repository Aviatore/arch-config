echo ""

DEV=$1
DM=${DEV##*/}
DEVP="${DEV}$( if [[ "$DEV" =~ "nvme" ]]; then echo "p"; fi )"
DM="${DM}$( if [[ "$DM" =~ "nvme" ]]; then echo "p"; fi )"
RAM=$2

echo "--- Configure timezone ---"
timedatectl --set-timezone Europe/Warsaw

# Set up of the encrypted partitions
echo "--- Recreating partition table ---"

sgdisk --zap-all $DEV
sgdisk --new=1:0:+768M $DEV
sgdisk --new=2:0:+2M $DEV
sgdisk --new=3:0:+128M $DEV
sgdisk --new=5:0:0 $DEV
sgdisk --typecode=1:8301 --typecode=2:ef02 --typecode=3:ef00 --typecode=5:8301 $DEV
sgdisk --change-name=1:/boot --change-name=2:GRUB --change-name=3:EFI-SP --change-name=5:rootfs $DEV
sgdisk --hybrid 1:2:3 $DEV
read -p "Press ENTER to continue..." && echo ""

echo ""

echo "--- New partition structure ---"
sgdisk --print $DEV
read -p "Press ENTER to continue..." && echo ""

echo ""

echo "--- Encrypt /boot partition ---"
cryptsetup luksFormat --type=luks1 ${DEVP}1
read -p "Press ENTER to continue..." && echo ""

echo ""

echo "--- Encrypt operating system partition ---"
cryptsetup luksFormat ${DEVP}5
read -p "Press ENTER to continue..." && echo ""

echo ""

echo "--- Opening encrypted partitions ---"
cryptsetup open ${DEVP}1 LUKS_BOOT
cryptsetup open ${DEVP}5 ${DM}5_crypt
read -p "Press ENTER to continue..." && echo ""

echo "--- Formatting the boot partition ---"
mkfs.ext4 -L boot /dev/mapper/LUKS_BOOT
read -p "Press ENTER to continue..." && echo ""

echo "--- Formatting the EFI partition ---"
mkfs.vfat -F 16 -n EFI-SP ${DEVP}3
read -p "Press ENTER to continue..." && echo ""

echo "--- Configuring the LVM ---"
pvcreate /dev/mapper/${DM}5_crypt
vgcreate vgArch /dev/mapper/${DM}5_crypt
lvcreate -L ${RAM}G -n swap_1 vgArch
lvcreate -l 80%FREE -n root vgArch
read -p "Press ENTER to continue..." && echo ""

echo "--- Formatting the root partition ---"
mkfs.ext4 /dev/mapper/vgArch-root
read -p "Press ENTER to continue..." && echo ""

# Install Arch
echo "--- Initialize the swap partition ---"
mkswap /dev/mapper/vgArch-swap_1
swapon /dev/mapper/vgArch-swap_1

echo "--- Mounting the partitions ---"
mount /dev/mapper/vgArch-root /mnt
mkdir /mnt/boot
mount /dev/mapper/LUKS_BOOT /mnt/boot
read -p "Press ENTER to continue..." && echo ""

echo "--- Install essential packages ---"
pacstrap -K /mnt base linux linux-firmware
read -p "Press ENTER to continue..." && echo ""

echo "--- Generate the fstab file ---"
genfstab -U /mnt >> /mnt/etc/fstab
read -p "Press ENTER to continue..." && echo ""