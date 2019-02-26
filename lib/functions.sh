#! /bin/bash

#variables
SERVER='159.65.88.73'
LIBDIR=/usr/share/manjaro-arm-tools/lib
BUILDDIR=/var/lib/manjaro-arm-tools/pkg
PACKAGER=$(cat /etc/makepkg.conf | grep PACKAGER)
PKGDIR=/var/cache/manjaro-arm-tools/pkg
ROOTFS_IMG=/var/lib/manjaro-arm-tools/img
TMPDIR=/var/lib/manjaro-arm-tools/tmp
IMGDIR=/var/cache/manjaro-arm-tools/img
IMGNAME=Manjaro-ARM-$EDITION-$DEVICE-$VERSION
PROFILES=/usr/share/manjaro-arm-tools/profiles
NSPAWN='sudo systemd-nspawn -q --resolv-conf=copy-host --timezone=off -D'
OSDN='storage.osdn.net:/storage/groups/m/ma/manjaro-arm/'
VERSION=$(date +'%y'.'%m')
ARCH='aarch64'
DEVICE='rpi3'
EDITION='minimal'
USER='manjaro'
PASSWORD='manjaro'

#import conf file
if [[ -f ~/.local/share/manjaro-arm-tools/manjaro-arm-tools.conf ]]; then
source ~/.local/share/manjaro-arm-tools/manjaro-arm-tools.conf 
else
source /etc/manjaro-arm-tools/manjaro-arm-tools.conf 
fi

