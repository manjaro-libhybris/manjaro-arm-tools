# Manjaro ARM Tools
Contains scripts and files needed to build and manage manjaro-arm packages and images.

This software is available in the Manjaro repository.

*These tools only work on Manjaro based distributions!*

## Dependencies
These scripts rely on certain packages, other than what's in the `base` package group, to be able to function. These packages are:
* parted (arch repo)
* libarchive (arch repo)
* git (arch repo)
* binfmt-user-static (AUR) or manjaro-arm-qemu-static (manjaro repo)
* dosfstools (arch repo)
* pacman (arch repo)
* polkit (arch repo)
* gnugpg (arch repo)
* wget (arch repo)
* systemd-nspawn with support for `--resolv-conf=copy-host` (arch repo)

### Optional Dependencies
* gzip (arch repo) (for `builddockerimg`)
* docker (arch repo) (for `builddockkerimg`)
* mktorrent (arch repo) (for torrent support in `deployarmimg`)
* rsync (arch repo) (for `deployarmimg`)
* bmap-tools (AUR or manjaro repo) (for BMAP support in `buildarmimg`)
* btrfs-progs (arch repo) (for btrfs support in `buildarmimg`)

# Installation (Manjaro based distributions only)
## From Manjaro repositories (both x64 and aarch64)
Simply run `sudo pacman -S manjaro-arm-tools`.

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

## signarmpkgs
This script uses the GPG identity you have setup in your /etc/makepkg.conf to sign the packages in the current folder.

```
cd <folder with built packages>
signarmpkgs
```

## buildarmimg
**Supported devices:**
* halium-9
* halium-10
* halium-11
* xiaomi-onclite
* xiaomi-lavender
* xiaomi-miatoll
* xiaomi-dandelion
* google-sargo

**Supported editions:**
* minimal
* lxqt
* kde-plasma
* mate
* xfce
* i3
* sway
* gnome (experimental)
* budgie (experimental)
* plasma-mobile (experimental)
* phosh (experimental)
* cubocore (not complete yet)
* jade (not comlete yet)
* server (not complete yet, unmaintained)

This script will compress the image file and place it in `/var/cache/manjaro-arm-tools/img/`

Profiles that gets used are from this [github](https://github.com/manjaro-libhybris/arm-profiles) repository.

**Syntax**

```
sudo buildarmimg [-d device] [-e edition] [-v version] [-n] [-x] [-i package-file.pkg.tar.xz] [-b branch] [-m]
```

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

A log is located at /var/log/manjaro-arm-tools/buildrootfs-$(date +%Y-%m-%d-%H.%M).log

## builddockerimg
This script is similar to `buildrootfs`, except that it builds a rootfs ready for package building and turns it into a docker image, that can be uploaded to DockerHub.

**Syntax**
```
sudo builddockerimg
```
This uploads the docker file directly to the Manjaro ARM acccount on DockerHub.

A log is located at /var/log/manjaro-arm-tools/builddockerimg-$(date +%Y-%m-%d-%H.%M).log

## deployarmimg (depricated)
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
