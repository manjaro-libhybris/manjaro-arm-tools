#! /bin/bash

# Default variables
BRANCH='stable'
DEVICE='halium-9'
EDITION='phosh'
VERSION=$(date +'%y'.'%m')
LIBDIR=/usr/share/manjaro-arm-tools/lib
BUILDDIR=/var/lib/manjaro-arm-tools/pkg
BUILDSERVER=https://repo.manjaro.org/repo
PACKAGER=$(cat /etc/makepkg.conf | grep PACKAGER)
PKGDIR=/var/cache/manjaro-arm-tools/pkg
ROOTFS_IMG=/var/lib/manjaro-arm-tools/img
TMPDIR=/var/lib/manjaro-arm-tools/tmp
IMGDIR=/var/cache/manjaro-arm-tools/img
IMGNAME=Manjaro-ARM-$EDITION-$DEVICE-$VERSION
PROFILES=/usr/share/manjaro-arm-tools/profiles
TEMPLATES=/usr/share/manjaro-arm-tools/templates
NSPAWN='systemd-nspawn -q --resolv-conf=copy-host --timezone=off -D'
STORAGE_USER=$(whoami)
FLASHVERSION=$(date +'%y'.'%m')
ARCH='aarch64'
USER='manjaro'
HOSTNAME='manjaro-libhybris'
PASSWORD='manjaro'
CARCH=$(uname -m)
COLORS=true
FILESYSTEM='ext4'
srv_list=/tmp/services_list

# import conf file
source /etc/manjaro-arm-tools/manjaro-arm-tools.conf

# PKGDIR & IMGDIR may not exist if they were changed by configuration, make sure they do.
mkdir -p ${PKGDIR}/pkg-cache
mkdir -p ${IMGDIR}

