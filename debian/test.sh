#
# Building a raw disk image
#

# bytes per sector
bytes=512
# sectors per track
sectors=63
# heads per track
heads=16
# bytes per cylinder is bytes*sectors*head
bpc=$(( bytes*sectors*heads ))
# number of cylinders
# For a image of $size MB, cylinders = (($size*1024*1024)/$bpc)
size=250
cylinders=$(( ($size*1024*1024) / $bpc ))
loop=/dev/loop7

SIZECOUNT=$((size/4))

# Path to disk image
image=$PWD/test.img
# Path to location to mount image
mount=$PWD/test

# Create raw disk image
# dd if=/dev/zero of=$image bs=$bpc count=$cylinders
dd if=/dev/zero of=$image bs=4M count=$SIZECOUNT

# Attach image as raw device and partition it
losetup $loop $image
parted $image mklabel msdos
parted $image mkpart primary ext2 0 $size
parted $image set 1 boot on
fdisk -u -C$cylinders -S$sectors -H$heads $loop
# Create a ext2 partition
# With commands like these;
# o n p 1 <return> <return> a 1 p w
# Note the start sector and block count of partition
# start=63
# count=204592
losetup -d $loop

# Mount a specfic parition
offset=$(( start*bytes ))
losetup -o$offset $loop $image

# Format the partition
mke2fs -o hurd -b1024 $loop $count

# Mount the partition
mkdir $mount
mount -tauto $loop $mount

# Unmount the partition
umount $loop
losetup -d $loop

#
# Installing GRUB into the raw disk image
#

# Easy mounting
mount -tauto -oloop=$loop,offset=$offset $image $mount

# Copy across needed grub images
cd $mount
mkdir -p boot/grub
cd /boot/grub
cp stage1 stage2 e2fs_stage1_5 $mount/boot/grub
cd
sync
umount -d $mount

# Install grub
losetup $loop $image
grub
# Commands like this;
# device (hd0) /dev/loop0
# geometry (hd0) $cylinders $heads $sectors
# root (hd0,0)
# setup (hd0)

grub> setup (hd0)
Checking if "/boot/grub/stage1" exists... yes
Checking if "/boot/grub/stage2" exists... yes
Checking if "/boot/grub/e2fs_stage1_5" exists... yes
Running "embed /boot/grub/e2fs_stage1_5 (hd0)"... 22 sectors are
embedded. succeeded
Running "install /boot/grub/stage1 (hd0) (hd0)1+22 p
(hd0,0)/boot/grub/stage2 /boot/grub/menu.lst"... failed