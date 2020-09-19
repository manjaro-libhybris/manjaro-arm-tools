# Manjaro ARM Tools
Contains scripts and files needed to build and manage manjaro-arm packages and images.

This software is available in the Manjaro repository.

*These tools only work on Manjaro based distributions!*


## Known issues
Check the [Issues](https://gitlab.manjaro.org/manjaro-arm/applications/manjaro-arm-tools/-/issues) page.

## Dependencies
These scripts rely on certain packages, other than what's in the `base` package group, to be able to function. These packages are:
* parted (arch repo)
* libarchive (arch repo)
* git (arch repo)
* binfmt-user-static (AUR) or manjaro-arm-qemu-static (manjaro repo)
* dosfstools (arch repo)
* polkit (arch repo)
* gnugpg (arch repo)
* wget (arch repo)
* systemd-nspawn with support for `--resolv-conf=copy-host` (arch repo)

### Optional Dependencies
* gzip (arch repo) (for `builddockerimg`)
* docker (arch repo) (for `builddockkerimg`)
* mktorrent (arch repo) (for torrent support in `deployarmimg`)
* rsync (arch repo) (for `deployarmimg`)

# Installation (Manjaro based distributions only)
## GIT version from Manjaro Strit repo
Add my repo to your `/etc/pacman.conf`:
```
[manjaro-strit]
SigLevel = Optional
Server = https://www.strits.dk/files/manjaro-strit/manjaro-strit-repo/$arch
```
Run `sudo pacman -Syyu manjaro-arm-tools-git`.

## From gitlab (tagged or GIT version)
* Download the `.zip` or `.tar.gz` file from https://gitlab.manjaro.org/manjaro-arm/applications/manjaro-arm-tools.
* Extract it.
* Copy the contents of `lib/` to `/usr/share/manjaro-arm-tools/lib/`.
* Copy the contents of `bin/` to `/usr/bin/`. Remember to make them executable.
* Create `/var/lib/manjaro-arm-tools/pkg` folder.
* Create `/var/lib/manjaro-arm-tools/img` folder.
* Create `/var/lib/manjaro-arm-tools/tmp` folder.
* Create `/var/cache/manjaro-arm-tools/img` folder.
* Create `/var/cache/manjaro-arm-tools/pkg` folder.
* Install `binfmt-qemu-static` package and make sure `systemd-binfmt` is running

# Usage
## buildarmpkg
This script is used to create packages for ARM architectures.
It assumes you have filled out the PACKAGER section of your `/etc/makepkg.conf`.

Options inside `[` `]` are optional. Use `-h` to see what the defaults are.

**Syntax**

```
sudo buildarmpkg -p package [-a architecture] [-k] [-i package file] [-b branch]
```

To build an aarch64 package against arm-unstable branch use the following command:

```
sudo buildarmpkg -p package -a aarch64 -b unstable
```

You can also build `any` packages, which will use the aarch64 architecture to build from.

```
sudo buildarmpkg -p package -a any
```

The built packages will be copied to `$PKGDIR` as specified in `/usr/share/manjaro-arm-tools/lib/manjaro-arm-tools.conf` and placed in a subdirectory for the respective architecture.
Default package destination is `/var/cache/manjaro-arm-tools/pkg/`.


## buildarmimg
**Supported devices:**
* edgev
* nanopc-t4
* nanopi-neo-plus2
* oc2
* oc4
* on2
* on2-plus (new)
* pine64-lts
* pine-h64
* pinebook
* pinephone
* pinetab
* pbpro
* rpi3 (not the A/B+ models it seems)
* rpi4
* rock64
* roc-cc
* rockpi4b
* rockpi4c (new)
* rockpro64
* vim1
* vim2
* vim3

**Supported editions:**

* minimal
* lxqt
* kde-plasma
* mate
* xfce
* i3
* sway
* gnome (experimental)
* plasma-mobile (experimental)
* phosh (experimental)
* cubocore (not complete yet)
* server (not complete yet, unmaintained)


This script will compress the image file and place it in `/var/cache/manjaro-arm-tools/img/`

Profiles that gets used are from this [Gitlab](https://gitlab.manjaro.org/manjaro-arm/applications/arm-profiles) repository.

**Syntax**

```
sudo buildarmimg [-d device] [-e edition] [-v version] [-n] [-x] [-i package-file.pkg.tar.xz] [-b branch]
```

To build a minimal image version 18.07 for the raspberry pi 3 on arm-unstable branch:

```
sudo buildarmimg -d rpi3 -e minimal -v 18.07 -b unstable
```

To build a minimal version 18.08 RC1 for the odroid-c2 with a new rootfs downloaded:

```
sudo buildarmimg -d oc2 -e minimal -v 18.08-rc1 -n
```

To build an lxqt version with a local package installed for the rock64:

```
sudo buildarmimg -d rock64 -e lxqt -i package-name-1.0-1-aarch64.pkg.tar.xz
```

## buildemmcinstaller
This script does almost the same as the `buildarmimg` script.

Except that it always creates a minimal image, with an already existing image inside it, only to be used for internal storage (eMMC) deployments.

**Syntax**
```
sudo buildemmcinstaller [-d device] [-e edition] -v version [-f flashversion] [-n] [-x] [-i package-file.pkg.tar.xz]
```

So to build an eMMC installer image for KDE Plasma 19.04 on Pinebook:
```
sudo buildemmcinstaller -d pinebook -e kde-plasma -v 19.04 -f first-emmc-flasher
```
Be aware that the device, edition and version, most already exist on the OSDN download page, else it won't work.


## buildrootfs
This script does exactly what it says it does. It builds a very small rootfs, to be used by the Manjaro ARM Installer and `buildarmimg`. Right now only supports `aarch64`.

**Syntax**
```
sudo buildrootfs
```

To build an aarch64 rootfs:
```
sudo buildrootfs
```

## builddockerimg
This script is similar to `buildrootfs`, except that it builds a rootfs ready for package building and turns it into a docker image, that can be uploaded to DockerHub.

**Syntax**
```
sudo builddockerimg
```
This uploads the docker file directly to the Manjaro ARM acccount on DockerHub.


## deployarmimg
This script will create checksums for and upload the newly generated image. It assumes you have upload access to our OSDN server.
If you don't, you can't use this.

**Syntax**

```
deployarmimg -i image [-d device] [-e edition] [-v version] -k email@server.org [-t] [-u osdn-username]
```

To upload an image to the raspberry pi minimal 18.07 folder use with torrent:

```
deployarmimg -i Manjaro-ARM-minimal-rpi3-18.07.img.xz -d rpi3 -e minimal -v 18.07 -k email@server.org -t
```

## getarmprofiles
This script will just clone or update the current profile list in `/usr/share/manjaro-arm-tools/profiles/`.
So nothing fancy.

This would enable users to clone the profiles repository, make any changes they would like to their images and then build them locally.
So if you made changes to the profiles yourself, don't run `getarmprofiles` and you will still have your edits.

But if you messed up your profiles somehow, you can start with the repo ones with:
```
sudo getarmprofiles -f
```
