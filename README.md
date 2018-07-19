# manjaro-arm-tools
Contains scripts and files needed to build and manage manjaro-arm packages and images.
This software an all it's dependencies are available in the Manjaro Strit repo's, if you run Manjaro.


## Known issues
* `buildarmimg` does not create working odroid images

# Usage
## buildarmpkg
This script is used to create packages for ARM architectures.
It assumes you have filled out the PACKAGER section of your `/etc/makepkg.conf`.

**Syntax**

```
buildarmpkg package architecture
```

To build an armv7h package, place yourself in the folder, that contains a folder with the PKGBUILD, named as the package you want to build. Then run:

```
buildarmpkg package armv7h
```

This will build the package called "package" for the armv7h architecture.

To build an aarch64 package it's the same, just with

```
buildarmpkg package aarch64
```

You can also build `any` packages, which will use the armv7h architecture to build from.

```
buildarmpkg package any
```

This places the packages created inside `/var/cache/manjaro-arm-tools/pkg/` in either armv7h folder or aarch64 folder.

## deployarmpkg
This script is only for package maintainers of Manjaro-ARM.

This script assumes that you have enabled GPG signing on your machine, that you have a working key-pair and that you have a user on the Manjaro-ARM main server.

It will gpg sign and uploud the package you mention to the Manjaro-ARM main server.


**Syntax**

```
deployarmpkg package architecture repo
```

To upload a package to the armv7h core repo use:

```
deployarmpkg package.pkg.tar.xz armv7h core
```

To upload a package to the aarch64 extra repo use:

```
deployarmpkg package.pkg.tar.xz aarch64 extra
```

To upload an any package to the community repo use:

```
deployarmpkg package.pkg.tar.xz any community
```

This should be used after creating a package with `buildarmpkg` and cd'ing to the cache folder. It will sign the package with your default secret GPG key and upload both files
and remove the local files.

## buildarmimg
This script is the most complicated of them and it assumes that you have the following packages (arch package names) installed:
* manjaro-tools-base (manjaro-repo)
* qemu (arch repo)
* parted (arch repo)
* qemu-user-static (AUR or manjaro-strit repo)
* binfmt-support-git (AUR or manjaro-strit repo)
* binfmt-qemu-static (AUR or manjaro-strit repo)

**Supported devices:**
* rpi2
* oc1
* oc2
* xu4 (not tested)

**Supported editions:**

minimal

*more to come*

The script breafly replaces your `/etc/pacman.d/mirrorlist` with that of manjaro-arm to fetch the right packages.

This means that it will place all downloaded packages for the images in your own `/var/cache/pacman/pkg/` including `any` packages.

This is because they are signed by other keys than the ones in regular manjaro/arch repositories. This will create a corrupt signature next time you try to install the packages from the cache.

If that happens, just try running the command again. This script will zip up the image file and place it in `/var/cache/manjaro-arm-tools/img/`

**Syntax**

```
buildarmimg device edition version
```

To build a minimal image version 18.07 for the raspberry pi 2/3:

```
buildarmimg rpi2 minimal 18.07
```

To build a minimal image version 18.08 RC1 for the odroid-c2:

```
buildarmimg oc2 minimal 18.08-rc1
```

## deployarmimg
This script will create checksums for and upload the newly generated image.

**Syntax**

```
deployarmimg image device edition version
```

To upload an image to the raspberry pi minimal 18.07 folder use:

```
deployarmimg Manjaro-ARM-minimal-rpi2-18.07.zip rpi2 minimal 18.07
```
