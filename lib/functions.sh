#! /bin/bash

#variables
SERVER='sync.manjaro-arm.org'
_LIBDIR=/usr/share/manjaro-arm-tools/lib
_BUILDDIR=/var/lib/manjaro-arm-tools/pkg
_PACKAGER=$(cat /etc/makepkg.conf | grep PACKAGER)

#Leave these alone
_ROOTFS=$_BUILDDIR/$arch
_REPODIR=$_BUILDDIR/repo
_PKGDIR=/var/cache/manjaro-arm-tools/pkg

usage_deploy_pkg() {
    echo "Usage: ${0##*/} [options]"
    echo "    -a <arch>          Architecture. [Options = any, armv7h or aarch64]"
    echo "    -p <pkg>           Package to upload"
    echo '    -r <repo>          Repository package belongs to. [Options = core, extra or community]'
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

 msg() {
    ALL_OFF="\e[1;0m"
    BOLD="\e[1;1m"
    GREEN="${BOLD}\e[1;32m"
      local mesg=$1; shift
      printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
 }
 
 sign_pkg() {
    msg "Signing [$package] with users GPG key..."
    gpg --detach-sign "$package"
}

pkg_upload() {
    msg "Uploading package to server..."
    echo "Please use your server login details..."
    scp $package* $SERVER:/opt/repo/mirror/stable/$arch/$repo/
    msg "Adding [$package] to repo..."
    echo "Please use your server login details..."
    ssh $SERVER 'bash -s' < $_LIBDIR/repo-add.sh "$@"
}

remove_local_files() {
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
    mkdir -p $_ROOTFS

    # basescrap the rootfs filesystem
    basestrap -G -C $_LIBDIR/pacman.conf.$arch $_ROOTFS base base-devel manjaro-system archlinuxarm-keyring manjaro-keyring lsb-release haveged

    # Enable cross architecture Chrooting
    sudo cp /usr/bin/qemu-arm-static $_ROOTFS/usr/bin/
    sudo cp /usr/bin/qemu-aarch64-static $_ROOTFS/usr/bin/
    
    #enable qemu binaries
    msg "===== Enabling qemu binaries ====="
    sudo update-binfmts --enable qemu-arm
    sudo update-binfmts --enable qemu-aarch64 

    # restore original mirrorlist to host system
    sudo mv /etc/pacman.d/mirrorlist-orig /etc/pacman.d/mirrorlist
    sudo pacman -Syy

    msg "===== Creating rootfs user ====="
    sudo systemd-nspawn -D $_ROOTFS useradd -m -g users -G wheel,storage,network,power,users -s /bin/bash manjaro

    msg "===== Configuring rootfs for building ====="
    sudo cp $_LIBDIR/makepkg $_ROOTFS/usr/bin/
    sudo systemd-nspawn -D $_ROOTFS chmod +x /usr/bin/makepkg
    sudo systemd-nspawn -D $_ROOTFS update-ca-trust
    sudo systemd-nspawn -D $_ROOTFS systemctl enable haveged
    sudo systemd-nspawn -D $_ROOTFS pacman-key --init
    sudo systemd-nspawn -D $_ROOTFS pacman-key --populate archlinuxarm manjaro manjaro-arm
    sudo sed -i s/'#PACKAGER="John Doe <john@doe.com>"'/"$_PACKAGER"/ $_ROOTFS/etc/makepkg.conf
    sudo sed -i s/'#MAKEFLAGS="-j2"'/'MAKEFLAGS=-"j$(nproc)"'/ $_ROOTFS/etc/makepkg.conf

}

build_pkg() {
    #cp package to rootfs
    msg "===== Copying build directory {$package} to rootfs ====="
    sudo systemd-nspawn -D $_ROOTFS -u manjaro --chdir=/home/manjaro/ mkdir build
    sudo cp -rp "$package"/* $_ROOTFS/home/manjaro/build/

    #build package
    msg "===== Building {$package} ====="
    sudo systemd-nspawn -D $_ROOTFS/ -u manjaro --chdir=/home/manjaro/ chmod -R 777 build/
    sudo systemd-nspawn -D $_ROOTFS/ --chdir=/home/manjaro/build/ makepkg -scr --noconfirm
}

export_and_clean() {
    if ls $_ROOTFS/home/manjaro/build/*.pkg.tar.xz* 1> /dev/null 2>&1; then
        #pull package out of rootfs
        msg "!!!!! +++++ ===== Package Succeeded ===== +++++ !!!!!"
        msg "===== Extracting finished package out of rootfs ====="
        mkdir -p $_PKGDIR/$arch
        cp $_ROOTFS/home/manjaro/build/*.pkg.tar.xz* $_PKGDIR/$arch/
        msg "+++++ Package saved at $_PKGDIR/$arch/$package*.pkg.tar.xz +++++"

        #clean up rootfs
        msg "===== Cleaning rootfs ====="
        sudo rm -rf $_ROOTFS > /dev/null

    else
        msg "!!!!! ++++++ ===== Package failed to build ===== +++++ !!!!!"
        msg "Cleaning rootfs"
        sudo rm -rf $_ROOTFS > /dev/null
        exit 1
    fi
}
