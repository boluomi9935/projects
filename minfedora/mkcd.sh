FILE=image.img
DIR=image
INITRD=minfedoramin.img
SIZE=128

dd if=/dev/zero of=$FILE bs=1M count=$SIZE
#echo "y" | mke2fs -q -i 8192 -m 0 $FILE



#sudo parted $FILE mklabel
echo "msdos" | sudo parted $FILE mklabel
#msdos
sudo parted $FILE mkpart primary ext2 0 $SIZE
sudo parted $FILE set 1 boot on
#1 
#sudo parted $FILE mkfs 1 ext2
sudo parted -s $FILE mkfs 1 ext2

mkdir $DIR
sudo mount -o loop,offset=16384 -t ext2 $FILE $DIR






#sudo mount -o loop $FILE $DIR

sudo mkdir $DIR/boot
sudo mkdir $DIR/boot/grub

sudo cp -v /boot/grub/stage[12] $DIR/boot/grub/
sudo cp -v /boot/grub/e2fs_stage1_5 $DIR/boot/grub/

#sudo umount $DIR



echo "device (hd0) $PWD/$FILE
root (hd0,0)
setup (hd0)
quit
" >/tmp/grub.input

#mkdir -p $DIR/boot/grub


grub --batch --device-map=/dev/null < /tmp/grub.input


echo "default=0
timeout=10
#hiddenmenu

#title minimal-kernel
#    kernel /minimal-kernel

title Debian
        root (hd0,0)
        kernel /boot/vmlinuz ro root=/dev/hda1 rhgb quiet
        initrd /boot/initrd.img

" > /tmp/grub.conf

sudo cp /tmp/grub.conf $DIR/boot/grub/grub.conf

cd $DIR/boot/grub
sudo ln -s grub.conf menu.lst
cd ../../..

sudo cp $INITRD $DIR/boot/initrd.img

sudo umount $DIR
