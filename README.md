# Manjaro ARM Tools
Contains scripts and files needed to build and manage manjaro-arm packages and images.

This software is available in the Manjaro repository.

*These tools only work on Manjaro based distributions!*


## Known issues
* `deployarmpkg` does not add the packages to the repo. Wait for the server to do the automatic adding.

## Dependencies
These scripts rely on certain packages to be able to function. These packages are:
* parted (arch repo)
* manjaro-tools-base (manjaro repo)
* xz (arch repo)
* git (arch repo)
* zip (arch repo) (for `buildrootfs`)

### Optional Dependencies
* gzip (arch repo) (for `builddockerimg`)
* docker (arch repo) (for `builddockkerimg`)

This package also provides `binfmt-qemu-static`.

# Installation (Manjaro based distributions only)
## GIT version from Manjaro Strit repo
Add my repo to your `/etc/pacman.conf`:
```
[manjaro-strit]
SigLevel = Optional
Server = https://www.strits.dk/files/manjaro-strit/manjaro-strit-repo/$arch
```
Run `sudo pacman -Syyu manjaro-strit-keyring && sudo pacman -S manjaro-arm-tools-git`.

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
* Install `binfmt-qemu-static` package.

# Usage
## buildarmpkg
This script is used to create packages for ARM architectures.
It assumes you have filled out the PACKAGER section of your `/etc/makepkg.conf`.

Options inside [] are optional. Use `-h` to see what the defaults are.

**Syntax**

```
sudo buildarmpkg -p package [-a architecture] [-k] [-i package file]
```

To build an aarch64 package use the following command:

```
sudo buildarmpkg -p package -a aarch64
```

You can also build `any` packages, which will use the aarch64 architecture to build from.

```
sudo buildarmpkg -p package -a any
```

This places the packages created inside `/var/cache/manjaro-arm-tools/pkg/` in the architecture folder.

## deployarmpkg
This script is only for package maintainers of Manjaro-ARM.

This script assumes that you have enabled GPG signing on your machine, that you have a working key-pair and that you have a user on the Manjaro-ARM main server.
The `-p` option needs to be only the package. Not the full path to the package.

It will gpg sign and uploud the package you mention to the Manjaro-ARM main server.


**Syntax**

```
deployarmpkg -p package [-a architecture] -r repo -k keyid
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


## buildarmoem
**Supported devices:**
* oc2
* rpi3 (not the A/B+ models it seems)
* rpi4
* pinebook
* sopine
* rock64
* rockpro64
* on2
* rockpi4
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
* cubocore (not complete yet)
* server (not complete yet, unmaintained)


This script will zip up the image file and place it in `/var/cache/manjaro-arm-tools/img/`

Profiles that gets used are on the [Gitlab.com](https://gitlab.com/Strit/arm-profiles) website, so they are easier to fork and create merge requests.

**Syntax**

```
sudo buildarmoem [-d device] [-e edition] [-v version] [-n] [-x] [-i package-file.pkg.tar.xz]
```

To build a minimal image version 18.07 for the raspberry pi 3:

```
sudo buildarmoem -d rpi3 -e minimal -v 18.07
```

To build a minimal version 18.08 RC1 for the odroid-c2 with a new rootfs downloaded:

```
sudo buildarmoem -d oc2 -e minimal -v 18.08-rc1 -n
```

To build an lxqt version with a local package installed for the rock64:

```
sudo buildarmoem -d rock64 -e lxqt -i package-name-1.0-1-aarch64.pkg.tar.xz
```

## buildemmcinstaller
This script does almost the same as the `buildarmoem` script.

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
This script does exactly what it says it does. It builds a very small rootfs, to be used by the Manjaro ARM Installer and `buildarmoem`. Right now only supports `aarch64`.

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
This results in a .tar.gz file in /var/cache/manjaro-arm-tools/img/ that contains the docker image.


## deployarmimg
This script will create checksums for and upload the newly generated image. It assumes you have upload access to our OSDN server.
If you don't, you can't use this.
PS: The torrents will not have a tracker, until Manjaro comes up with a solution. So torrents won't be useful untl that happens.

**Syntax**

```
deployarmimg -i image [-d device] [-e edition] [-v version] -k email@server.org [-t]
```

To upload an image to the raspberry pi minimal 18.07 folder use with torrent:

```
deployarmimg -i Manjaro-ARM-minimal-rpi3-18.07.zip -d rpi3 -e minimal -v 18.07 -k email@server.org -t
```

## getarmprofiles
This script will just clone or update the current profile list in `/usr/share/manjaro-arm-tools/profiles/`.
So nothing fancy.

This would enable users to clone the profiles repository, make any changes they would like to their images and then build them localy.
So if you made changes to the profiles yourself, don't run `getarmprofiles` and you will still have your edits.

But if you messed up your profiles somehow, you can start with the repo ones with:
```
sudo getarmprofiles -f
```
