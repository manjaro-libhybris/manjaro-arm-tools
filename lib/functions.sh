#! /bin/bash

#variables
SERVER='sync.manjaro-arm.org'
_LIBDIR=/usr/share/manjaro-arm-tools/lib

usage_deploy_pkg() {
    echo "Usage: ${0##*/} [options]"
    echo "    -a <arch>          Architecture"
    echo '    -h                 This help'
    echo "    -p <pkg>           Package to build"
    echo '    -r <repo>          Repository package belongs to'
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
