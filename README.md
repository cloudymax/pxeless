# What is PXEless? [![GitHub Release](https://img.shields.io/github/v/release/cloudymax/pxeless?style=flat&labelColor=858585&color=6BF847&logo=GitHub&logoColor=white)](https://github.com/cloudymax/pxeless/releases)

It's an automated system install and image-creation tool for situations where provisioning machines via a PXE server is not an option, or is not an option *yet*. It's ideal for small-scale greenfielding, proofs-of-concept, and general management of on-prem compute infrastructure in a cloud-native way without the cloud.

PXEless is based on [covertsh/ubuntu-autoinstall-generator](https://github.com/covertsh/ubuntu-autoinstall-generator), and generates a customized Ubuntu auto-intstall ISO. This is accomplished by using [cloud-init](https://cloudinit.readthedocs.io/en/latest/) and Ubuntu's [Ubiquity installer](https://wiki.ubuntu.com/Ubiquity) - specifically the server variant known as [Subiquity](https://github.com/canonical/subiquity), which itself wraps [Curtin](https://launchpad.net/curtin).

## How does PXEless work?

1. Download the ISO of your choice - a daily build, or a release.
2. Extracts the EFI, MBR, and File-System from the ISO
3. Adds some kernel command line parameters
4. Adds customised autoinstall and cloud-init configuration files
5. Adds arbitrary files to the squashfs (Optional)
6. Repacks the data into a new ISO.

The resulting product is a fully-automated Ubuntu installer. This serves as an easy stepping-off point for configuration-management tooling like Ansible, Puppet, and Chef or personalization tools like [jessebot/onboardme](https://github.com/jessebot/onboardme).

<p align="center">
<img src="https://raw.githubusercontent.com/cloudymax/pxeless/develop/liveiso.drawio.svg" />
</p>

> Be aware that, while similar in schema, the Autoinstall and Cloud-Init portions of the `user-data` file do not mix. The `user-data` key marks the transition from autoinstall to cloud-init syntax. [example](https://github.com/cloudymax/pxeless/blob/62c028c885a9c37318092dd67a02005b3595f610/user-data.basic#L14)


## Quickstart

1. Clone the rpos

    ```bash
    git clone https://github.com/cloudymax/pxeless.git
    ```

2. Change directory to the root of the repo

    ```bash
    cd pxeless
    ```

3. Execute via Docker

    ```bash
    docker run --rm --volume "$(pwd):/data" --user $(id -u):$(id -g) deserializeme/pxeless \
    -a -u user-data.basic -n jammy
    ```
    
4. The credentials for the included example user-data.basic are `usn: vmadmin`, and `pwd: password`.
To create your own credentials run:

    ```bash
    mkpasswd -m sha-512 --rounds=4096 "some-password" -s "some-salt"
    ```

## Command-line options

|Short  |Long    |Description|
| :--- | :---  | :---    |
| -h    | --help | Print this help and exit |
| -v  |--verbose| Print script debug info|
| -n  | --code-name| The Code Name of the Ubuntu release to download (bionic, focal, jammy etc...)|
| -a  | --all-in-one| Bake user-data and meta-data into the generated ISO. By default you will need to boot systems with a CIDATA volume attached containing your autoinstall user-data and meta-data files. For more information see: https://ubuntu.com/server/docs/install/autoinstall-quickstart |
| -e  | --use-hwe-kernel| Force the generated ISO to boot using the hardware enablement (HWE) kernel. Not supported by early Ubuntu 20.04 release ISOs. |
| -u  | --user-data| Path to user-data file. Required if using -a|
| -m  | --meta-data| Path to meta-data file. Will be an empty file if not specified and using the `-a` flag. You may read more about providing a `meta-data` file [HERE](https://cloudinit.readthedocs.io/en/latest/topics/instancedata.html)|
| -x  | --extra-files| Specifies an folder with files and folders, which will be copied into the root of the iso image. If not set, nothing is copied|
| -k  | --no-verify| Disable GPG verification of the source ISO file. By default SHA256SUMS-<current date> and SHA256SUMS-<current date>.gpg files in the script directory will be used to verify the authenticity and integrity of the source ISO file. If they are not present the latest daily SHA256SUMS will be downloaded and saved in the script directory. The Ubuntu signing key will be downloaded and saved in a new keyring in the script directory.|
| -r  | --use-release-iso| Use the current release ISO instead of the daily ISO. The file will be used if it already exists.|
| -s  | --source| Source ISO file. By default the latest daily ISO for Ubuntu 20.04 will be downloaded  and saved as `script directory/ubuntu-original-current date.iso` That file will be used by default if it already exists.|
| -d  | --destination |      Destination ISO file. By default script directory/ubuntu-autoinstall-current date.iso will be created, overwriting any existing file.|

## Sources 

This project is made possible through the open-source work of the following authors and many others. Thank you all for sharing your time, effort, and knowledge freely with us. You are the giants upon whos shoulders we stand. :heart:

| Reference | Author | Description |
| ---     |  ---   |    ---      |
| [ubuntu-autoinstall-generator](https://github.com/covertsh/ubuntu-autoinstall-generator)| [covertsh](github.com/covertsh)| The original project that PXEless is based off of. If the original author ever becomes active again, I would love to merge these changes back. |
|[Ubuntu Autoinstall Docs](https://ubuntu.com/server/docs/install/autoinstall-reference)| Canonical | Official documentation for the Ubuntu Autoinstall process |
[Cloud-Init Docs](https://cloudinit.readthedocs.io/en/latest/index.html) | Canonical | The official docs for the Cloud-Init project|
|[How-To: Make Ubuntu Autoinstall ISO with Cloud-init](https://www.pugetsystems.com/labs/hpc/How-To-Make-Ubuntu-Autoinstall-ISO-with-Cloud-init-2213/) | [Dr Donald Kinghorn](https://www.pugetsystems.com/bios/donkinghorn/) | A great walkthrough of how to manually create an AutoInstall USB drive using Cloud-Init on Ubuntu 20.04 |
|[My Magical Adventure with Cloud-Init](https://xeiaso.net/blog/cloud-init-2021-06-04)| [Xe Iaso](https://xeiaso.net/) | Excellent practical example of how to manipulate cloud-init's execution order by specifying module order|
|[Basic user-data example](user-data.basic) | Cloudymax | A very basic user-data file that will provision a user with a password |
|[Advanced user-data example](user-data.advanced) | Cloudymax | |
    
    
## Need something different?

PXEless currently only supports creating ISO's using Ubuntu Server (Focal and Jammy). Users who's needs ae not met by PXEless may find these other FOSS projects useful:

| Project Name | Description |
| ---  | ---         |
|[Tinkerbell](https://github.com/tinkerbell) | A flexible bare metal provisioning engine. Open-sourced by the folks @equinixmetal; currently a sandbox project in the CNCF |
|[Metal³](https://github.com/metal3-io)| Bare Metal Host Provisioning for Kubernetes and preferred starting point for [Cluster API](https://cluster-api.sigs.k8s.io/) |
|[Metal-as-a-Service](https://github.com/maas/maas)| Treat physical servers like virtual machines in the cloud. MAAS turns your bare metal into an elastic cloud-like resource|
|[Packer](https://github.com/hashicorp/packer)| A tool for creating identical machine images for multiple platforms from a single source configuration. 
|[Clonezilla Live!](https://gitlab.com/stevenshiau/clonezilla)| A partition or disk clone tool similar to Norton Ghost®. It saves and restores only used blocks in hard drive. Two types of Clonezilla are available, Clonezilla live and Clonezilla SE (Server Edition)|


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