usage_build_pkg() {
    echo "Usage: ${0##*/} [options]"
    echo "    -a <arch>          Architecture. [Default = aarch64. Options = any or aarch64]"
    echo "    -p <pkg>           Package to build"
    echo "    -k                 Keep the previous rootfs for this build"
    echo "    -b <branch>        Set the branch used for the build. [Default = stable. Options = stable, testing or unstable]"
    echo "    -n                 Install built package into rootfs"
    echo "    -i <package>       Install local package into rootfs."
    echo "    -r <repository>    Use a custom repository in the rootfs."
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_build_img() {
    echo "Usage: ${0##*/} [options]"
    echo "    -d <device>        Device the image is for. [Default = halium-9. Options = $(ls -m --width=0 "$PROFILES/arm-profiles/devices/")]"
    echo "    -e <edition>       Edition of the image. [Default = phosh. Options = $(ls -m --width=0 "$PROFILES/arm-profiles/editions/")]"
    echo "    -v <version>       Define the version the resulting image should be named. [Default is current YY.MM]"
    echo "    -k <repo>          Add overlay repo [Options = kde-unstable, mobile] or url https://server/path/custom_repo.db"
    echo "    -i <package>       Install local package into image rootfs."
    echo "    -b <branch>        Set the branch used in the image. [Default = stable. Options = stable, testing or unstable]"
    echo "    -m                 Create bmap. ('bmap-tools' need to be installed.)"
    echo "    -n                 Force download of new rootfs."
    echo "    -s <hostname>      Use custom hostname"
    echo "    -x                 Don't compress the image."
    echo "    -c                 Disable colors."
    echo "    -p <filesystem>    Filesystem to be used for the root partition. [Default = ext4. Options = ext4]"
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

usage_getarmprofiles() {
    echo "Usage: ${0##*/} [options]"
    echo '    -f                 Force download of current profiles from the git repository'
    echo '    -h                 This help'
    echo ''
    echo ''
    exit $1
}

enable_colors() {
    ALL_OFF="\e[1;0m"
    BOLD="\e[1;1m"
    GREEN="${BOLD}\e[1;32m"
    BLUE="${BOLD}\e[1;34m"
}

msg() {
    local mesg=$1; shift
    printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
 }

info() {
    local mesg=$1; shift
    printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
 }

error() {
    local mesg=$1; shift
    printf "${RED}==> ERROR:${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

cleanup() {
    umount $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg
    exit ${1:-0}
}

abort() {
    error 'Aborting...'
    cleanup 255
}

prune_cache(){
    info "Prune and unmount pkg-cache..."
    $NSPAWN $CHROOTDIR paccache -r
    umount $PKG_CACHE
}

load_vars() {
    local var

    [[ -f $1 ]] || return 1

    for var in {SRC,SRCPKG,PKG,LOG}DEST MAKEFLAGS PACKAGER CARCH GPGKEY; do
        [[ -z ${!var} ]] && eval $(grep -a "^${var}=" "$1")
    done

    return 0
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

create_rootfs_pkg() {
    msg "Building $PACKAGE for $ARCH..."

    # Remove old rootfs if it exists
    if [ -d $CHROOTDIR ]; then
        info "Removing old rootfs..."
        rm -rf $CHROOTDIR
    fi

    msg "Creating rootfs..."
    mkdir -p $CHROOTDIR

    # basescrap the rootfs filesystem
    info "Switching branch to $BRANCH..."
    sed -i s/"arm-stable"/"arm-$BRANCH"/g $LIBDIR/pacman.conf.$ARCH
    $LIBDIR/pacstrap -G -M -C $LIBDIR/pacman.conf.$ARCH $CHROOTDIR fakeroot-qemu base-devel
    echo "Server = $BUILDSERVER/arm-$BRANCH/\$repo/\$arch" > $CHROOTDIR/etc/pacman.d/mirrorlist
    sed -i s/"arm-$BRANCH"/"arm-stable"/g $LIBDIR/pacman.conf.$ARCH

    if [[ $CARCH != "aarch64" ]]; then
        # Enable cross architecture Chrooting
        cp /usr/bin/qemu-aarch64-static $CHROOTDIR/usr/bin/
    fi

    msg "Configuring rootfs for building..."
    $NSPAWN $CHROOTDIR pacman-key --init
    $NSPAWN $CHROOTDIR pacman-key --populate archlinuxarm manjaro manjaro-arm
    cp $LIBDIR/makepkg $CHROOTDIR/usr/bin/
    $NSPAWN $CHROOTDIR chmod +x /usr/bin/makepkg
    $NSPAWN $CHROOTDIR update-ca-trust

    if [[ ! -z ${CUSTOM_REPO} ]]; then
        info "Adding repo [$CUSTOM_REPO] to rootfs"

        if [[ "$CUSTOM_REPO" =~ ^https?://.*db ]]; then
            CUSTOM_REPO_NAME="${CUSTOM_REPO##*/}" # remove everyting before last slash
            CUSTOM_REPO_NAME="${CUSTOM_REPO_NAME%.*}" # remove everything after last dot
            CUSTOM_REPO_URL="${CUSTOM_REPO%/*}" # remove everything after last slash
            sed -i "s/^\[core\]/\[$CUSTOM_REPO_NAME\]\nSigLevel = Optional TrustAll\nServer = ${CUSTOM_REPO_URL//\//\\/}\n\n\[core\]/" $CHROOTDIR/etc/pacman.conf
        else
            sed -i "s/^\[core\]/\[$CUSTOM_REPO\]\nInclude = \/etc\/pacman.d\/mirrorlist\n\n\[core\]/" $CHROOTDIR/etc/pacman.conf
        fi
    fi

    sed -i s/'#PACKAGER="John Doe <john@doe.com>"'/"$PACKAGER"/ $CHROOTDIR/etc/makepkg.conf
    sed -i s/'#MAKEFLAGS="-j2"'/'MAKEFLAGS="-j$(nproc)"'/ $CHROOTDIR/etc/makepkg.conf
    sed -i s/'COMPRESSXZ=(xz -c -z -)'/'COMPRESSXZ=(xz -c -z - --threads=0)'/ $CHROOTDIR/etc/makepkg.conf
    $NSPAWN $CHROOTDIR pacman -Syy
}

create_rootfs_img() {
    # Check if device file exists
    if [ ! -f "$PROFILES/arm-profiles/devices/$DEVICE" ]; then
        echo 'Invalid device '$DEVICE', please choose one of the following'
        echo "$(ls $PROFILES/arm-profiles/devices/)"
        exit 1
    fi

    # check if edition file exists
    if [ ! -f "$PROFILES/arm-profiles/editions/$EDITION" ]; then
        echo 'Invalid edition '$EDITION', please choose one of the following'
        echo "$(ls $PROFILES/arm-profiles/editions/)"
        exit 1
    fi

    msg "Creating image of $EDITION for $DEVICE..."

    # Remove old rootfs if it exists
    if [ -d $ROOTFS_IMG/rootfs_$ARCH ]; then
        info "Removing old rootfs..."
        rm -rf $ROOTFS_IMG/rootfs_$ARCH
    fi

    mkdir -p $ROOTFS_IMG/rootfs_$ARCH

    if [[ "$KEEPROOTFS" = "false" ]]; then
        rm -rf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz*
        # fetch and extract rootfs
        info "Downloading latest $ARCH rootfs..."
        cd $ROOTFS_IMG
        wget -q --show-progress --progress=bar:force:noscroll https://github.com/manjaro-libhybris/rootfs/releases/latest/download/Manjaro-ARM-$ARCH-latest.tar.gz
    fi

    # also fetch it, if it does not exist
    if [ ! -f "$ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz" ]; then
        cd $ROOTFS_IMG
        wget -q --show-progress --progress=bar:force:noscroll https://github.com/manjaro-libhybris/rootfs/releases/latest/download/Manjaro-ARM-$ARCH-latest.tar.gz
    fi

    info "Extracting $ARCH rootfs..."
    bsdtar -xpf $ROOTFS_IMG/Manjaro-ARM-$ARCH-latest.tar.gz -C $ROOTFS_IMG/rootfs_$ARCH

    info "Setting up keyrings..."
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --init  || abort
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-key --populate archlinuxarm manjaro manjaro-arm  || abort

    info "Adding the repo for manjaro libhybris"
    sed -i '/\[core\]/i \
[manjaro-libhybris]\
SigLevel = Optional TrustAll\
Server = https://mirror.bardia.tech/manjaro-libhybris/aarch64\n' $ROOTFS_IMG/rootfs_$ARCH/etc/pacman.conf

    if [ "$EDITION" == "nemomobile" ]; then
        CUSTOM_REPO="https://img.nemomobile.net/manjaro/05.2023/stable/aarch64/nemomobile.db"
    fi

    if [[ ! -z ${CUSTOM_REPO} ]]; then
        info "Adding repo [$CUSTOM_REPO] to rootfs"

        if [[ "$CUSTOM_REPO" =~ ^https?://.*db ]]; then
            CUSTOM_REPO_NAME="${CUSTOM_REPO##*/}" # remove everyting before last slash
            CUSTOM_REPO_NAME="${CUSTOM_REPO_NAME%.*}" # remove everything after last dot
            CUSTOM_REPO_URL="${CUSTOM_REPO%/*}" # remove everything after last slash
            sed -i "s/^\[core\]/\[$CUSTOM_REPO_NAME\]\nSigLevel = Optional TrustAll\nServer = ${CUSTOM_REPO_URL//\//\\/}\n\n\[core\]/" $ROOTFS_IMG/rootfs_$ARCH/etc/pacman.conf
        else
            sed -i "s/^\[core\]/\[$CUSTOM_REPO\]\nInclude = \/etc\/pacman.d\/mirrorlist\n\n\[core\]/" $ROOTFS_IMG/rootfs_$ARCH/etc/pacman.conf
        fi
    fi

    info "Setting branch to $BRANCH..."
    echo "Server = $BUILDSERVER/arm-$BRANCH/\$repo/\$arch" > $ROOTFS_IMG/rootfs_$ARCH/etc/pacman.d/mirrorlist

    msg "Installing packages for $DEVICE"

    # Install device specific packages
    mount -o bind $PKGDIR/pkg-cache $PKG_CACHE

    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -Syyu base systemd pacutils systemd-libs manjaro-system manjaro-release which $PKG_DEVICE --noconfirm || abort

    msg "Installing packages for edition $EDITION"

    # Install edition specific packages
    case "$EDITION" in
        cubocore|phosh|plasma-mobile|plasma-mobile-dev|kde-bigscreen|nemomobile|cutie)
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacinstall --no-confirm --resolve-conflicts=all $PKG_EDITION || abort
            ;;
        minimal|server)
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacinstall --no-confirm --resolve-conflicts=all $PKG_EDITION || abort
            ;;
        *)
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacinstall --no-confirm --resolve-conflicts=all $PKG_EDITION || abort
            ;;
    esac

    if [[ ! -z "$ADD_PACKAGE" ]]; then
        info "Installing local package {$ADD_PACKAGE} to rootfs..."
        cp -ap $ADD_PACKAGE $PKG_CACHE/
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman -U /var/cache/pacman/pkg/$ADD_PACKAGE --noconfirm || abort
    fi

    info "Generating mirrorlist..."
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH pacman-mirrors --protocols https --method random --api --set-branch $BRANCH

    info "Enabling services..."

    # Enable services
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable getty.target haveged.service pacman-init.service
    if [[ "$CUSTOM_REPO" = "kde-unstable" ]]; then
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable sshd.service
    fi

    while read service; do
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl enable $service
    done < $srv_list

    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -s /usr/lib/systemd/user/audiosystem-passthrough.service /etc/systemd/user/default.target.wants/audiosystem-passthrough.service

    if [ "$EDITION" = "nemomobile" ]; then
        msg "Masking connman"
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH systemctl mask connman
    fi

    info "Applying overlay for $EDITION edition..."
    cp -ap $PROFILES/arm-profiles/overlays/$EDITION/* $ROOTFS_IMG/rootfs_$ARCH/

    info "Creating all the users"
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH groupadd autologin
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH groupadd --gid 32011 manjaro
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH useradd -G autologin,wheel,sys,audio,input,video,storage,lp,network,users,power,rfkill,system,radio,android_input,android_graphics,android_audio \
	--uid 32011 --gid 32011 -m -g users -p $(openssl passwd -6 "123456") -s /bin/bash manjaro

    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH awk -i inplace -F: "BEGIN {OFS=FS;} \$1 == \"root\" {\$2=\"$(openssl passwd -6 'root')\"} 1" /etc/shadow

    info "Setting up system settings..."
    # system setup
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH update-ca-trust
    echo "$HOSTNAME" | tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/hostname

    case "$EDITION" in
        cubocore|plasma-mobile|plasma-mobile-dev|kde-bigscreen)
            echo "No OEM setup!"
            # Lock root user
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH passwd --lock root
            ;;
        phosh|lomiri|nemomobile|cutie)
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH groupadd -r autologin
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH gpasswd -a "manjaro" autologin
            # Lock root user
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH passwd --lock root
            ;;
        minimal|server)
            echo "Enabling SSH login for root user for headless setup..."
            sed -i s/"#PermitRootLogin prohibit-password"/"PermitRootLogin yes"/g $ROOTFS_IMG/rootfs_$ARCH/etc/ssh/sshd_config
            sed -i s/"#PermitEmptyPasswords no"/"PermitEmptyPasswords yes"/g $ROOTFS_IMG/rootfs_$ARCH/etc/ssh/sshd_config
            echo "Enabling autologin for first setup..."
            mv $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service.bak
            cp $LIBDIR/getty\@.service $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/getty\@.service
            ;;
    esac

    # Create OEM user
    if [ -d $ROOTFS_IMG/rootfs_$ARCH/usr/share/calamares ]; then
        echo "Creating OEM user..."
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH groupadd -r autologin
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH useradd -m -g users -u 984 -G wheel,sys,audio,input,video,storage,lp,network,users,power,autologin -p $(openssl passwd -6 oem) -s /bin/bash oem
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH echo "oem ALL=(ALL) NOPASSWD: ALL" > $ROOTFS_IMG/rootfs_$ARCH/etc/sudoers.d/g_oem

        case "$EDITION" in
            desq|wayfire|sway)
                SESSION=$(ls $ROOTFS_IMG/rootfs_$ARCH/usr/share/wayland-sessions/ | head -1)
                ;;
            *)
                SESSION=$(ls $ROOTFS_IMG/rootfs_$ARCH/usr/share/xsessions/ | head -1)
                ;;
        esac

        # For sddm based systems
        if [ -f $ROOTFS_IMG/rootfs_$ARCH/usr/bin/sddm ]; then
            $NSPAWN $ROOTFS_IMG/rootfs_$ARCH mkdir -p /etc/sddm.conf.d
            echo "# Created by Manjaro ARM OEM Setup

[Autologin]
User=oem
Session=$SESSION" > $ROOTFS_IMG/rootfs_$ARCH/etc/sddm.conf.d/90-autologin.conf
        fi

        # For lightdm based systems
        if [ -f $ROOTFS_IMG/rootfs_$ARCH/usr/bin/lightdm ]; then
            SESSION=$(echo ${SESSION%.*})
            sed -i s/"#autologin-user="/"autologin-user=oem"/g $ROOTFS_IMG/rootfs_$ARCH/etc/lightdm/lightdm.conf
            sed -i s/"#autologin-user-timeout=0"/"autologin-user-timeout=0"/g $ROOTFS_IMG/rootfs_$ARCH/etc/lightdm/lightdm.conf
            if [[ "$EDITION" = "lxqt" ]]; then
                sed -i s/"#autologin-session="/"autologin-session=lxqt"/g $ROOTFS_IMG/rootfs_$ARCH/etc/lightdm/lightdm.conf
            elif [[ "$EDITION" = "i3" ]]; then
                echo "autologin-user=oem
autologin-user-timeout=0
autologin-session=i3" >> $ROOTFS_IMG/rootfs_$ARCH/etc/lightdm/lightdm.conf
                sed -i s/"# Autostart applications"/"# Autostart applications\nexec --no-startup-id sudo -E calamares"/g $ROOTFS_IMG/rootfs_$ARCH/home/oem/.i3/config
            else
                sed -i s/"#autologin-session="/"autologin-session=$SESSION"/g $ROOTFS_IMG/rootfs_$ARCH/etc/lightdm/lightdm.conf
            fi
        fi

        # For greetd based Sway edition
        if [ -f $ROOTFS_IMG/rootfs_$ARCH/usr/bin/sway ]; then
            echo '[initial_session]
command = "sway --config /etc/greetd/oem-setup"
user = "oem"' >> $ROOTFS_IMG/rootfs_$ARCH/etc/greetd/config.toml
        fi
        # For Gnome edition
        if [ -f $ROOTFS_IMG/rootfs_$ARCH/usr/bin/gdm ]; then
            sed -i s/"\[daemon\]"/"\[daemon\]\nAutomaticLogin=oem\nAutomaticLoginEnable=True"/g $ROOTFS_IMG/rootfs_$ARCH/etc/gdm/custom.conf
        fi
    fi

    # Lomiri services Temporary in function until it is moved to an individual package.
    if [[ "$EDITION" = "lomiri" ]]; then
        echo "Fix indicators"
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH mkdir -pv /usr/lib/systemd/user/ayatana-indicators.target.wants
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/ayatana-indicator-datetime.service /usr/lib/systemd/user/ayatana-indicators.target.wants/ayatana-indicator-datetime.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/ayatana-indicator-display.service /usr/lib/systemd/user/ayatana-indicators.target.wants/ayatana-indicator-display.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/ayatana-indicator-messages.service /usr/lib/systemd/user/ayatana-indicators.target.wants/ayatana-indicator-messages.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/ayatana-indicator-power.service /usr/lib/systemd/user/ayatana-indicators.target.wants/ayatana-indicator-power.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/ayatana-indicator-session.service /usr/lib/systemd/user/ayatana-indicators.target.wants/ayatana-indicator-session.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/ayatana-indicator-sound.service /usr/lib/systemd/user/ayatana-indicators.target.wants/ayatana-indicator-sound.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/indicator-network.service /usr/lib/systemd/user/ayatana-indicators.target.wants/indicator-network.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/indicator-transfer.service /usr/lib/systemd/user/ayatana-indicators.target.wants/indicator-transfer.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/indicator-bluetooth.service /usr/lib/systemd/user/ayatana-indicators.target.wants/indicator-bluetooth.service
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/indicator-location.service /usr/lib/systemd/user/ayatana-indicators.target.wants/indicator-location.service

        echo "Fix background"
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH mkdir -pv /usr/share/backgrounds
        #$NSPAWN $ROOTFS_IMG/rootfs_$ARCH convert -verbose /usr/share/wallpapers/manjaro.jpg /usr/share/wallpapers/manjaro.png
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/share/wallpapers/manjaro.png /usr/share/backgrounds/warty-final-ubuntu.png

        echo "Fix Maliit"
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH mkdir -pv /usr/lib/systemd/user/graphical-session.target.wants
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ln -sfv /usr/lib/systemd/user/maliit-server.service /usr/lib/systemd/user/graphical-session.target.wants/maliit-server.service
    fi
    ### Lomiri Temporary service ends here

    info "Correcting permissions from overlay..."
    chown -R 0:0 $ROOTFS_IMG/rootfs_$ARCH/etc
    chown -R 0:0 $ROOTFS_IMG/rootfs_$ARCH/usr/{local,share}

    if [[ -d $ROOTFS_IMG/rootfs_$ARCH/etc/polkit-1/rules.d ]]; then
        chown 0:102 $ROOTFS_IMG/rootfs_$ARCH/etc/polkit-1/rules.d
    fi

    if [[ -d $ROOTFS_IMG/rootfs_$ARCH/usr/share/polkit-1/rules.d ]]; then
        chown 0:102 $ROOTFS_IMG/rootfs_$ARCH/usr/share/polkit-1/rules.d
    fi

    echo "$DEVICE - $EDITION - $VERSION" | tee --append $ROOTFS_IMG/rootfs_$ARCH/etc/manjaro-arm-version

    info "Setting the correct theme for plymouth"
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH plymouth-set-default-theme manjaro

    info "Setting the correct locale"
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH echo "LANG=en_US.UTF-8" > /etc/locale.conf

    info "Setting chassis mode"
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH echo "CHASSIS=handset" > /etc/machine-info

    if [[ -f $ROOTFS_IMG/rootfs_$ARCH/usr/bin/appstreamctl ]]; then
        echo "Update appstream DB"
        $NSPAWN $ROOTFS_IMG/rootfs_$ARCH appstreamcli refresh-cache --force
    fi

    info "Generating ssh keys"
    $NSPAWN $ROOTFS_IMG/rootfs_$ARCH ssh-keygen -A

    info "Cleaning rootfs for unwanted files..."
    prune_cache
    rm $ROOTFS_IMG/rootfs_$ARCH/usr/bin/qemu-aarch64-static
    rm -f $ROOTFS_IMG/rootfs_$ARCH/var/log/*
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/var/log/journal/*
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/etc/*.pacnew
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/usr/lib/systemd/system/systemd-firstboot.service
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/etc/machine-id
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/etc/pacman.d/gnupg
    rm -rf $ROOTFS_IMG/rootfs_$ARCH/Manjaro-ARM-$ARCH-latest.tar.gz

    msg "$DEVICE $EDITION rootfs complete"
}

create_img_halium() {
    msg "Finishing image for $DEVICE $EDITION edition..."
    info "Creating image..."

    ARCH='aarch64'

    SIZE=$(du -s --block-size=MB $CHROOTDIR | awk '{print $1}' | sed -e 's/MB//g')
    EXTRA_SIZE=300
    REAL_SIZE=`echo "$(($SIZE+$EXTRA_SIZE))"`

    # making blank .img to be used
    dd if=/dev/zero of=$IMGDIR/$IMGNAME.img bs=1M count=$REAL_SIZE

    # format it
    mkfs.ext4 $IMGDIR/$IMGNAME.img -L ROOT_MNJRO
    info "Copying files to image..."

    mkdir -p $TMPDIR/root
    mount $IMGDIR/$IMGNAME.img $TMPDIR/root
    cp -ra $ROOTFS_IMG/rootfs_$ARCH/* $TMPDIR/root/ || true
    cp -ra $ROOTFS_IMG/rootfs_$ARCH/.* $TMPDIR/root/ || true

    info "Creating Android directories and symlinks"
    mkdir -p $TMPDIR/root/android
    mkdir -p $TMPDIR/root/userdata
    mkdir -p $TMPDIR/root/mnt/vendor/persist $TMPDIR/root/mnt/vendor/efs
    ln -s /android/product $TMPDIR/root/product
    ln -s /android/metadata $TMPDIR/root/metadata
    ln -s /android/system $TMPDIR/root/system
    ln -s /android/efs $TMPDIR/root/efs
    touch $TMPDIR/root/.writable_image

    umount $TMPDIR/root/
    rm -r $TMPDIR/root/

    chmod 666 $IMGDIR/$IMGNAME.img
}

create_bmap() {
    if [ ! -e /usr/bin/bmaptool ]; then
        echo "'bmap-tools' are not installed. Skipping."
    else
        info "Creating bmap."
        cd ${IMGDIR}
        rm ${IMGNAME}.img.bmap
        bmaptool create -o ${IMGNAME}.img.bmap ${IMGNAME}.img
    fi
}

compress() {
    if [ -f $IMGDIR/$IMGNAME.img.xz ]; then
        info "Removing existing compressed image file {$IMGNAME.img.xz}..."
        rm -rf $IMGDIR/$IMGNAME.img.xz
    fi

    info "Compressing $IMGNAME.img..."
    #compress img
    cd $IMGDIR
    xz -zv --threads=0 $IMGNAME.img
    chmod 666 $IMGDIR/$IMGNAME.img.xz

    info "Removing rootfs_$ARCH"
    umount $ROOTFS_IMG/rootfs_$ARCH/var/cache/pacman/pkg
    rm -rf $CHROOTDIR
}

build_pkg() {
    # Install local package to rootfs before building
    if [[ ! -z "$ADD_PACKAGE" ]]; then
        info "Installing local package {$ADD_PACKAGE} to rootfs..."
        cp -ap $ADD_PACKAGE $PKG_CACHE
        $NSPAWN $CHROOTDIR pacman -U /var/cache/pacman/pkg/$ADD_PACKAGE --noconfirm
    fi

    # Build the actual package
    msg "Copying build directory {$PACKAGE} to rootfs..."
    $NSPAWN $CHROOTDIR mkdir build
    mount -o bind "$PACKAGE" $CHROOTDIR/build
    msg "Building {$PACKAGE}..."
    mount -o bind $PKGDIR/pkg-cache $PKG_CACHE
    $NSPAWN $CHROOTDIR pacman -Syu

    if [[ $INSTALL_NEW = true ]]; then
        $NSPAWN $CHROOTDIR --chdir=/build/ makepkg -Asci --noconfirm
    else
        $NSPAWN $CHROOTDIR --chdir=/build/ makepkg -Asc --noconfirm
    fi
}

export_and_clean() {
    if ls $CHROOTDIR/build/*.pkg.tar.* ; then
        # pull package out of rootfs
        msg "Package Succeeded..."
        info "Extracting finished package out of rootfs..."
        mkdir -p $PKGDIR/$ARCH
        cp $CHROOTDIR/build/*.pkg.tar.* $PKGDIR/$ARCH/
        chown -R $SUDO_USER $PKGDIR
        msg "Package saved as {$PACKAGE} in {$PKGDIR/$ARCH}..."
        umount $CHROOTDIR/build

        # clean up rootfs
        info "Cleaning build files from rootfs"
        rm -rf $CHROOTDIR/build/
    else
        msg "!!!!! Package failed to build !!!!!"
        umount $CHROOTDIR/build
        prune_cache
        rm -rf $CHROOTDIR/build/
        exit 1
    fi
}

clone_profiles() {
    cd $PROFILES
    git clone --branch $1 https://github.com/manjaro-libhybris/arm-profiles
}

clone_templates() {
    cd $TEMPLATES
    git clone --branch $1 https://www.github.com/manjaro-libhybris/android-recovery-flashing-template.git
}

get_profiles() {
    local branch=master

    if ls $PROFILES/arm-profiles/* ; then
        if [[ $(grep branch $PROFILES/arm-profiles/.git/config | cut -d\" -f2) = "$branch" ]]; then
            cd $PROFILES/arm-profiles
            git pull
        else
            rm -rf $PROFILES/arm-profiles/
            clone_profiles $branch
        fi
    else
        clone_profiles $branch
    fi
}

get_templates() {
    local branch=master
    if ls $TEMPLATES/android-recovery-flashing-template/* ; then
        if [[ $(grep branch $TEMPLATES/android-recovery-flashing-template/.git/config | cut -d\" -f2) = "$branch" ]]; then
            cd $TEMPLATES/android-recovery-flashing-template
            git pull
        else
            rm -rf $TEMPLATES/android-recovery-flashing-template/
            clone_templates $branch
        fi
    else
        clone_templates $branch
    fi
}
