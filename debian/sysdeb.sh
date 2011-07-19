BASENAME=gcc
# ARCH=i386
# ARCHL=686
ARCH=amd64
ARCHL=amd64
SIZE=4300
USERL=cbs


FILE=$PWD/$BASENAME.img
PWD2=$PWD/$BASENAME
SIZECOUNT=$((SIZE/4))

# http://osdir.com/ml/boot-loaders.grub.bugs/2005-01/msg00035.html
echo CREATING IMAGE
#dd if=/dev/zero of=/mnt/d/sys/debian.img bs=4K count=1100800
# dd if=/dev/zero of=/mnt/d/sys/debian.img bs=1M count=1536
# dd if=/dev/zero of=$PWD/debian.img bs=1M count=512
dd if=/dev/zero of=$FILE bs=4M count=$SIZECOUNT
#1100800 4.3gb
#150000  512 mb

mkdir $PWD2




echo INSTALING BOOR LOADER
parted $FILE mklabel msdos
parted $FILE mkpart primary ext2 0 $SIZE
parted $FILE set 1 boot on
parted $FILE mkfs 1 ext2

mount -o loop,offset=16384 -t ext2 $FILE $PWD2

echo BOOTSTRAPPING
debootstrap --verbose --include=discover,udev,make,automake,zip,bzip2,ftp,wget,lynx,unzip,ncftp,locales,locate,less,mc,lynx,gcc --arch $ARCH lenny $PWD2 http://ftp.nl.debian.org/debian/
#http://ftp.debian.org/debian


echo COPYING LOCALE
rm -rf $PWD2/usr/share/locale/
cp -rp --force /usr/share/locale $PWD2/usr/share
cp -rp --force /usr/local/share/locale/ $PWD2/usr/local/share/
cp -rp --force /usr/lib/locale/ $PWD2/usr/lib/


echo INSTALLING USERS
chroot $PWD2 << EOFFE
passwd << IOF
root
root
IOF

addgroup $USERL -gid 501
addgroup --force-badname Debian-exim
useradd -c "$USERL" -d /home/$USERL -m -s /bin/bash -g $USERL -u 501 $USERL
passwd $USERL << IOF
$USERL
$USERL
IOF
useradd -g Debian-exim Debian-exim

echo "%sudo ALL=NOPASSWD: ALL"        >> /etc/sudoers
echo "$USERL ALL=(ALL) NOPASSWD:ALL"  >> /etc/sudoers
echo "root ALL=(ALL) NOPASSWD:ALL"    >> /etc/sudoers
echo "knoppix ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
echo "root ALL=(ALL) NOPASSWD:ALL"    >> /etc/sudoers
EOFFE


echo COPYING HOSTS
cp -af /etc/hosts $PWD2/etc/


echo CREATING FSTAB
cat >> $PWD2/etc/fstab << EOFEO
tmpfs                   /dev/shm                tmpfs   defaults        0 0
devpts                  /dev/pts                devpts  gid=5,mode=620  0 0
sysfs                   /sys                    sysfs   defaults        0 0
proc                    /proc                   proc    defaults        0 0
#selinuxfs               /selix                  none    defaults        0 0
EOFEO


echo CREATING START SCRIPT
cat >> $PWD2/start << EOFE
mount -t proc none /proc
#mount -t selinuxfs none /selinux
mount -t sysfs none /sys
mount -t devpts none /dev/pts
mount -t tmpfs none /dev/shm
/etc/init.d/apache2 start

export PATH=/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/local/sbin:/sbin:/usr/local/bin
       PATH=/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/local/sbin:/sbin:/usr/local/bin

rpc.statd
rpc.idmapd 
# sudo mount -o udp -o nolock -t nfs 10.66.0.13:/home/aflitos/Desktop/output BASIC/ 
EOFE
chroot $PWD2 chmod +x /start


echo CREATING STOP SCRIPT
cat >> $PWD2/stop << EOFO
/etc/init.d/apache2 stop
killall rpc.statd
umount /proc
#umount /selinux
umount /sys
umount /dev/pts
umount /dev/shm
EOFO
chroot $PWD2 chmod +x /stop


echo COPYING PROFILE
cat /etc/profile >> $PWD2/etc/profile
cp -ar /etc/profile.d/ $PWD2/etc


# Filesystem            Size  Used Avail Use% Mounted on
# /home/saulo/Desktop/debian/debian.img
#                       4.0G  771M  3.0G  21% /home/saulo/Desktop/debian/debian
#END STEP 1
umount $PWD2
cp $FILE $FILE.1
mount -o loop,offset=16384 -t ext2 $FILE $PWD2




echo INSTALL SUPPLEMENTARY PACKAGES
cat >> $PWD2/etc/kernel-img.conf << EOFF
do_symlinks = yes
relative_links = yes
do_bootloader = yes
do_initrd = yes
link_in_boot = yes
#postinst_hook = /sbin/update-grub
#postrm_hook   = /sbin/update-grub
EOFF

