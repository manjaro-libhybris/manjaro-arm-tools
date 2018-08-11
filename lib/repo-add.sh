#! /bin/bash

# This script is meant to be run via SSH to the server.

# Variables
#package="${OPTARG%/}"
#arch="${OPTARG}"
#repo="${OPTARG}"

# Run repo add on folder to add new package and cleanup old versions
sudo systemd-nspawn -D /opt/repo/ repo-add -q -n -R /mirror/stable/$arch/$repo/$repo.db.tar.gz /mirror/stable/$arch/$repo/$package


if [[ $arch == "any" ]]; then
    # create new symlinks
    cd /opt/repo/mirror/stable/any/$repo/ &&
    for f in *
    do
    ln -s ../../any/$repo/"$f" ../../armv7h/$repo/"$f"
    ln -s ../../any/$repo/"$f" ../../aarch64/$repo/"$f"
    done

    # then we remove broken symlinks
    cd /opt/repo/mirror/stable/armv7h/$repo/ &&
    for x in * .[!.]* ..?*; do if [ -L "$x" ] && ! [ -e "$x" ]; then rm -- "$x"; fi; done 
    cd /opt/repo/mirror/stable/aarch64/$repo/ &&
    for x in * .[!.]* ..?*; do if [ -L "$x" ] && ! [ -e "$x" ]; then rm -- "$x"; fi; done 

    # and now we update the databases in armv7h and aarch64
    sudo systemd-nspawn -D /opt/repo/ repo-add -q -n -R /mirror/stable/armv7h/$repo/$repo.db.tar.gz /mirror/stable/armv7h/$repo/$package
    sudo systemd-nspawn -D /opt/repo/ repo-add -q -n -R /mirror/stable/aarch64/$repo/$repo.db.tar.gz /mirror/stable/aarch64/$repo/$package
fi
