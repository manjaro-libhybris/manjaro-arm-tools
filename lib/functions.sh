#! /bin/bash

#variables
SERVER='sync.manjaro-arm.org'
_LIBDIR=/usr/share/manjaro-arm-tools/lib
_BUILDDIR=/var/lib/manjaro-arm-tools/pkg
_PACKAGER=$(cat /etc/makepkg.conf | grep PACKAGER)

#Leave these alone
#_ROOTFS=$_BUILDDIR/$arch
#_REPODIR=$_BUILDDIR/repo
_PKGDIR=/var/cache/manjaro-arm-tools/pkg
_ROOTFS_IMG=/var/lib/manjaro-arm-tools/img
_TMPDIR=/var/lib/manjaro-arm-tools/tmp
IMGDIR=/var/cache/manjaro-arm-tools/img
_IMGNAME=Manjaro-ARM-$edition-$device-$version
PROFILES=/usr/share/manjaro-arm-tools/profiles
OSDN='storage.osdn.net:/storage/groups/m/ma/manjaro-arm/'


usage_deploy_pkg() {
    echo "Usage: ${0##*/} [options]"
    echo "    -a <arch>          Architecture. [Options = any, armv7h or aarch64]"
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
    echo "    -d <device>        Device the image is for."
    echo '    -e <edition>       Edition of the image. [Options = minimal]'
    echo "    -v <version>       Version of the image."
    echo "    -t                 Create a torrent of the image"
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_pkg() {
    echo "Usage: ${0##*/} [options]"
    echo "    -a <arch>          Architecture. [Options = any, armv7h or aarch64]"
    echo "    -p <pkg>           Package to build"
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_img() {
    echo "Usage: ${0##*/} [options]"
    echo "    -d <device>        Device [Options = rpi2, oc1, oc2 and xu4]"
    echo "    -e <edition>       Edition to build [Options = minimal]"
    echo "    -v <version>       Version the resulting image should be named"
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
    mktorrent -a udp://mirror.strits.dk:6969 -v -w https://osdn.net/projects/manjaro-arm/storage/$device/$edition/$version/$image.zip -o $image.zip.torrent $image.zip
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
    #ssh $SERVER 'bash -s' < $_LIBDIR/repo-add.sh "$@"
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
    msg "===== Creating rootfs ====="
    # backup host mirrorlist
    sudo mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-orig

    # Create arm mirrorlist
    echo "Server = http://mirror.strits.dk/manjaro-arm/stable/\$arch/\$repo/" > mirrorlist
    sudo mv mirrorlist /etc/pacman.d/mirrorlist

    # cd to root_fs
    mkdir -p $_BUILDDIR/$arch

    # basescrap the rootfs filesystem
    sudo pacstrap -G -c -C $_LIBDIR/pacman.conf.$arch $_BUILDDIR/$arch base base-devel manjaro-system archlinuxarm-keyring manjaro-keyring lsb-release haveged

    # Enable cross architecture Chrooting
    sudo cp /usr/bin/qemu-arm-static $_BUILDDIR/$arch/usr/bin/
    sudo cp /usr/bin/qemu-aarch64-static $_BUILDDIR/$arch/usr/bin/
    
    #enable qemu binaries
    msg "===== Enabling qemu binaries ====="
    sudo update-binfmts --enable qemu-arm 1> /dev/null 2>&1
    sudo update-binfmts --enable qemu-aarch64 1> /dev/null 2>&1

    # restore original mirrorlist to host system
    sudo mv /etc/pacman.d/mirrorlist-orig /etc/pacman.d/mirrorlist
    sudo pacman -Syy

    msg "===== Creating rootfs user ====="
    sudo systemd-nspawn -D $_BUILDDIR/$arch useradd -m -g users -G wheel,storage,network,power,users -s /bin/bash manjaro 1> /dev/null 2>&1

    msg "===== Configuring rootfs for building ====="
    sudo cp $_LIBDIR/makepkg $_BUILDDIR/$arch/usr/bin/
    sudo systemd-nspawn -D $_BUILDDIR/$arch chmod +x /usr/bin/makepkg 1> /dev/null 2>&1
    sudo systemd-nspawn -D $_BUILDDIR/$arch update-ca-trust 1> /dev/null 2>&1
    sudo systemd-nspawn -D $_BUILDDIR/$arch systemctl enable haveged 1> /dev/null 2>&1
    sudo systemd-nspawn -D $_BUILDDIR/$arch pacman-key --init 1> /dev/null 2>&1
    sudo systemd-nspawn -D $_BUILDDIR/$arch pacman-key --populate archlinuxarm manjaro manjaro-arm 1> /dev/null 2>&1
    sudo sed -i s/'#PACKAGER="John Doe <john@doe.com>"'/"$_PACKAGER"/ $_BUILDDIR/$arch/etc/makepkg.conf
    sudo sed -i s/'#MAKEFLAGS="-j2"'/'MAKEFLAGS=-"j$(nproc)"'/ $_BUILDDIR/$arch/etc/makepkg.conf

}

create_rootfs_img() {
    msg "Creating rootfs for $device..."

    # backup host mirrorlist
    sudo mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-orig

    # Create arm mirrlorlist
    echo "Server = http://mirror.strits.dk/manjaro-arm/stable/\$arch/\$repo/" > mirrorlist
    sudo mv mirrorlist /etc/pacman.d/mirrorlist

    # cd to root_fs
    mkdir -p $_ROOTFS_IMG
    cd $_ROOTFS_IMG

    # create folder for the rootfs
    mkdir -p rootfs_$_ARCH

    # install the rootfs filesystem
    sudo pacstrap -G -c -C $_LIBDIR/pacman.conf.$_ARCH $_ROOTFS_IMG/rootfs_$_ARCH $PKG_DEVICE $PKG_EDITION
    
    # Enable cross architecture Chrooting
    if [[ "device" = "oc2" ]]; then
        sudo cp /usr/bin/qemu-aarch64-static $_ROOTFS_IMG/rootfs_$_ARCH/usr/bin/
        sudo update-binfmts --enable qemu-aarch64 1> /dev/null 2>&1
    else
        sudo cp /usr/bin/qemu-arm-static $_ROOTFS_IMG/rootfs_$_ARCH/usr/bin/
        sudo update-binfmts --enable qemu-arm 1> /dev/null 2>&1
    fi

    msg "Enabling services..."

    # Enable services
    sudo systemd-nspawn -D rootfs_$_ARCH systemctl enable systemd-networkd.service getty.target haveged.service dhcpcd.service resize-fs.service 1> /dev/null 2>&1
    sudo systemd-nspawn -D rootfs_$_ARCH systemctl enable $SRV_EDITION 1> /dev/null 2>&1

    if [[ "$device" = "rpi2" ]] || [[ "$device" = "xu4" ]]; then
        echo ""
    else
        sudo systemd-nspawn -D rootfs_$_ARCH systemctl enable amlogic.service 1> /dev/null 2>&1
    fi

    # restore original mirrorlist to host system
    sudo mv /etc/pacman.d/mirrorlist-orig /etc/pacman.d/mirrorlist
    sudo pacman -Syy

    msg "Setting up users..."
    #setup users
    sudo systemd-nspawn -D rootfs_$_ARCH passwd root < $_LIBDIR/pass-root 1> /dev/null 2>&1
    sudo systemd-nspawn -D rootfs_$_ARCH useradd -m -g users -G wheel,storage,network,power,users -s /bin/bash manjaro 1> /dev/null 2>&1
    sudo systemd-nspawn -D rootfs_$_ARCH passwd manjaro < $_LIBDIR/pass-manjaro 1> /dev/null 2>&1

    msg "Setting up system settings..."
    #system setup
    sudo systemd-nspawn -D rootfs_$_ARCH chmod u+s /usr/bin/ping 1> /dev/null 2>&1
    sudo systemd-nspawn -D rootfs_$_ARCH update-ca-trust 1> /dev/null 2>&1
    sudo cp $_LIBDIR/10-installer $_ROOTFS_IMG/rootfs_$_ARCH/etc/sudoers.d/
    sudo cp $_LIBDIR/resize-sd $_ROOTFS_IMG/rootfs_$_ARCH/usr/bin/
    sudo cp $_LIBDIR/20-wired.network $_ROOTFS_IMG/rootfs_$_ARCH/etc/systemd/network/

    msg "Setting up keyrings..."
    #setup keys
    sudo systemd-nspawn -D rootfs_$_ARCH pacman-key --init 1> /dev/null 2>&1
    sudo systemd-nspawn -D rootfs_$_ARCH pacman-key --populate manjaro archlinuxarm manjaro-arm 1> /dev/null 2>&1

    msg "$device $edition rootfs complete"
}

create_img() {
    msg "Creating image!"

    # Test for device input
    if [[ "$device" != "rpi2" && "$device" != "oc1" && "$device" != "oc2" && "$device" != "xu4" ]]; then
        echo 'Invalid device '$device', please choose one of the following'
        echo 'rpi2  |  oc1  | oc2  |  xu4  '
        exit 1
    else
        _DEVICE="$device"
    fi

    if [[ "$_DEVICE" = "oc2" ]]; then
        _ARCH='aarch64'
    else
        _ARCH='armv7h'
    fi

    if [[ "$edition" = "minimal" ]]; then
        _SIZE=1500
    else
        _SIZE=2000
    fi

    msg "Please ensure that the rootfs is configured and all necessary boot packages are installed"

    ##Image set up
    #making blank .img to be used
    sudo dd if=/dev/zero of=$IMGDIR/$_IMGNAME.img bs=1M count=$_SIZE

    #probing loop into the kernel
    sudo modprobe loop

    #set up loop device
    LDEV=`sudo losetup -f`
    DEV=`echo $LDEV | cut -d "/" -f 3`

    #mount image to loop device
    sudo losetup $LDEV $IMGDIR/$_IMGNAME.img


    # For Raspberry Pi devices
    if [[ "$device" = "rpi2" ]]; then
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
        mkdir -p $_TMPDIR/root
        mkdir -p $_TMPDIR/boot
        sudo mount ${LDEV}p1 $_TMPDIR/boot
        sudo mount ${LDEV}p2 $_TMPDIR/root
        sudo cp -ra $_ROOTFS_IMG/rootfs_$_ARCH/* $_TMPDIR/root/
        sudo mv $_TMPDIR/root/boot/* $_TMPDIR/boot

    #clean up
        sudo umount $_TMPDIR/root
        sudo umount $_TMPDIR/boot
        sudo losetup -d $LDEV
        sudo rm -r $_TMPDIR/root $_TMPDIR/boot
        sudo partprobe $LDEV

    # For Odroid devices
    elif [[ "$device" = "oc1" ]] || [[ "$1" = "oc2" ]] || [[ "$1" = "xu4" ]]; then
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
        mkdir -p $_TMPDIR/root
        sudo chmod 777 -R $_TMPDIR/root
        sudo mount ${LDEV}p1 $_TMPDIR/root
        sudo cp -ra $_ROOTFS_IMG/rootfs_$_ARCH/* $_TMPDIR/root/

    #flash bootloader
        cd $_TMPDIR/root/boot/
        sudo ./sd_fusing.sh $LDEV
        cd ~

    #clean up
        sudo umount $_TMPDIR/root
        sudo losetup -d $LDEV
        sudo rm -r $_TMPDIR/root
        sudo partprobe $LDEV

    else
        #Not sure if this IF statement is nesssary anymore
        echo "The $device" has not been set up yet
    fi
}

create_zip() {
    #zip img
    cd $IMGDIR
    zip -9 $_IMGNAME.zip $_IMGNAME.img 
    sudo rm $IMGDIR/$_IMGNAME.img

    msg "Removing rootfs_$_ARCH"
    sudo rm -rf $_ROOTFS_IMG/rootfs_$_ARCH
}

build_pkg() {
    #cp package to rootfs
    msg "===== Copying build directory {$package} to rootfs ====="
    sudo systemd-nspawn -D $_BUILDDIR/$arch -u manjaro --chdir=/home/manjaro/ mkdir build 1> /dev/null 2>&1
    sudo cp -rp "$package"/* $_BUILDDIR/$arch/home/manjaro/build/

    #build package
    msg "===== Building {$package} ====="
    sudo systemd-nspawn -D $_BUILDDIR/$arch/ -u manjaro --chdir=/home/manjaro/ chmod -R 777 build/ 1> /dev/null 2>&1
    sudo systemd-nspawn -D $_BUILDDIR/$arch/ --chdir=/home/manjaro/build/ makepkg -scr --noconfirm
}

export_and_clean() {
    if ls $_BUILDDIR/$arch/home/manjaro/build/*.pkg.tar.xz* 1> /dev/null 2>&1; then
        #pull package out of rootfs
        msg "!!!!! +++++ ===== Package Succeeded ===== +++++ !!!!!"
        msg "===== Extracting finished package out of rootfs ====="
        mkdir -p $_PKGDIR/$arch
        cp $_BUILDDIR/$arch/home/manjaro/build/*.pkg.tar.xz* $_PKGDIR/$arch/
        msg "+++++ Package saved at $_PKGDIR/$arch/$package*.pkg.tar.xz +++++"

        #clean up rootfs
        msg "===== Cleaning rootfs ====="
        sudo rm -rf $_BUILDDIR/$arch > /dev/null

    else
        msg "!!!!! ++++++ ===== Package failed to build ===== +++++ !!!!!"
        msg "Cleaning rootfs"
        sudo rm -rf $_BUILDDIR/$arch > /dev/null
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
