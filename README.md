# Manjaro ARM Tools
Contains scripts and files needed to build and manage manjaro-arm packages and images.

This software is available in the Manjaro Strit repo's, if you run Manjaro.

*These tools only work on Arch based distributions!*


## Known issues
`deployarmpkg` does not add the packages to the repo. Wait for the server to do the automatic adding.

`buildarmpkg` has problems building *some* `armv7h` packages, but I think it's an upstream issue, because there's no problem on `aarch64`.

## Dependencies
These scripts rely on certain packages to be able to function. These packages are:
* parted (arch repo)
* arch-install-scripts (arch repo)
* xz (arch repo)
* git (arch repo)
* zip (arch repo) (for `buildrootfs`)
* gptfdisk (arch repo) (required for nyan-big builds)

This package also provides `binfmt-qemu-static`.

# Installation (Arch based distributions only)
## From Manjaro Strit repo
Add my repo to your `/etc/pacman.conf`:
```
[manjaro-strit]
SigLevel = Optional
Server = https://www.strits.dk/files/manjaro-strit/manjaro-strit-repo/$arch
```
Run `sudo pacman -Syyu manjaro-strit-keyring && sudo pacman -S manjaro-arm-tools`.

## From gitlab
* Download the `.zip` or `.tar.gz` file from https://gitlab.manjaro.org/manjaro-arm/applications/manjaro-arm-tools.
* Extract it.
* Copy the contents of `lib/` to `/usr/share/manjaro-arm-tools/lib/`.
* Copy the contents of `bin/` to `/usr/bin/`. Remember to make them executable.
* Create `/var/lib/manjaro-arm-tools/pkg` folder.
* Create `/var/lib/manjaro-arm-tools/img` folder.
* Create `/var/lib/manjaro-arm-tools/tmp` folder.
* Create /var/cache/manjaro-arm-tools/img` folder.
* Create /var/cache/manjaro-arm-tools/pkg` folder.
* Install `binfmt-qemu-static` package.

# Usage
## buildarmpkg
This script is used to create packages for ARM architectures.
It assumes you have filled out the PACKAGER section of your `/etc/makepkg.conf`.

Options inside [] are optional. Use `-h` to see what the defaults are.

**Syntax**

```
buildarmpkg -p package [-a architecture] [-k] [-i package file]
```

To build an armv7h package, place yourself in the folder, that contains a folder with the PKGBUILD, named as the package you want to build. Then run:

```
buildarmpkg -p package -a armv7h
```

This will build the package called "package" for the armv7h architecture in the previous rootfs generated.

To build an aarch64 package it's the same, just with

```
buildarmpkg -p package -a aarch64
```

You can also build `any` packages, which will use the aarch64 architecture to build from.

```
buildarmpkg -p package -a any
```

This places the packages created inside `/var/cache/manjaro-arm-tools/pkg/` in either armv7h folder or aarch64 folder.

## deployarmpkg
This script is only for package maintainers of Manjaro-ARM.

This script assumes that you have enabled GPG signing on your machine, that you have a working key-pair and that you have a user on the Manjaro-ARM main server.
The `-p` option needs to be only the package. Not the full path to the package.

It will gpg sign and uploud the package you mention to the Manjaro-ARM main server.


**Syntax**

```
deployarmpkg -p package [-a architecture] -r repo -k keyid
```

To upload a package to the armv7h core repo use:

```
deployarmpkg -p package.pkg.tar.xz -a armv7h -r core -k email@server.org
```

To upload a package to the aarch64 extra repo use:

```
deployarmpkg -p package.pkg.tar.xz -a aarch64 -r extra -k email@server.org
```

To upload an any package to the community repo use:

```
deployarmpkg -p package.pkg.tar.xz -a any -r community -k email@server.org
```

This should be used after creating a package with `buildarmpkg` and cd'ing to the cache folder. It will sign the package with your default secret GPG key and upload both files
and remove the local files.

## buildarmimg

**Supported devices:**
* oc2
* rpi3 (not the A/B+ models it seems)
* pinebook
* sopine
* rpi2 (not maintained)
* oc1 (not maintained)
* xu4 (not maintained or tested)

**Supported editions:**

* minimal
* lxqt
* kde
* mate (not complete yet, unmaintained)
* i3 (not complete yet)
* server (not complete yet, unmaintained)


The script breafly replaces your `/etc/pacman.d/mirrorlist` with that of manjaro-arm to fetch the right packages.
This script will zip up the image file and place it in `/var/cache/manjaro-arm-tools/img/`

Profiles that gets used are on the [Gitlab.com](https://gitlab.com/Strit/arm-profiles) website, so they are easier to fork and create merge requests.

**Syntax**

```
buildarmimg [-d device] [-e edition] [-v version] [-u username] [-p password] [-n] [-x] [-i package file]
```

To build a minimal image version 18.07 for the raspberry pi 3:

```
buildarmimg -d rpi3 -e minimal -v 18.07
```

To build a minimal version 18.08 RC1 for the odroid-c2 with a new rootfs downloaded:

```
buildarmimg -d oc2 -e minimal -v 18.08-rc1 -n
```

To build an lxqt version with a local package installed for the rock64:

```
buildarmimg -d rock64 -e lxqt -i package-name-1.0-1-aarch64.pkg.tar.xz
```

## buildarmoem
This one functions mostly like `buildarmimg`, but only has device, edition and version arguments.

It will create an image, much like `buildarmimg`, but will not add users or password to it. It will then install a special script that runs on first boot, that prompts the user for OEM stuff.

## buildrootfs
This script does exactly what it says it does. It builds a very small rootfs, to be used by the Manjaro ARM Installer (and perhaps `buildarmpkg` and `buildarmimg` in the future.

**Syntax**
```
buildrootfs -a arch
```

To build an armv7h rootfs:
```
buildrootfs -a armv7h
```

To build an aarch64 rootfs:
```
buildrootfs -a aarch64
```

## deployarmimg
This script will create checksums for and upload the newly generated image. It assumes you have upload access to our OSDN server.
If you don't, you can't use this.

**Syntax**

```
deployarmimg -i image [-d device] [-e edition] [-v version] [-t]
```

To upload an image to the raspberry pi minimal 18.07 folder use with torrent:

```
deployarmimg -i Manjaro-ARM-minimal-rpi3-18.07.zip -d rpi3 -e minimal -v 18.07 -t
```

## getarmprofiles
This script will just clone or update the current profile list in `/usr/share/manjaro-arm-tools/profiles/`.
So nothing that fancy.

This would enable users to clone the profiles repository, make any changes they would like to their images and then build them localy.
So if you made changes to the profiles yourself, don't run `getarmprofiles` and you will still have your edits.

But if you messed up your profiles somehow, you can start with the repo ones with:
```
getarmprofiles -f
```
