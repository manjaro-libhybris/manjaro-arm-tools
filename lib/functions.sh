#! /bin/bash

#variables
SERVER='sync.manjaro-arm.org'
LIBDIR=/usr/share/manjaro-arm-tools/lib
BUILDDIR=/var/lib/manjaro-arm-tools/pkg
PACKAGER=$(cat /etc/makepkg.conf | grep PACKAGER)

#Leave these alone
PKGDIR=/var/cache/manjaro-arm-tools/pkg
ROOTFS_IMG=/var/lib/manjaro-arm-tools/img
TMPDIR=/var/lib/manjaro-arm-tools/tmp
IMGDIR=/var/cache/manjaro-arm-tools/img
IMGNAME=Manjaro-ARM-$edition-$device-$version
PROFILES=/usr/share/manjaro-arm-tools/profiles
OSDN='storage.osdn.net:/storage/groups/m/ma/manjaro-arm/'
version=$(date +'%y'.'%m')
arch='armv7h'
device='rpi2'

#import conf file
if [[ -f ~/.local/share/manjaro-arm-tools/manjaro-arm-tools.conf ]]; then
source ~/.local/share/manjaro-arm-tools/manjaro-arm-tools.conf 
else
source /etc/manjaro-arm-tools/manjaro-arm-tools.conf 
fi