usage_deploy_pkg() {
    echo "Usage: ${0##*/} [options]"
    echo "    -a <arch>          Architecture. [Default = aarch64. Options = any, armv7h or aarch64]"
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
    echo "    -d <device>        Device the image is for. [Default = rpi3. Options = rpi2, rpi3, oc1, oc2, xu4, rock64, sopine, pine64, pinebook and nyan-big]"
    echo '    -e <edition>       Edition of the image. [Default = minimal. Options = minimal, lxqt, mate and server]'
    echo "    -v <version>       Version of the image. [Default = Current YY.MM]"
    echo "    -t                 Create a torrent of the image"
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_pkg() {
    echo "Usage: ${0##*/} [options]"
    echo "    -a <arch>          Architecture. [Default = aarch64. Options = any, armv7h or aarch64]"
    echo "    -p <pkg>           Package to build"
    echo "    -k                 Keep the previous rootfs for this build"
    echo "    -i <package>       Install local package into image rootfs."
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_img() {
    echo "Usage: ${0##*/} [options]"
    echo "    -d <device>        Device [Default = rpi3. Options = rpi2, rpi3, oc1, oc2, xu4, rock64, sopine, pine64, pinebook and nyan-big]"
    echo "    -e <edition>       Edition to build [Default = minimal. Options = minimal, lxqt, mate and server]"
    echo "    -v <version>       Define the version the resulting image should be named. [Default is current YY.MM]"
    echo "    -u <user>          Username for default user. [Default = manjaro]"
    echo "    -p <password>      Password of default user. [Default = manjaro]"
    echo "    -i <package>       Install local package into image rootfs."
    echo "    -n                 Force download of new rootfs."
    echo "    -x                 Don't compress the image."
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_oem() {
    echo "Usage: ${0##*/} [options]"
    echo "    -d <device>        Device [Default = rpi3. Options = rpi2, rpi3, oc1, oc2, xu4, rock64, sopine, pine64, pinebook and nyan-big]"
    echo "    -e <edition>       Edition to build [Default = minimal. Options = minimal, lxqt, mate and server]"
    echo "    -v <version>       Define the version the resulting image should be named. [Default is current YY.MM]"
    echo "    -i <package>       Install local package into image rootfs."
    echo "    -n                 Force download of new rootfs."
    echo "    -x                 Don't compress the image."
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
 
info() {
    ALL_OFF="\e[1;0m"
    BOLD="\e[1;1m"
    BLUE="${BOLD}\e[1;34m"
      local mesg=$1; shift
      printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
 }
 
get_timer(){
    echo $(date +%s)
}

# $1: start timer
elapsed_time(){
    echo $(echo $1 $(get_timer) | awk '{ printf "%0.2f",($2-$1)/60 }')
}

show_elapsed_time(){
    msg "Time %s: %s minutes..." "$1" "$(elapsed_time $2)"
}
 
sign_pkg() {
    info "Signing [$PACKAGE] with GPG key belonging to $GPGMAIL..."
    gpg --detach-sign -u $GPGMAIL "$PACKAGE"
}

create_torrent() {
    info "Creating torrent of $IMAGE..."
    cd $IMGDIR/
    mktorrent -v -w https://osdn.net/projects/manjaro-arm/storage/$DEVICE/$EDITION/$VERSION/$IMAGE -o $IMAGE.torrent $IMAGE
}

checksum_img() {
    # Create checksums for the image
    info "Creating checksums for [$IMAGE]..."
    cd $IMGDIR/
    sha1sum $IMAGE > $IMAGE.sha1
    sha256sum $IMAGE > $IMAGE.sha256
}

pkg_upload() {
    msg "Uploading package to server..."
    info "Please use your server login details..."
    scp $PACKAGE* $SERVER:/opt/repo/mirror/stable/$ARCH/$REPO/
    #msg "Adding [$PACKAGE] to repo..."
    #info "Please use your server login details..."
    #ssh $SERVER 'bash -s' < $LIBDIR/repo-add.sh "$@"
}

img_upload() {
    # Upload image + checksums to image server
    msg "Uploading image and checksums to server..."
    info "Please use your server login details..."
    rsync -raP $IMAGE* $OSDN/$DEVICE/$EDITION/$VERSION/
}

remove_local_pkg() {
    # remove local packages if remote packages exists, eg, if upload worked
    if ssh $SERVER "[ -f /opt/repo/mirror/stable/$ARCH/$REPO/$PACKAGE ]"; then
    msg "Removing local files..."
    rm $PACKAGE*
    else
    info "Package did not get uploaded correctly! Files not removed..."
    fi
}

create_rootfs_pkg() {
    msg "Building $PACKAGE for $ARCH..."
    # Remove old rootfs if it exists
    if [ -d $BUILDDIR/$ARCH ]; then
    info "Removing old rootfs..."
    sudo rm -rf $BUILDDIR/$ARCH
    fi
    msg "Creating rootfs..."
    # backup host mirrorlist
    sudo mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-orig

    # Create arm mirrorlist
    echo "Server = http://manjaro-arm.moson.eu/stable/\$arch/\$repo/" > mirrorlist
    sudo mv mirrorlist /etc/pacman.d/mirrorlist

    # cd to root_fs
    sudo mkdir -p $BUILDDIR/$ARCH

    # basescrap the rootfs filesystem
    sudo pacstrap -G -c -C $LIBDIR/pacman.conf.$ARCH $BUILDDIR/$ARCH base-devel manjaro-arm-keyring

    # Enable cross architecture Chrooting
    if [[ "$ARCH" = "aarch64" ]]; then
        sudo cp /usr/bin/qemu-aarch64-static $BUILDDIR/$ARCH/usr/bin/
    else
        sudo cp /usr/bin/qemu-arm-static $BUILDDIR/$ARCH/usr/bin/
    fi
    
    # restore original mirrorlist to host system
    sudo mv /etc/pacman.d/mirrorlist-orig /etc/pacman.d/mirrorlist
    sudo pacman -Syy

   msg "Configuring rootfs for building..."
    $NSPAWN $BUILDDIR/$ARCH pacman-key --init 1> /dev/null 2>&1
    $NSPAWN $BUILDDIR/$ARCH pacman-key --populate archlinuxarm manjaro manjaro-arm 1> /dev/null 2>&1
    sudo cp $LIBDIR/makepkg $BUILDDIR/$ARCH/usr/bin/
    $NSPAWN $BUILDDIR/$ARCH chmod +x /usr/bin/makepkg 1> /dev/null 2>&1
    sudo rm -f $BUILDDIR/$ARCH/etc/ssl/certs/ca-certificates.crt
    sudo rm -f $BUILDDIR/$ARCH/etc/ca-certificates/extracted/tls-ca-bundle.pem
    sudo cp -a /etc/ssl/certs/ca-certificates.crt $BUILDDIR/$ARCH/etc/ssl/certs/
    sudo cp -a /etc/ca-certificates/extracted/tls-ca-bundle.pem $BUILDDIR/$ARCH/etc/ca-certificates/extracted/
    sudo sed -i s/'#PACKAGER="John Doe <john@doe.com>"'/"$PACKAGER"/ $BUILDDIR/$ARCH/etc/makepkg.conf
    sudo sed -i s/'#MAKEFLAGS="-j2"'/'MAKEFLAGS=-"j$(nproc)"'/ $BUILDDIR/$ARCH/etc/makepkg.conf
     if [[ ! -z "$ADD_PACKAGE" ]]; then
    info "Installing local package {$ADD_PACKAGE} to rootfs..."
    sudo cp -ap $ADD_PACKAGE $BUILDDIR/$ARCH/var/cache/pacman/pkg/$ADD_PACKAGE
    $NSPAWN $BUILDDIR/$ARCH pacman -U /var/cache/pacman/pkg/$ADD_PACKAGE --noconfirm
    fi
}

create_rootfs_img() {
    msg "Creating install image of $EDITION for $DEVICE..."
    # Remove old rootfs if it exists
    if [ -d $ROOTFS_IMG/rootfs_$ARCH ]; then
    info "Removing old rootfs..."
    sudo rm -rf $ROOTFS_IMG/rootfs_$ARCH
    fi
    mkdir -p $ROOTFS_IMG/rootfs_$ARCH
    if [[ "$KEEPROOTFS" = "false" ]]; then
    sudo rm -rf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz*
    # fetch and extract rootfs
    info "Downloading latest $ARCH rootfs..."
    cd $ROOTFS_IMG
    wget -q --show-progress --progress=bar:force:noscroll https://www.strits.dk/files/Manjaro-ARM-$ARCH-latest.tar.gz
    fi
    #also fetch it, if it does not exist
    if [ ! -f "$ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz" ]; then
    cd $ROOTFS_IMG
    wget -q --show-progress --progress=bar:force:noscroll https://www.strits.dk/files/Manjaro-ARM-$ARCH-latest.tar.gz
    fi
    
    info "Extracting $ARCH rootfs..."
    sudo bsdtar -xpf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz -C $ROOTFS_IMG/rootfs_$ARCH
    
    info "Setting up keyrings..."
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --init 1> /dev/null 2>&1
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --populate archlinuxarm manjaro manjaro-arm 1> /dev/null 2>&1
    
    msg "Installing packages for $EDITION edition on $DEVICE..."
    # Install device and editions specific packages
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -Syyu base $PKG_DEVICE $PKG_EDITION --noconfirm
    if [[ ! -z "$ADD_PACKAGE" ]]; then
    info "Installing local package {$ADD_PACKAGE} to rootfs..."
    sudo cp -ap $ADD_PACKAGE $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg/$ADD_PACKAGE
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -U /var/cache/pacman/pkg/$ADD_PACKAGE --noconfirm
    fi
    
    info "Enabling services..."
    # Enable services
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable systemd-networkd.service getty.target haveged.service dhcpcd.service resize-fs.service 1> /dev/null 2>&1
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable $SRV_EDITION 1> /dev/null 2>&1

    info "Applying overlay for $EDITION edition..."
    sudo cp -ap $PROFILES/arm-profiles/overlays/$EDITION/* $ROOTFS_IMG/rootfs_$ARCH/
    
    info "Setting up users..."
    #setup users
    echo "$USER" > $TMPDIR/user
    echo "$PASSWORD" >> $TMPDIR/password
    echo "$PASSWORD" >> $TMPDIR/password
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH passwd root < $LIBDIR/pass-root 1> /dev/null 2>&1
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH useradd -m -g users -G wheel,storage,network,power,users -s /bin/bash $(cat $TMPDIR/user) 1> /dev/null 2>&1
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH passwd $(cat $TMPDIR/user) < $TMPDIR/password 1> /dev/null 2>&1
    
    info "Enabling user services..."
    if [[ "$EDITION" = "minimal" ]] || [[ "$EDITION" = "server" ]]; then
        info "No user services for $EDITION edition"
    else
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH --user $(cat $TMPDIR/user) systemctl --user enable pulseaudio.service 1> /dev/null 2>&1
    fi

    info "Setting up system settings..."
    #system setup
    sudo rm -f $ROOTFS_IMG/rootfs_$ARCH/etc/ssl/certs/ca-certificates.crt
    sudo rm -f $ROOTFS_IMG/rootfs_$ARCH/etc/ca-certificates/extracted/tls-ca-bundle.pem
    sudo cp -a /etc/ssl/certs/ca-certificates.crt $ROOTFS_IMG/rootfs_$ARCH/etc/ssl/certs/
    sudo cp -a /etc/ca-certificates/extracted/tls-ca-bundle.pem $ROOTFS_IMG/rootfs_$ARCH/etc/ca-certificates/extracted/
    echo "manjaro-arm" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/hostname 1> /dev/null 2>&1
    
    info "Doing device specific setups for $DEVICE..."
    if [[ "$DEVICE" = "rpi2" ]] || [[ "$DEVICE" = "rpi3" ]]; then
        echo "dtparam=audio=on" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/boot/config.txt 1> /dev/null 2>&1
        echo "hdmi_drive=2" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/boot/config.txt 1> /dev/null 2>&1
        echo "audio_pwm_mode=2" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/boot/config.txt 1> /dev/null 2>&1
        echo "/dev/mmcblk0p1  /boot   vfat    defaults        0       0" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/fstab 1> /dev/null 2>&1
    elif [[ "$DEVICE" = "oc1" ]] || [[ "$DEVICE" = "oc2" ]]; then
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable amlogic.service 1> /dev/null 2>&1
    elif [[ "$DEVICE" = "pinebook" ]]; then
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable pinebook-post-install.service 1> /dev/null 2>&1
        #$NSPAWN $ROOTFS_IMG/rootfs_$ARCH --user $(cat $TMPDIR/user) systemctl --user enable pinebook-user.service 1> /dev/null 2>&1
    else
        info "No device specific setups for $DEVICE..."
    fi
    
    info "Cleaning rootfs for unwanted files..."
       if [[ "$DEVICE" = "oc1" ]] || [[ "$DEVICE" = "rpi2" ]] || [[ "$DEVICE" = "xu4" ]] || [[ "$DEVICE" = "nyan-big" ]]; then
        sudo rm $ROOTFS_IMG/rootfs_$ARCH/usr/bin/qemu-arm-static
    else
        sudo rm $ROOTFS_IMG/rootfs_$ARCH/usr/bin/qemu-aarch64-static
    fi
    sudo rm -rf $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg/*
    sudo rm -rf $ROOTFS_IMG/rootfs_$ARCH/var/log/*
    sudo rm -f $TMPDIR/user $TMPDIR/password

    msg "$DEVICE $EDITION rootfs complete"
}

create_rootfs_oem() {
    msg "Creating OEM image of $EDITION for $DEVICE..."
    # Remove old rootfs if it exists
    if [ -d $ROOTFS_IMG/rootfs_$ARCH ]; then
    info "Removing old rootfs..."
    sudo rm -rf $ROOTFS_IMG/rootfs_$ARCH
    fi
    mkdir -p $ROOTFS_IMG/rootfs_$ARCH
    if [[ "$KEEPROOTFS" = "false" ]]; then
    sudo rm -rf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz*
    # fetch and extract rootfs
    info "Downloading latest $ARCH rootfs..."
    cd $ROOTFS_IMG
    wget -q --show-progress --progress=bar:force:noscroll https://www.strits.dk/files/Manjaro-ARM-$ARCH-latest.tar.gz
    fi
    #also fetch it, if it does not exist
    if [ ! -f "$ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz" ]; then
    cd $ROOTFS_IMG
    wget -q --show-progress --progress=bar:force:noscroll https://www.strits.dk/files/Manjaro-ARM-$ARCH-latest.tar.gz
    fi
    
    info "Extracting $ARCH rootfs..."
    sudo bsdtar -xpf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz -C $ROOTFS_IMG/rootfs_$ARCH
    
    info "Setting up keyrings..."
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --init 1> /dev/null 2>&1
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --populate archlinuxarm manjaro manjaro-arm 1> /dev/null 2>&1
    
    msg "Installing packages for $EDITION edition on $DEVICE..."
    # Install device and editions specific packages
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -Syyu base $PKG_DEVICE $PKG_EDITION dialog manjaro-arm-oem-install --noconfirm
    if [[ ! -z "$ADD_PACKAGE" ]]; then
    info "Installing local package {$ADD_PACKAGE} to rootfs..."
    sudo cp -ap $ADD_PACKAGE $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg/$ADD_PACKAGE
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -U /var/cache/pacman/pkg/$ADD_PACKAGE --noconfirm
    fi
    
    info "Enabling services..."
    # Enable services
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable systemd-networkd.service getty.target haveged.service dhcpcd.service resize-fs.service 1> /dev/null 2>&1
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable $SRV_EDITION 1> /dev/null 2>&1
    
    #disabling services depending on edition
    if [[ "$EDITION" = "mate" ]] || [[ "$EDITION" = "i3" ]]; then
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl disable lightdm.service 1> /dev/null 2>&1
    elif [[ "$EDITION" = "gnome" ]]; then
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl disable gdm.service 1> /dev/null 2>&1
    elif [[ "$EDITION" = "minimal" ]] || [[ "$EDITION" = "server" ]]; then
    info "No Display manager in $EDITION..."
    else
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl disable sddm.service 1> /dev/null 2>&1
    fi

    info "Applying overlay for $EDITION edition..."
    sudo cp -ap $PROFILES/arm-profiles/overlays/$EDITION/* $ROOTFS_IMG/rootfs_$ARCH/

    info "Setting up system settings..."
    #system setup
    sudo rm -f $ROOTFS_IMG/rootfs_$ARCH/etc/ssl/certs/ca-certificates.crt
    sudo rm -f $ROOTFS_IMG/rootfs_$ARCH/etc/ca-certificates/extracted/tls-ca-bundle.pem
    sudo cp -a /etc/ssl/certs/ca-certificates.crt $ROOTFS_IMG/rootfs_$ARCH/etc/ssl/certs/
    sudo cp -a /etc/ca-certificates/extracted/tls-ca-bundle.pem $ROOTFS_IMG/rootfs_$ARCH/etc/ca-certificates/extracted/
    echo "manjaro-arm" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/hostname 1> /dev/null 2>&1
    sudo mv $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service.bak
    sudo cp $LIBDIR/getty\@.service $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service
    
    
    info "Doing device specific setups for $DEVICE..."
    if [[ "$DEVICE" = "rpi2" ]] || [[ "$DEVICE" = "rpi3" ]]; then
        echo "dtparam=audio=on" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/boot/config.txt 1> /dev/null 2>&1
        echo "hdmi_drive=2" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/boot/config.txt 1> /dev/null 2>&1
        echo "audio_pwm_mode=2" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/boot/config.txt 1> /dev/null 2>&1
        echo "/dev/mmcblk0p1  /boot   vfat    defaults        0       0" | sudo tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/fstab 1> /dev/null 2>&1
    elif [[ "$DEVICE" = "oc1" ]] || [[ "$DEVICE" = "oc2" ]]; then
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable amlogic.service 1> /dev/null 2>&1
    elif [[ "$DEVICE" = "pinebook" ]]; then
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable pinebook-post-install.service 1> /dev/null 2>&1
        #$NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl --user enable pinebook-user.service 1> /dev/null 2>&1
    else
        info "No device specific setups for $DEVICE..."
    fi
    
    info "Cleaning rootfs for unwanted files..."
       if [[ "$DEVICE" = "oc1" ]] || [[ "$DEVICE" = "rpi2" ]] || [[ "$DEVICE" = "xu4" ]] || [[ "$DEVICE" = "nyan-big" ]]; then
        sudo rm $ROOTFS_IMG/rootfs_$ARCH/usr/bin/qemu-arm-static
    else
        sudo rm $ROOTFS_IMG/rootfs_$ARCH/usr/bin/qemu-aarch64-static
    fi
    sudo rm -rf $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg/*
    sudo rm -rf $ROOTFS_IMG/rootfs_$ARCH/var/log/*
    sudo rm -rf $ROOTFS_IMG/rootfs_$ARCH/etc/*.pacnew

    msg "$DEVICE $EDITION rootfs complete"
}

create_img() {
    # Test for device input
    if [[ "$DEVICE" != "rpi2" && "$DEVICE" != "oc1" && "$DEVICE" != "oc2" && "$DEVICE" != "xu4" && "$DEVICE" != "pinebook" && "$DEVICE" != "sopine" && "$DEVICE" != "pine64" && "$DEVICE" != "rpi3" && "$DEVICE" != "rock64" && "$DEVICE" != "rockpro64" && "$DEVICE" != "nyan-big" ]]; then
        echo 'Invalid device '$DEVICE', please choose one of the following'
        echo 'rpi2
        oc1
        oc2
        xu4
        pinebook
        sopine
        pine64
        rpi3
        rock64
        rockpro64
        nyan-big'
        exit 1
    else
    msg "Finishing image for $DEVICE $EDITION edition..."
    fi

    if [[ "$DEVICE" = "oc1" ]] || [[ "$DEVICE" = "rpi2" ]] || [[ "$DEVICE" = "xu4" ]] || [[ "$DEVICE" = "nyan-big" ]]; then
        ARCH='armv7h'
    else
        ARCH='aarch64'
    fi

    if [[ "$EDITION" = "minimal" ]]; then
        _SIZE=2000
    else
        _SIZE=5000
    fi

    #making blank .img to be used
    sudo dd if=/dev/zero of=$IMGDIR/$IMGNAME.img bs=1M count=$_SIZE 1> /dev/null 2>&1

    #probing loop into the kernel
    sudo modprobe loop 1> /dev/null 2>&1

    #set up loop device
    LDEV=`sudo losetup -f`
    DEV=`echo $LDEV | cut -d "/" -f 3`

    #mount image to loop device
    sudo losetup $LDEV $IMGDIR/$IMGNAME.img 1> /dev/null 2>&1


    ## For Raspberry Pi devices
    if [[ "$DEVICE" = "rpi2" ]] || [[ "$DEVICE" = "rpi3" ]]; then
        #partition with boot and root
        sudo parted -s $LDEV mklabel msdos 1> /dev/null 2>&1
        sudo parted -s $LDEV mkpart primary fat32 0% 100M 1> /dev/null 2>&1
        START=`cat /sys/block/$DEV/${DEV}p1/start`
        SIZE=`cat /sys/block/$DEV/${DEV}p1/size`
        END_SECTOR=$(expr $START + $SIZE)
        sudo parted -s $LDEV mkpart primary ext4 "${END_SECTOR}s" 100% 1> /dev/null 2>&1
        sudo partprobe $LDEV 1> /dev/null 2>&1
        sudo mkfs.vfat "${LDEV}p1" 1> /dev/null 2>&1
        sudo mkfs.ext4 "${LDEV}p2" 1> /dev/null 2>&1

    #copy rootfs contents over to the FS
        mkdir -p $TMPDIR/root
        mkdir -p $TMPDIR/boot
        sudo mount ${LDEV}p1 $TMPDIR/boot
        sudo mount ${LDEV}p2 $TMPDIR/root
        sudo cp -ra $ROOTFS_IMG/rootfs_$ARCH/* $TMPDIR/root/
        sudo mv $TMPDIR/root/boot/* $TMPDIR/boot

    #clean up
        sudo umount $TMPDIR/root
        sudo umount $TMPDIR/boot
        sudo losetup -d $LDEV 1> /dev/null 2>&1
        sudo rm -r $TMPDIR/root $TMPDIR/boot
        sudo partprobe $LDEV 1> /dev/null 2>&1

    ## For Odroid devices
    elif [[ "$DEVICE" = "oc1" ]] || [[ "$DEVICE" = "oc2" ]] || [[ "$DEVICE" = "xu4" ]]; then
        #Clear first 8mb
        sudo dd if=/dev/zero of=${LDEV} bs=1M count=8 1> /dev/null 2>&1
	
    #partition with a single root partition
        sudo parted -s $LDEV mklabel msdos 1> /dev/null 2>&1
        sudo parted -s $LDEV mkpart primary ext4 0% 100% 1> /dev/null 2>&1
        sudo partprobe $LDEV 1> /dev/null 2>&1
        sudo mkfs.ext4 -O ^metadata_csum,^64bit ${LDEV}p1 1> /dev/null 2>&1

    #copy rootfs contents over to the FS
        mkdir -p $TMPDIR/root
        sudo chmod 777 -R $TMPDIR/root
        sudo mount ${LDEV}p1 $TMPDIR/root
        sudo cp -ra $ROOTFS_IMG/rootfs_$ARCH/* $TMPDIR/root/

    #flash bootloader
        cd $TMPDIR/root/boot/
        sudo ./sd_fusing.sh $LDEV 1> /dev/null 2>&1
        cd ~

    #clean up
        sudo umount $TMPDIR/root
        sudo losetup -d $LDEV 1> /dev/null 2>&1
        sudo rm -r $TMPDIR/root
        sudo partprobe $LDEV 1> /dev/null 2>&1

    ## For pine devices
    elif [[ "$DEVICE" = "pinebook" ]] || [[ "$DEVICE" = "sopine" ]] || [[ "$DEVICE" = "pine64" ]]; then

    #Clear first 8mb
        sudo dd if=/dev/zero of=${LDEV} bs=1M count=8 1> /dev/null 2>&1
	
    #partition with a single root partition
        sudo parted -s $LDEV mklabel msdos 1> /dev/null 2>&1
        sudo parted -s $LDEV mkpart primary ext4 0% 100% 1> /dev/null 2>&1
        sudo partprobe $LDEV 1> /dev/null 2>&1
        sudo mkfs.ext4 -O ^metadata_csum,^64bit ${LDEV}p1 1> /dev/null 2>&1

    #copy rootfs contents over to the FS
        mkdir -p $TMPDIR/root
        sudo chmod 777 -R $TMPDIR/root
        sudo mount ${LDEV}p1 $TMPDIR/root
        sudo cp -ra $ROOTFS_IMG/rootfs_$ARCH/* $TMPDIR/root/
        
    #flash bootloader
        sudo dd if=$TMPDIR/root/boot/u-boot-sunxi-with-spl-$DEVICE.bin of=${LDEV} bs=8k seek=1 1> /dev/null 2>&1

    #clean up
        sudo umount $TMPDIR/root
        sudo losetup -d $LDEV 1> /dev/null 2>&1
        sudo rm -r $TMPDIR/root
        sudo partprobe $LDEV 1> /dev/null 2>&1
        
    ## For rockchip devices
    elif [[ "$DEVICE" = "rock64" ]] || [[ "$DEVICE" = "rockpro64" ]]; then

    #Clear first 32mb
        sudo dd if=/dev/zero of=${LDEV} bs=1M count=32 1> /dev/null 2>&1
	
    #partition with a single root partition
        sudo parted -s $LDEV mklabel msdos 1> /dev/null 2>&1
        sudo parted -s $LDEV mkpart primary ext4 32M 100% 1> /dev/null 2>&1
        sudo partprobe $LDEV 1> /dev/null 2>&1
        sudo mkfs.ext4 -O ^metadata_csum,^64bit ${LDEV}p1 1> /dev/null 2>&1

    #copy rootfs contents over to the FS
        mkdir -p $TMPDIR/root
        sudo chmod 777 -R $TMPDIR/root
        sudo mount ${LDEV}p1 $TMPDIR/root
        sudo cp -ra $ROOTFS_IMG/rootfs_$ARCH/* $TMPDIR/root/
        
    #flash bootloader
        sudo dd if=$TMPDIR/root/boot/idbloader.img of=${LDEV} seek=64 conv=notrunc 1> /dev/null 2>&1
        sudo dd if=$TMPDIR/root/boot/uboot.img of=${LDEV} seek=16384 conv=notrunc 1> /dev/null 2>&1
        sudo dd if=$TMPDIR/root/boot/trust.img of=${LDEV} seek=24576 conv=notrunc 1> /dev/null 2>&1
        
    #clean up
        sudo umount $TMPDIR/root
        sudo losetup -d $LDEV 1> /dev/null 2>&1
        sudo rm -r $TMPDIR/root
        sudo partprobe $LDEV 1> /dev/null 2>&1
        
    # RockPro64 uses EFI it seems
    #elif [[ "$DEVICE" = "rockpro64" ]]; then
    
    #Clear first 32mb
        #sudo dd if=/dev/zero of=${LDEV} bs=1M count=32 1> /dev/null 2>&1
	
    #partition with boot and root
        #sudo parted -s $LDEV mklabel gpt 1> /dev/null 2>&1
        #sudo parted -s $LDEV mkpart primary fat16 32M 128M 1> /dev/null 2>&1
        #START=`cat /sys/block/$DEV/${DEV}p1/start`
        #SIZE=`cat /sys/block/$DEV/${DEV}p1/size`
        #END_SECTOR=$(expr $START + $SIZE)
        #sudo parted -s $LDEV mkpart primary ext4 "${END_SECTOR}s" 100% 1> /dev/null 2>&1
        #sudo partprobe $LDEV 1> /dev/null 2>&1
        #sudo mkfs.vfat "${LDEV}p1" -n boot 1> /dev/null 2>&1
        #sudo mkfs.ext4 -O ^metadata_csum,^64bit ${LDEV}p2 -L linux-root 1> /dev/null 2>&1

    #copy rootfs contents over to the FS
        #mkdir -p $TMPDIR/root
        #mkdir -p $TMPDIR/boot
        #sudo mount ${LDEV}p1 $TMPDIR/boot
        #sudo mount ${LDEV}p2 $TMPDIR/root
        #sudo cp -ra $ROOTFS_IMG/rootfs_$ARCH/* $TMPDIR/root/
        #sudo mv $TMPDIR/root/boot/* $TMPDIR/boot
        
    #flash bootloader
        #sudo dd if=$TMPDIR/boot/idbloader.img of=${LDEV} seek=64 conv=notrunc 1> /dev/null 2>&1
        #sudo dd if=$TMPDIR/boot/uboot.img of=${LDEV} seek=16384 conv=notrunc 1> /dev/null 2>&1
        #sudo dd if=$TMPDIR/boot/trust.img of=${LDEV} seek=24576 conv=notrunc 1> /dev/null 2>&1
        
    #clean up
        #sudo umount $TMPDIR/root
        #sudo umount $TMPDIR/boot
        #sudo losetup -d $LDEV 1> /dev/null 2>&1
        #sudo rm -r $TMPDIR/root $TMPDIR/boot
        #sudo partprobe $LDEV 1> /dev/null 2>&1
        
    elif [[ "$DEVICE" = "nyan-big" ]]; then
	
    #partition with boot and root
        if [ ! -f /usr/bin/sgdisk ]; then
        info "gptfdisk is not installed. Please install it and try again..."
        exit 1
        fi

	    sudo sgdisk -a 64 -n 1:0:+16M -t 1:7F00 -c 1:"KERN-A" -A 1:=:0x0105000000000000 -n 2:0:0 -t 2:7F01 -c 2:"ROOT-A" $LDEV

	    sync
	    sudo partprobe $LDEV
	    sudo partprobe
	    sudo mkfs.ext4 -L ROOT ${LDEV}p2
        

    #copy rootfs contents over to the FS
        mkdir -p $TMPDIR/root
        sudo mount ${LDEV}p2 $TMPDIR/root
        sudo cp -ra $ROOTFS_IMG/rootfs_$ARCH/* $TMPDIR/root/
        
    #flash bootloader
	sudo dd if=/dev/zero of=${LDEV}p1
	#flash u-boot or linux-nyan-chromebook kpart..
	    #sudo dd if=$TMPDIR/root/boot/u-boot.kpart of=${LDEV}p1
        sudo dd if=$TMPDIR/root/boot/vmlinux.kpart of=${LDEV}p1 
        
    #clean up
        sudo umount $TMPDIR/root
        sudo losetup -d $LDEV 1> /dev/null 2>&1
        sudo rm -r $TMPDIR/root
        sudo partprobe $LDEV 1> /dev/null 2>&1


    else
        #Not sure if this IF statement is nesssary anymore
        info "The $DEVICE" has not been set up yet
    fi
}

create_zip() {
    info "Compressing $IMGNAME.img..."
    #zip img
    cd $IMGDIR
    xz -zv --threads=0 $IMGNAME.img

    info "Removing rootfs_$ARCH"
    sudo rm -rf $ROOTFS_IMG/rootfs_$ARCH
}

build_pkg() {
    #cp package to rootfs
    msg "Copying build directory {$PACKAGE} to rootfs..."
    $NSPAWN $BUILDDIR/$ARCH mkdir build 1> /dev/null 2>&1
    sudo cp -rp "$PACKAGE"/* $BUILDDIR/$ARCH/build/

    #build package
    msg "Building {$PACKAGE}..."
    $NSPAWN $BUILDDIR/$ARCH/ chmod -R 777 build/ 1> /dev/null 2>&1
    $NSPAWN $BUILDDIR/$ARCH/ --chdir=/build/ makepkg -sc --noconfirm
}

export_and_clean() {
    if ls $BUILDDIR/$ARCH/build/*.pkg.tar.xz* 1> /dev/null 2>&1; then
        #pull package out of rootfs
        msg "Package Succeeded..."
        info "Extracting finished package out of rootfs..."
        mkdir -p $PKGDIR/$ARCH
        cp $BUILDDIR/$ARCH/build/*.pkg.tar.xz* $PKGDIR/$ARCH/
        msg "Package saved as {$PACKAGE} in {$PKGDIR/$ARCH}..."

        #clean up rootfs
        info "Cleaning build files from rootfs"
        sudo rm -rf $BUILDDIR/$ARCH/build/

    else
        msg "!!!!! Package failed to build !!!!!"
        info "Cleaning build files from rootfs"
        sudo rm -rf $BUILDDIR/$ARCH/build/
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
