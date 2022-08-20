# Pxeless

An automated system install tool for when PXE is not an option, or is not an option *yet*.

Pxeless is based on [covertsh/ubuntu-autoinstall-generator](https://github.com/covertsh/ubuntu-autoinstall-generator), and generates a customized Ubuntu auto-intstall ISO using [cloud-init](https://cloudinit.readthedocs.io/en/latest/) and the new **autoinstall** feature of Ubuntu's Ubiquity installer. The credentials for the included example user-data.basic are `vmadmin`, and `password`.

## Behavior

 - Find an unmodified Ubuntu ISO image, 
 - Download it, 
 - Extract it, 
 - Add some kernel command line parameters, 
 - Add our custom cloud-init config,
 - Repack the data into a new ISO.
 - Create a bootable USB drive (Optional)
 

<img src="https://raw.githubusercontent.com/cloudymax/ubuntu-autoinstall-generator-dockerized/main/liveiso.drawio.svg">


## How it works

First we download the ISO of your choice - a daily build, or a release. (Daily builds are faster because they don't require as many updates/upgrades)

By default, the source ISO image is checked for integrity and authenticity using GPG. This can be disabled with ```-k```.

We combine an `autoistall` config from the Ubuntu [Ubiquity installer](https://wiki.ubuntu.com/Ubiquity), and a [cloud-init](https://cloudinit.readthedocs.io/en/latest/) `cloud-config` / `user-data` file. 

The resulting product is a fully-automated Ubuntu install with pre-provision capabilities for basic users, groups, packages, storage, networks etc... This serves as an easy stepping-off point to Ansible, puppet, Chef and other configuration-management tooling for enterprise users, or to personalization tools like [jessebot/onboardme](https://github.com/jessebot/onboardme) for every-day users.

> Be aware that, while similar in schema, the Autoinstall and Cloud-Init portions of the file do not mix - the `user-data` value on line 44 marks the transition from autoinstall to cloud-init syntax.

## References

- Autoinstall configuration options and schema can be found [HERE](https://ubuntu.com/server/docs/install/autoinstall-reference).

- Cloud-Init options and examples may be found [HERE](https://cloudinit.readthedocs.io/en/latest/index.html)

- You can also refer to the provided example file [HERE](image-creator/user-data.example)

## **Usage**

- Build a combined `autoinstall` + `cloud-init` image by using the ```-a``` flag and providing a **user-data** file containing the autoinstall configuration and cloud-init data.
A **meta-data** file may be included if you choose. The file will be empty if it is not specified. You may read more about providing a `meta-data` file [HERE](https://cloudinit.readthedocs.io/en/latest/topics/instancedata.html)

- With an 'all-in-one' ISO, you simply boot a machine using the ISO and the installer will do the rest.

- This script can use an existing ISO image or download the latest daily image from the Ubuntu project. 
Using a fresh ISO speeds things up because there won't be as many packages to update during the installation.

- By default, the source ISO image is checked for integrity and authenticity using GPG. This can be disabled with `-k`.

```bash
docker build -t iso-generator . && \
docker run -it --mount type=bind,source="$(pwd)",target=/app iso-generator \
ubuntu-autoinstall-generator.sh -a -u user-data.example -n jammy
```

## Command-line options
```
Usage: ubuntu-autoinstall-generator.sh [-h] [-v] [-a] [-e] [-u user-data-file] [-m meta-data-file] [-k] [-c] [-r] [-s source-iso-file] [-d destination-iso-file]

💁 This script will create fully-automated Ubuntu installation media.

Available options:

-h, --help              Print this help and exit

-v, --verbose           Print script debug info

-n, --code-name         The Code Name of the Ubuntu release to download (bionic, focal, jammy etc...)

-a, --all-in-one        Bake user-data and meta-data into the generated ISO. By default you will
                        need to boot systems with a CIDATA volume attached containing your
                        autoinstall user-data and meta-data files.
                        For more information see: https://ubuntu.com/server/docs/install/autoinstall-quickstart

-e, --use-hwe-kernel    Force the generated ISO to boot using the hardware enablement (HWE) kernel. Not supported
                        by early Ubuntu 20.04 release ISOs.

-u, --user-data         Path to user-data file. Required if using -a

-m, --meta-data         Path to meta-data file. Will be an empty file if not specified and using -a

-k, --no-verify         Disable GPG verification of the source ISO file. By default SHA256SUMS-<current date> and
                        SHA256SUMS-<current date>.gpg files in the script directory will be used to verify the authenticity and integrity
                        of the source ISO file. If they are not present the latest daily SHA256SUMS will be
                        downloaded and saved in the script directory. The Ubuntu signing key will be downloaded and
                        saved in a new keyring in the script directory.

-r, --use-release-iso   Use the current release ISO instead of the daily ISO. The file will be used if it already
                        exists.

-s, --source            Source ISO file. By default the latest daily ISO for Ubuntu 20.04 will be downloaded
                        and saved as <script directory>/ubuntu-original-<current date>.iso
                        That file will be used by default if it already exists.

-d, --destination       Destination ISO file. By default <script directory>/ubuntu-autoinstall-<current date>.iso will be
                        created, overwriting any existing file.
```


### Example output
```
docker build -t iso-generator . && \
docker run -it --mount type=bind,source="$(pwd)",target=/app iso-generator \
image-create.sh -a -u user-data.example -n jammy
...
...
...
...
[2022-06-19 14:36:41] 📁 Created temporary working directory /tmp/tmp.divHIg2PfD
[2022-06-19 14:36:41] 📁 Created temporary build directory /tmp/tmp.GzoJu7mqPa
[2022-06-19 14:36:41] 👶 Starting up...
[2022-06-19 14:36:41] 🔎 Checking for daily jammy release...
[2022-06-19 14:36:41] ✅ Daily release is 22.04
[2022-06-19 14:36:41] ✅ 22.04 is greater than 20.10. Not a legacy image.
[2022-06-19 14:36:41] 🔎 Checking for required utilities...
[2022-06-19 14:36:41] 👍 All required utilities are installed.
[2022-06-19 14:36:41] 🌎 Downloading ISO image for Ubuntu Server 22.04 LTS (Jammy Jellyfish) ...
/app/ubuntu-original-2022-06-19.iso                100%[===============================================================================================================>]   1.37G  31.8MB/s    in 45s     
[2022-06-19 14:37:27] 👍 Downloaded and saved to /app/ubuntu-original-2022-06-19.iso
[2022-06-19 14:37:27] 🌎 Downloading SHA256SUMS & SHA256SUMS.gpg files...
[2022-06-19 14:37:27] 🌎 Downloading and saving Ubuntu signing key...
[2022-06-19 14:37:28] 👍 Downloaded and saved to /tmp/tmp.divHIg2PfD/843938DF228D22F7B3742BC0D94AA3F0EFE21092.keyring
[2022-06-19 14:37:28] 🔐 Verifying /app/ubuntu-original-2022-06-19.iso integrity and authenticity...
[2022-06-19 14:37:41] 👍 Verification succeeded.
[2022-06-19 14:37:41] 🔧 Extracting ISO image...
[2022-06-19 14:37:49] 👍 Extracted to /tmp/tmp.GzoJu7mqPa
[2022-06-19 14:37:49] 🔧 Extracting MBR image...
[2022-06-19 14:37:49] 👍 Extracted to /tmp/tmp.divHIg2PfD/ubuntu-original-2022-06-19.mbr
[2022-06-19 14:37:49] 🔧 Extracting EFI image...
[2022-06-19 14:37:49] 👍 Extracted to /tmp/tmp.divHIg2PfD/ubuntu-original-2022-06-19.efi
[2022-06-19 14:37:49] 🧩 Adding autoinstall parameter to kernel command line...
[2022-06-19 14:37:49] 👍 Added parameter to UEFI and BIOS kernel command lines.
[2022-06-19 14:37:49] 🧩 Adding user-data and meta-data files...
[2022-06-19 14:37:49] 👍 Added data and configured kernel command line.
[2022-06-19 14:37:49] 👷 Updating /tmp/tmp.GzoJu7mqPa/md5sum.txt with hashes of modified files...
[2022-06-19 14:37:49] 👍 Updated hashes.
[2022-06-19 14:37:49] 📦 Repackaging extracted files into an ISO image...
[2022-06-19 14:37:54] 👍 Repackaged into ubuntu-autoinstall-2022-06-19.iso
[2022-06-19 14:37:54] ✅ Completed.
```

## Create a bootable usb flash drive

```zsh
export IMAGE_FILE="ubuntu-autoinstall-2022-06-19.iso"
```

 ```zsh
 # /dev/sdb is assumed for the sake of the example

 sudo fdisk -l |grep "Disk /dev/"

 export DISK_NAME="/dev/sdb"

 sudo umount "$DISK_NAME"

 sudo dd bs=4M if=$IMAGE_FILE of="$DISK_NAME" status=progress oflag=sync
```

### License
MIT license.

This spin-off project adds support for [eltorito + GPT images required for Ubuntu 20.10 and newer](https://askubuntu.com/questions/1289400/remaster-installation-image-for-ubuntu-20-10). It also keeps support for the [now depricated isolinux + MBR](https://archive.org/details/ubuntukylin2104-201214-daily) image type. In addition, the process is dockerized to make it possible to run on Mac/Windows hosts in addition to Linux. Automated builds via github actions have also been created.
