#! /bin/bash

# This script is meant to be run via SSH to the server.

# Variables

# Run repo add on folder to add new package and cleanup old versions
sudo systemd-nspawn -D /opt/repo/ repo-add -q -n -R /mirror/stable/$2/$3/$3.db.tar.gz /mirror/stable/$2/$3/$1


if [[ $2 == "any" ]]; then
    # create new symlinks
    cd /opt/repo/mirror/stable/any/$3/ &&
    for f in *
    do
    ln -s ../../any/$3/"$f" ../../armv7h/$3/"$f"
    ln -s ../../any/$3/"$f" ../../aarch64/$3/"$f"
    done

    # then we remove broken symlinks
    cd /opt/repo/mirror/stable/armv7h/$3/ &&
    for x in * .[!.]* ..?*; do if [ -L "$x" ] && ! [ -e "$x" ]; then rm -- "$x"; fi; done 
    cd /opt/repo/mirror/stable/aarch64/$3/ &&
    for x in * .[!.]* ..?*; do if [ -L "$x" ] && ! [ -e "$x" ]; then rm -- "$x"; fi; done 

    # and now we update the databases in armv7h and aarch64
    sudo systemd-nspawn -D /opt/repo/ repo-add -q -n -R /mirror/stable/armv7h/$3/$3.db.tar.gz /mirror/stable/armv7h/$3/$1
    sudo systemd-nspawn -D /opt/repo/ repo-add -q -n -R /mirror/stable/aarch64/$3/$3.db.tar.gz /mirror/stable/aarch64/$3/$1
fi