chroot $PWD2 << EOFOE
echo "INSTALLING SUPPLEMENTARY SYSTEM PACKAGES: START"
/start
ARCHL=$ARCHL


echo "INSTALLING SUPPLEMENTARY SYSTEM PACKAGES: SUDO, NFS"
apt-get -y --force-yes install libx11-6 sudo nfs-common psmisc


echo "INSTALLING SUPPLEMENTARY SYSTEM PACKAGES: LINUX IMAGE AND HEADER"
apt-get -y --force-yes install linux-image-2.6.26-1-$ARCHL linux-headers-2.6.26-1-$ARCHL


echo "INSTALLING SUPPLEMENTARY SYSTEM PACKAGES: GRUB"
apt-get -y --force-yes install grub

# lilo

mkdir /boot/grub


echo "INSTALLING SUPPLEMENTARY PROGRAMS PACKAGES: PDL, LIBSTDC++, G++, GAWK, ZLIB AND ALIEN"

# apt-get -y --force-yes install emboss pdl emboss-data emboss-lib libemboss-acd-perl plplot-bin libstdc++5 

apt-get -y --force-yes install pdl plplot-bin libstdc++5 g++ gawk

apt-get -y --force-yes install zlib-bin zlibc libcompress-zlib-perl zlib1g-dev alien



echo "INSTALLING SUPPLEMENTARY PROGRAMS PACKAGES: PERL"

apt-get -y --force-yes install bioperl libgd-gd2-perl libgd-graph-perl libdata-sorting-perl libpng12-0 libgd-text-perl libio-string-perl libgd2-xpm

#  libgd2-noxpm



echo "INSTALLING SUPPLEMENTARY PROGRAMS PACKAGES: APACHE"

apt-get -y --force-yes install apache2 libapache2-mod-perl2 perl-suid cgilib

apt-get clean
apt-get autoclean

# cgiwrap

updatedb

echo "INSTALLING SUPPLEMENTARY PROGRAMS PACKAGES: STOP"

/stop

EOFOE

# Filesystem            Size  Used Avail Use% Mounted on
# /home/saulo/Desktop/debian/debian.img
#                       4.0G  1.1G  2.8G  28% /home/saulo/Desktop/debian/debian
umount $PWD2
cp $FILE $FILE.2
mount -o loop,offset=16384 -t ext2 $FILE $PWD2


echo COPYING GRUB

echo "device (hd0) $FILE
root (hd0,0)
setup (hd0)
quit
" >/tmp/grub.input

mkdir -p $PWD2/boot/grub

cp -p /boot/grub/stage1 $PWD2/boot/grub
cp -p /boot/grub/stage2 $PWD2/boot/grub
cp -p /boot/grub/e2fs_stage1_5 $PWD2/boot/grub
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

" > $PWD2/boot/grub/grub.conf

cd $PWD2/boot/grub
ln -s grub.conf menu.lst
# cd ..
# ln -s `ls initrd.img*` initrd.img
cd ../../..





# grub --device-map=/dev/null < /tmp/grub.input




echo BASIC SYSTEM CREATION DONE
umount $PWD2



echo PROCESS DONE



###################################################################################
#bioperl,pdl,

##debootstrap --arch i386 etch --keep-bootstrap-dir --second-stage --second-stage-target /media/disk/cluster/sandbox/basicsys/debian 
##debootstrap --second-stage --second-stage-target /media/disk/cluster/sandbox/basicsys/debian --keep-bootstrap-dir --arch i386 etch

#libstdc++5-3.3-dbg

#cp -R /media/disk/cluster/sandbox/basicsys/deb /media/disk/cluster/sandbox/basicsys/debian/

#useradd -c "Test user for chrooted union." -d /home/unionuser \<br /> -m -s /bin/chroot-union -g uniongroup -u 27 unionuser

#debootstrap --include=libdata-sorting-perl,make,automake,zip,bzip2,ftp,wget,lynx,unzip,ncftp,locales,less,mc,lynx,gcc,plplot-bin,emboss,libpng12-0,libgd2-noxpm,libx11-6 --exclude=x11-common --print-debs --keep-debootstrap-dir --arch i386 lenny /mnt/d/debian http://ftp.debian.org/debian
#debootstrap --verbose --include=libdata-sorting-perl,make,automake,zip,bzip2,ftp,wget,lynx,unzip,ncftp,locales,less,mc,lynx,gcc,plplot-bin,libpng12-0,libgd2-noxpm,libstdc++5,libx11-6,emboss --exclude=x11-common --keep-debootstrap-dir --arch i386 lenny /mnt/d/debian http://ftp.debian.org/debian