usage_deploy_pkg() {
    echo "Usage: ${0##*/} [options]"
    echo "    -a <arch>          Architecture. [Default = armv7h. Options = any, armv7h or aarch64]"
    echo "    -p <pkg>           Package to upload"
    echo '    -r <repo>          Repository package belongs to. [Options = core, extra or community]'
    echo "    -k <gpg key ID>    Email address associated with the GPG key to use for signing"
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_deploy_img() {
    echo "Usage: ${0##*/} [options]"
    echo "    -i <image>         Image to upload. Should be a .zip file."
    echo "    -d <device>        Device the image is for. [Default = rpi2. Options = rpi2, rpi3, oc1, oc2, xu4 and pine64]"
    echo '    -e <edition>       Edition of the image. [Options = minimal]'
    echo "    -v <version>       Version of the image. [Default = Current YY.MM]"
    echo "    -t                 Create a torrent of the image"
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_pkg() {
    echo "Usage: ${0##*/} [options]"
    echo "    -a <arch>          Architecture. [Default = armv7h. Options = any, armv7h or aarch64]"
    echo "    -p <pkg>           Package to build"
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_img() {
    echo "Usage: ${0##*/} [options]"
    echo "    -d <device>        Device [Default = rpi2. Options = rpi2, rpi3, oc1, oc2, xu4 and pine64]"
    echo "    -e <edition>       Edition to build [Options = minimal, lxqt, mate and server]"
    echo "    -v <version>       Define the version the resulting image should be named. [Default is current YY.MM]"
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

 msg() {
    ALL_OFF="\e[1;0m"
    BOLD="\e[1;1m"
    GREEN="${BOLD}\e[1;32m"
      local mesg=$1; shift
      printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
 }
 
 sign_pkg() {
    msg "Signing [$package] with GPG key belonging to $gpgmail..."
    gpg --detach-sign -u $gpgmail "$package"
}

create_torrent() {
    msg "Creating torrent of $image..."
    cd $IMGDIR/
    mktorrent -a udp://mirror.strits.dk:6969 -v -w https://osdn.net/projects/manjaro-arm/storage/$device/$edition/$version/$image -o $image.torrent $image
}

checksum_img() {
    # Create checksums for the image
    msg "Creating checksums for [$image]..."
    cd $IMGDIR/
    sha1sum $image > $image.sha1
    sha256sum $image > $image.sha256
}

pkg_upload() {
    msg "Uploading package to server..."
    echo "Please use your server login details..."
    scp $package* $SERVER:/opt/repo/mirror/stable/$arch/$repo/
    #msg "Adding [$package] to repo..."
    #echo "Please use your server login details..."
    #ssh $SERVER 'bash -s' < $LIBDIR/repo-add.sh "$@"
}

img_upload() {
    # Upload image + checksums to image server
    msg "Uploading image and checksums to server..."
    echo "Please use your server login details..."
    rsync -raP $image* $OSDN/$device/$edition/$version/
}

remove_local_pkg() {
    msg "Removing local files..."
    rm $package*
}

create_rootfs_pkg() {
    msg "Creating rootfs..."
    # backup host mirrorlist
    sudo mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-orig

    # Create arm mirrorlist
    echo "Server = http://mirrors.dotsrc.org/manjaro-arm/stable/\$arch/\$repo/" > mirrorlist
    sudo mv mirrorlist /etc/pacman.d/mirrorlist

    # cd to root_fs
    mkdir -p $BUILDDIR/$arch

    # basescrap the rootfs filesystem
    sudo pacstrap -G -c -C $LIBDIR/pacman.conf.$arch $BUILDDIR/$arch base base-devel manjaro-system archlinuxarm-keyring manjaro-keyring lsb-release

    # Enable cross architecture Chrooting
    if [[ "$arch" = "aarch64" ]]; then
        sudo cp /usr/bin/qemu-aarch64-static $_BUILDIR/$arch/usr/bin/
    else
        sudo cp /usr/bin/qemu-arm-static $BUILDDIR/$arch/usr/bin/
    fi
    
    # restore original mirrorlist to host system
    sudo mv /etc/pacman.d/mirrorlist-orig /etc/pacman.d/mirrorlist
    sudo pacman -Syy

   msg "Configuring rootfs for building..."
    sudo cp $LIBDIR/makepkg $BUILDDIR/$arch/usr/bin/
    sudo systemd-nspawn -D $BUILDDIR/$arch chmod +x /usr/bin/makepkg 1> /dev/null 2>&1
    sudo rm -f $BUILDDIR/$arch/etc/ssl/certs/ca-certificates.crt
    sudo rm -f $BUILDDIR/$arch/etc/ca-certificates/extracted/tls-ca-bundle.pem
    sudo cp -a /etc/ssl/certs/ca-certificates.crt $BUILDDIR/$arch/etc/ssl/certs/
    sudo cp -a /etc/ca-certificates/extracted/tls-ca-bundle.pem $BUILDDIR/$arch/etc/ca-certificates/extracted/
#    sudo systemd-nspawn -D $BUILDDIR/$arch update-ca-trust 1> /dev/null 2>&1
    sudo systemd-nspawn -D $BUILDDIR/$arch pacman-key --init 1> /dev/null 2>&1
    sudo systemd-nspawn -D $BUILDDIR/$arch pacman-key --populate archlinuxarm manjaro manjaro-arm 1> /dev/null 2>&1
    sudo sed -i s/'#PACKAGER="John Doe <john@doe.com>"'/"$PACKAGER"/ $BUILDDIR/$arch/etc/makepkg.conf
    sudo sed -i s/'#MAKEFLAGS="-j2"'/'MAKEFLAGS=-"j$(nproc)"'/ $BUILDDIR/$arch/etc/makepkg.conf
}

create_rootfs_img() {
    msg "Creating rootfs for $device..."

    # backup host mirrorlist
    sudo mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-orig

    # Create arm mirrlorlist
    echo "Server = http://mirrors.dotsrc.org/manjaro-arm/stable/\$arch/\$repo/" > mirrorlist
    sudo mv mirrorlist /etc/pacman.d/mirrorlist

    # cd to root_fs
    mkdir -p $ROOTFS_IMG
    cd $ROOTFS_IMG

    # create folder for the rootfs
    mkdir -p rootfs_$_ARCH

    # install the rootfs filesystem
    sudo pacstrap -G -c -C $LIBDIR/pacman.conf.$_ARCH $ROOTFS_IMG/rootfs_$_ARCH $PKG_DEVICE $PKG_EDITION
    
    # Enable cross architecture Chrooting
    if [[ "$device" = "oc2" ]] || [[ "$device" = "pine64" ]] || [[ "$device" = "rpi3" ]]; then
        sudo cp /usr/bin/qemu-aarch64-static $ROOTFS_IMG/rootfs_$_ARCH/usr/bin/
    else
        sudo cp /usr/bin/qemu-arm-static $ROOTFS_IMG/rootfs_$_ARCH/usr/bin/
    fi

    msg "Enabling services..."

    # Enable services
    sudo systemd-nspawn -D rootfs_$_ARCH systemctl enable systemd-networkd.service getty.target haveged.service dhcpcd.service resize-fs.service 1> /dev/null 2>&1
    sudo systemd-nspawn -D rootfs_$_ARCH systemctl enable $SRV_EDITION 1> /dev/null 2>&1

    if [[ "$device" = "rpi2" ]] || [[ "$device" = "xu4" ]] || [[ "$device" = "pine64" ]] || [[ "$device" = "rpi3" ]]; then
        echo ""
    else
        sudo systemd-nspawn -D rootfs_$_ARCH systemctl enable amlogic.service 1> /dev/null 2>&1
    fi

    # restore original mirrorlist to host system
    sudo mv /etc/pacman.d/mirrorlist-orig /etc/pacman.d/mirrorlist
    sudo pacman -Syy

    msg "Applying overlay for $edition..."
    sudo cp -ap $PROFILES/arm-profiles/overlays/$edition/* $ROOTFS_IMG/rootfs_$_ARCH/
    
    msg "Setting up users..."
    #setup users
    sudo systemd-nspawn -D rootfs_$_ARCH passwd root < $LIBDIR/pass-root 1> /dev/null 2>&1
    sudo systemd-nspawn -D rootfs_$_ARCH useradd -m -g users -G wheel,storage,network,power,users -s /bin/bash manjaro 1> /dev/null 2>&1
    sudo systemd-nspawn -D rootfs_$_ARCH passwd manjaro < $LIBDIR/pass-manjaro 1> /dev/null 2>&1

    msg "Setting up system settings..."
    #system setup
    sudo systemd-nspawn -D rootfs_$_ARCH chmod u+s /usr/bin/ping 1> /dev/null 2>&1
    sudo systemd-nspawn -D rootfs_$_ARCH update-ca-trust 1> /dev/null 2>&1

    msg "Setting up keyrings..."
    #setup keys
    sudo systemd-nspawn -D rootfs_$_ARCH pacman-key --init 1> /dev/null 2>&1
    sudo systemd-nspawn -D rootfs_$_ARCH pacman-key --populate manjaro archlinuxarm manjaro-arm 1> /dev/null 2>&1
    
    msg "Cleaning rootfs for unwanted files..."
       if [[ "$device" = "oc2" ]] || [[ "$device" = "pine64" ]] || [[ "$device" = "rpi3" ]]; then
        sudo rm $ROOTFS_IMG/rootfs_$_ARCH/usr/bin/qemu-aarch64-static
    else
        sudo rm $ROOTFS_IMG/rootfs_$_ARCH/usr/bin/qemu-arm-static
    fi


    msg "$device $edition rootfs complete"
}

create_img() {
    msg "Creating image!"

    # Test for device input
    if [[ "$device" != "rpi2" && "$device" != "oc1" && "$device" != "oc2" && "$device" != "xu4" && "$device" != "pine64" && "$device" != "rpi3" ]]; then
        echo 'Invalid device '$device', please choose one of the following'
        echo 'rpi2  |  oc1  | oc2  |  xu4 | pine64 | rpi3'
        exit 1
    else
        _DEVICE="$device"
    fi

    if [[ "$_DEVICE" = "oc2" ]] || [[ "$_DEVICE" = "pine64" ]] || [[ "$_DEVICE" = "rpi3" ]]; then
        _ARCH='aarch64'
    else
        _ARCH='armv7h'
    fi

    if [[ "$edition" = "minimal" ]]; then
        _SIZE=1500
    else
        _SIZE=3800
    fi

    msg "Please ensure that the rootfs is configured and all necessary boot packages are installed"

    ##Image set up
    #making blank .img to be used
    sudo dd if=/dev/zero of=$IMGDIR/$IMGNAME.img bs=1M count=$_SIZE

    #probing loop into the kernel
    sudo modprobe loop

    #set up loop device
    LDEV=`sudo losetup -f`
    DEV=`echo $LDEV | cut -d "/" -f 3`

    #mount image to loop device
    sudo losetup $LDEV $IMGDIR/$IMGNAME.img


    # For Raspberry Pi devices
    if [[ "$device" = "rpi2" ]] || [[ "$device" = "rpi3" ]]; then
        #partition with boot and root
        sudo parted -s $LDEV mklabel msdos
        sudo parted -s $LDEV mkpart primary fat32 0% 100M
        START=`cat /sys/block/$DEV/${DEV}p1/start`
        SIZE=`cat /sys/block/$DEV/${DEV}p1/size`
        END_SECTOR=$(expr $START + $SIZE)
        sudo parted -s $LDEV mkpart primary ext4 "${END_SECTOR}s" 100%
        sudo partprobe $LDEV
        sudo mkfs.vfat "${LDEV}p1"
        sudo mkfs.ext4 "${LDEV}p2"

    #copy rootfs contents over to the FS
        mkdir -p $TMPDIR/root
        mkdir -p $TMPDIR/boot
        sudo mount ${LDEV}p1 $TMPDIR/boot
        sudo mount ${LDEV}p2 $TMPDIR/root
        sudo cp -ra $ROOTFS_IMG/rootfs_$_ARCH/* $TMPDIR/root/
        sudo mv $TMPDIR/root/boot/* $TMPDIR/boot

    #clean up
        sudo umount $TMPDIR/root
        sudo umount $TMPDIR/boot
        sudo losetup -d $LDEV
        sudo rm -r $TMPDIR/root $TMPDIR/boot
        sudo partprobe $LDEV

    # For Odroid devices
    elif [[ "$device" = "oc1" ]] || [[ "$device" = "oc2" ]] || [[ "$device" = "xu4" ]]; then
        #Clear first 8mb
        sudo dd if=/dev/zero of=${LDEV} bs=1M count=8
	
    #partition with a single root partition
        sudo parted -s $LDEV mklabel msdos
        sudo parted -s $LDEV mkpart primary ext4 0% 100%
        sudo partprobe $LDEV
    #if [[ "$_DEVICE" = "xu4" ]]; then
    #	sudo mkfs.ext4 "${LDEV}p1"
    #else
        sudo mkfs.ext4 -O ^metadata_csum,^64bit ${LDEV}p1
    #fi

    #copy rootfs contents over to the FS
        mkdir -p $TMPDIR/root
        sudo chmod 777 -R $TMPDIR/root
        sudo mount ${LDEV}p1 $TMPDIR/root
        sudo cp -ra $ROOTFS_IMG/rootfs_$_ARCH/* $TMPDIR/root/

    #flash bootloader
        cd $TMPDIR/root/boot/
        sudo ./sd_fusing.sh $LDEV
        cd ~

    #clean up
        sudo umount $TMPDIR/root
        sudo losetup -d $LDEV
        sudo rm -r $TMPDIR/root
        sudo partprobe $LDEV

    # For Pine64 device
    elif [[ "$device" = "pine64" ]]; then
        partition with boot and root
        sudo parted -s $LDEV mklabel msdos
        sudo parted -s $LDEV mkpart primary fat32 0% 100M
        START=`cat /sys/block/$DEV/${DEV}p1/start`
        SIZE=`cat /sys/block/$DEV/${DEV}p1/size`
        END_SECTOR=$(expr $START + $SIZE)
        sudo parted -s $LDEV mkpart primary ext4 "${END_SECTOR}s" 100%
        sudo partprobe $LDEV
        sudo mkfs.vfat "${LDEV}p1"
        sudo mkfs.ext4 "${LDEV}p2"

    #copy rootfs contents over to the FS
        mkdir -p $TMPDIR/root
        mkdir -p $TMPDIR/boot
        sudo mount ${LDEV}p1 $TMPDIR/boot
        sudo mount ${LDEV}p2 $TMPDIR/root
        sudo cp -ra $ROOTFS_IMG/rootfs_$_ARCH/* $TMPDIR/root/
        sudo mv $TMPDIR/root/boot/* $TMPDIR/boot
        
    #flash bootloader
        #sudo wget http://os.archlinuxarm.org/os/allwinner/boot/pine64/boot.scr -O $TMPDIR/root/boot/boot.scr
        #sudo dd if=$TMPDIR/root/boot/u-boot-sunxi-with-spl.bin of=${LDEV} bs=8k seek=1

    #clean up
        sudo umount $TMPDIR/root
        sudo umount $TMPDIR/boot
        sudo losetup -d $LDEV
        sudo rm -r $TMPDIR/root $TMPDIR/boot
        sudo partprobe $LDEV

    else
        #Not sure if this IF statement is nesssary anymore
        echo "The $device" has not been set up yet
    fi
}

create_zip() {
    #zip img
    cd $IMGDIR
    zip -9 $IMGNAME.zip $IMGNAME.img 
    sudo rm $IMGDIR/$IMGNAME.img

    msg "Removing rootfs_$_ARCH"
    sudo rm -rf $ROOTFS_IMG/rootfs_$_ARCH
}

build_pkg() {
    #cp package to rootfs
    msg "Copying build directory {$package} to rootfs..."
    sudo systemd-nspawn -D $BUILDDIR/$arch mkdir build 1> /dev/null 2>&1
    sudo cp -rp "$package"/* $BUILDDIR/$arch/build/

    #build package
    msg "Building {$package}..."
    sudo systemd-nspawn -D $BUILDDIR/$arch/ chmod -R 777 build/ 1> /dev/null 2>&1
    sudo systemd-nspawn -D $BUILDDIR/$arch/ --chdir=/build/ makepkg -sc --noconfirm
}

export_and_clean() {
    if ls $BUILDDIR/$arch/build/*.pkg.tar.xz* 1> /dev/null 2>&1; then
        #pull package out of rootfs
        msg "Package Succeeded..."
        msg "Extracting finished package out of rootfs..."
        mkdir -p $PKGDIR/$arch
        cp $BUILDDIR/$arch/build/*.pkg.tar.xz* $PKGDIR/$arch/
        msg "Package saved at $PKGDIR/$arch/$package..."

        #clean up rootfs
        msg "Cleaning rootfs..."
        sudo rm -rf $BUILDDIR/$arch > /dev/null

    else
        msg "!!!!! Package failed to build !!!!!"
        msg "Cleaning rootfs"
        sudo rm -rf $BUILDDIR/$arch > /dev/null
        exit 1
    fi
}

get_profiles() {
    if ls $PROFILES/arm-profiles/* 1> /dev/null 2>&1; then
        cd $PROFILES/arm-profiles
        git pull
    else
        cd $PROFILES
        git clone https://gitlab.com/Strit/arm-profiles.git
    fi
}
