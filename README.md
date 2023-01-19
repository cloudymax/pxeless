# Pxeless [![GitHub Release](https://img.shields.io/github/v/release/cloudymax/pxeless?style=flat&labelColor=858585&color=6BF847&logo=GitHub&logoColor=white)](https://github.com/cloudymax/pxeless/releases)

An automated system install tool for when PXE is not an option, or is not an option *yet*.

Pxeless is based on [covertsh/ubuntu-autoinstall-generator](https://github.com/covertsh/ubuntu-autoinstall-generator), and generates a customized Ubuntu auto-intstall ISO using [cloud-init](https://cloudinit.readthedocs.io/en/latest/) and the new **autoinstall** feature of Ubuntu's Ubiquity installer.

## Behavior

 - Find an unmodified Ubuntu ISO image,
 - Download it,
 - Extract it,
 - Add some kernel command line parameters,
 - Add our custom cloud-init config,
 - Repack the data into a new ISO.
 - Create a bootable USB drive (Optional)

<img src="https://raw.githubusercontent.com/cloudymax/pxeless/develop/liveiso.drawio.svg">

## References

- The original project : [covertsh/ubuntu-autoinstall-generator](https://github.com/covertsh/ubuntu-autoinstall-generator)

- [Ubuntu autoinstall reference](https://ubuntu.com/server/docs/install/autoinstall-reference).

- [Cloud-Init options and examples](https://cloudinit.readthedocs.io/en/latest/index.html)

- [How-To: Make Ubuntu Autoinstall ISO with Cloud-init by Dr Donald Kinghorn](https://www.pugetsystems.com/labs/hpc/How-To-Make-Ubuntu-Autoinstall-ISO-with-Cloud-init-2213/)

- [My Magical Adventure with Cloud-Init by Xe Iaso](https://xeiaso.net/blog/cloud-init-2021-06-04)

- [Basic Example](user-data.basic)

- [Advanced Example](user-data.advanced)

## Command-line options

```
Usage: image-create.sh [-h] [-v] [-n] [-a] [-e] [-u user-data-file] [-m meta-data-file] [-k] [-c] [-r] [-s source-iso-file] [-d destination-iso-file]

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

-x, --extra-files       Specifies an folder with files and folders, which will be copied into the root of the iso image.
                        If not set, nothing is copied

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

## **Usage**

- Build a combined `autoinstall` + `cloud-init` image by using the ```-a``` flag and providing a **user-data** file containing the autoinstall configuration and cloud-init data.
A **meta-data** file may be included if you choose. The file will be empty if it is not specified. You may read more about providing a `meta-data` file [HERE](https://cloudinit.readthedocs.io/en/latest/topics/instancedata.html)

- With an 'all-in-one' ISO, you simply boot a machine using the ISO and the installer will do the rest.

- This script can use an existing ISO image or download the latest daily image from the Ubuntu project.
Using a fresh ISO speeds things up because there won't be as many packages to update during the installation.

- By default, the source ISO image is checked for integrity and authenticity using GPG. This can be disabled with `-k`.

- the newly added `-n`, `--code-name` flag allows you to specify an Ubuntu code-name instead of an exact version ie: `jammy`, `focal`

```bash
docker run --rm --volume "$(pwd):/data" --user $(id -u):$(id -g) deserializeme/pxeless \
-a -u user-data.basic -n jammy
```

## Credentials

The credentials for the included example user-data.basic are `usn: vmadmin`, and `pwd: password`.
To create your own credentials run:

```bash
mkpasswd -m sha-512 --rounds=4096 "some-password" -s "some-salt"
```

### Example output
```
docker build -t pxeless . && \
docker run --rm --volume "$(pwd):/data" --user $(id -u):$(id -g) pxeless \
-a -u user-data.basic -n jammy
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
## How it works

First we download the ISO of your choice - a daily build, or a release. (Daily builds are faster because they don't require as many updates/upgrades)

By default, the source ISO image is checked for integrity and authenticity using GPG. This can be disabled with ```-k```.

We combine an `autoistall` config from the Ubuntu [Ubiquity installer](https://wiki.ubuntu.com/Ubiquity), and a [cloud-init](https://cloudinit.readthedocs.io/en/latest/) `cloud-config` / `user-data` file.

The resulting product is a fully-automated Ubuntu install with pre-provision capabilities for basic users, groups, packages, storage, networks etc... This serves as an easy stepping-off point to Ansible, puppet, Chef and other configuration-management tooling for enterprise users, or to personalization tools like [jessebot/onboardme](https://github.com/jessebot/onboardme) for every-day users.

> Be aware that, while similar in schema, the Autoinstall and Cloud-Init portions of the file do not mix - the `user-data` key marks the transition from autoinstall to cloud-init syntax.

## Testing with QEMU

You will need to have a VNC client ([tigerVNC](https://tigervnc.org/) or [Remmina](https://remmina.org/) etc...) installed as well as the following packages:

```bash
    sudo apt-get install -y qemu-kvm \
        bridge-utils \
        virtinst\
        ovmf \
        qemu-utils \
        cloud-image-utils \
        ubuntu-drivers-common \
        whois \
        git \
        guestfs-tools
```

- You will need to replace my host IP (192.168.50.100) with your own.
- Also change the path to the ISO file to match your system.
- I have also set this VM to forward ssh over port 1234 instead of 22, feel free to change that as well.

1. Do fresh clone of the pxeless repo

2. Create the iso with

    ```bash
    docker run --rm --volume "$(pwd):/data" --user $(id -u):$(id -g) deserializeme/pxeless -a -u user-data.basic -n jammy
    ```
3.  Create a virtual disk with

    ```bash
    qemu-img create -f qcow2 hdd.img 8G
    ```

4. Create a test VM to boot the ISO files with

    ```bash
    sudo qemu-system-x86_64 -machine accel=kvm,type=q35 \
    -cpu host,kvm=off,hv_vendor_id=null \
    -smp 2,sockets=1,cores=1,threads=2,maxcpus=2 \
    -m 2G \
    -cdrom /home/max/repos/pxeless/ubuntu-autoinstall.iso \
    -object iothread,id=io1 \
    -device virtio-blk-pci,drive=disk0,iothread=io1 \
    -drive if=none,id=disk0,cache=none,format=qcow2,aio=threads,file=hdd.img \
    -netdev user,id=network0,hostfwd=tcp::1234-:22 \
    -device virtio-net-pci,netdev=network0 \
    -serial stdio -vga virtio -parallel none \
    -bios /usr/share/ovmf/OVMF.fd \
    -usbdevice tablet \
    -vnc 192.168.50.100:0
    ```
5. Select "Try or install Ubuntu" from the grub pop-up
    <img width="753" alt="Screenshot 2022-12-29 at 06 57 01" src="https://user-images.githubusercontent.com/84841307/209909893-e245bd60-87f2-4eca-990a-27c467f136e0.png">

6. Connect to the VM using VNC so we can watch the grub process run.

    <img width="555" alt="Screenshot 2022-12-29 at 07 01 06" src="https://user-images.githubusercontent.com/84841307/209911849-6416d311-aa45-4bbb-b77f-ae947bf0c281.png">


7. After the install process completes and the VM reboots, select the "Boot from next volume" grub option to prevent installing again

    <img width="753" alt="Screenshot 2022-12-29 at 06 58 50" src="https://user-images.githubusercontent.com/84841307/209909997-cb4886f7-1cda-41db-8f19-eb8493a1f5e9.png">
8. I was then able to log into he machine using `vmadmin` and `password` for the credentials

    <img width="555" alt="Screenshot 2022-12-29 at 07 00 01" src="https://user-images.githubusercontent.com/84841307/209910585-bfd540da-0eca-4209-87f9-fea0b0e36b95.png">

9. Finally i tried to SSH to the machine (since the vm I created is using SLIRP networking I have to reach it via a forwarded port)

    <img width="857" alt="Screenshot 2022-12-29 at 07 05 58" src="https://user-images.githubusercontent.com/84841307/209910665-f36001fc-0f83-469b-bb6f-725fd333ecf7.png">

The most common issues I run into with this process are improperly formatted yaml in the user-data file, and errors in the process of burning the ISO to a USB drive.

In those cases, the machine will perform a partial install but instead of seeing `pxeless login:` as the machine name at login it will still say `ubuntu login:`.

I prefer to use [Etcher](https://www.balena.io/etcher/) to create the USB drives on MacOS and dd on Linux as they seem to cause the fewest errors.

  ```zsh
  export IMAGE_FILE="ubuntu-autoinstall.iso"
  ```

 ```zsh
 # /dev/sdb is assumed for the sake of the example

 sudo fdisk -l |grep "Disk /dev/"

 export DISK_NAME="/dev/sdb"

 sudo umount "$DISK_NAME"

 sudo dd bs=4M if=$IMAGE_FILE of="$DISK_NAME" status=progress oflag=sync
```

### Contributors

<!-- readme: contributors -start -->
<table>
<tr>
    <td align="center">
        <a href="https://github.com/cloudymax">
            <img src="https://avatars.githubusercontent.com/u/84841307?v=4" width="100;" alt="cloudymax"/>
            <br />
            <sub><b>Max!</b></sub>
        </a>
    </td>
    <td align="center">
        <a href="https://github.com/lmunch">
            <img src="https://avatars.githubusercontent.com/u/5563316?v=4" width="100;" alt="lmunch"/>
            <br />
            <sub><b>Lars Munch</b></sub>
        </a>
    </td>
    <td align="center">
        <a href="https://github.com/koenvandesande">
            <img src="https://avatars.githubusercontent.com/u/803537?v=4" width="100;" alt="koenvandesande"/>
            <br />
            <sub><b>Koen Van De Sande</b></sub>
        </a>
    </td>
    <td align="center">
        <a href="https://github.com/Poeschl">
            <img src="https://avatars.githubusercontent.com/u/5469257?v=4" width="100;" alt="Poeschl"/>
            <br />
            <sub><b>Markus Pöschl</b></sub>
        </a>
    </td>
    <td align="center">
        <a href="https://github.com/ToroNZ">
            <img src="https://avatars.githubusercontent.com/u/8522935?v=4" width="100;" alt="ToroNZ"/>
            <br />
            <sub><b>Toro</b></sub>
        </a>
    </td>
    <td align="center">
        <a href="https://github.com/webbertakken">
            <img src="https://avatars.githubusercontent.com/u/20756439?v=4" width="100;" alt="webbertakken"/>
            <br />
            <sub><b>Webber Takken</b></sub>
        </a>
    </td></tr>
</table>
<!-- readme: contributors -end -->

### License
MIT license.

This spin-off project adds support for [eltorito + GPT images required for Ubuntu 20.10 and newer](https://askubuntu.com/questions/1289400/remaster-installation-image-for-ubuntu-20-10). It also keeps support for the [now depricated isolinux + MBR](https://archive.org/details/ubuntukylin2104-201214-daily) image type. In addition, the process is dockerized to make it possible to run on Mac/Windows hosts in addition to Linux. Automated builds via github actions have also been created.
