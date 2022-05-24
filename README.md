# [QEMU](https://www.qemu.org/) Virtual Machines

QEMU is a generic and open source machine emulator and virtualizer. It can be used for __system emulation__, where it provides a virtual model of an entire machine to run a guest OS or it may work with a hypervisor such as KVM, Xen, Hax or Hypervisor. The second supported way to use QEMU is __user mode emulation__, where QEMU can launch processes compiled for one CPU on another CPU. In this mode the CPU is always emulated.

QEMU is special among its counterparts for a couple important reasons:

  - Like ESXi, its capable of PCI passthrough for GPUs (VirtualBox cant help us here)
  - Unlike ESXi, it's free
  - It's multi-platform
  - It's fast - not as fast as LXD, FireCracker, Cloud-Hypervisor, or NEMU however it's way more mature and documented 


## Sources

- [Improving the performance of a Windows Guest on KVM/QEMU](https://leduccc.medium.com/improving-the-performance-of-a-windows-10-guest-on-qemu-a5b3f54d9cf5) - leduccc

- [My Magical Adventure With cloud-init](https://christine.website/blog/cloud-init-2021-06-04) - Xe Iaso

- [Faster Virtual Machines in Linux](https://adamgradzki.com/2020/04/06/faster-virtual-machines-linux/)

- [gpu-virtualization-with-kvm-qemu](https://medium.com/@calerogers/gpu-virtualization-with-kvm-qemu-63ca98a6a172)
 by Cale Rogers

- [vfio-gpu-how-to-series](http://vfio.blogspot.com/2015/05/vfio-gpu-how-to-series-part-1-hardware.html) by Alex Williamson

- [virtualization-hypervisors-explaining-qemu-kvm-libvirt](https://sumit-ghosh.com/articles/virtualization-hypervisors-explaining-qemu-kvm-libvirt/) by Sumit Ghosh

- [Schedule GPUs in K8s](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/#deploying-amd-gpu-device-plugin)

- [NVIDIA Container Toolkit install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

## Tested Hardware

```yaml
Compububu:
  - GPU: "GTX 1070ti"
  - CPU: "i7-4770k"
  - RAM: "16GB"
BigBradley:
  - GPU: "RTX 2060"
  - CPU: "i7-11700"
  - RAM: "72GB"
FlatBradley:
  - GPU: "gtx 970m"
  - CPU: "i7 4720HQ"
  - RAM: "16GB"
```

## Metal Configuration

1. Getting your GPU PCIe Information

Your GPU that you wish to pass through to the VM will often have other devices in its IOMMU group.
If this is the case, ALL devices in that IOMMU group should be passed through to your VM.
This shouldnt be too much of a problem, as those companion devices will likely be audio or busses that 
are attached to the GPU as well. 
This is only really an issue if your GPU for the Host and the GPU for the Guest are in the same IOMMU Group.
If that's the case, you need a patched kernel[idk how to do it yet] or to put the GPU in a differient PCI-e slot on your motherboard.

The [iommu-finder.sh](virtual-machines/iommu-finder.sh) script will gather all the PCI devices and sort them cleanly based on their IOMMU Group:

```zsh
> bash iommu-finder.sh |grep NVIDIA |awk '{print $1,$2,$3,$4,$5,$(NF-2)}'

IOMMU Group 14 02:00.0 VGA [10de:1f08]
IOMMU Group 14 02:00.1 Audio [10de:10f9]
IOMMU Group 14 02:00.2 USB [10de:1ada]
IOMMU Group 14 02:00.3 Serial [10de:1adb]
```

2. Kernel Modules/Grub configuration

From the above output, get the PCI Bus, Device ID, IOMMU Group, and Type of NVIDIA pci devices. Fortunately, all needed of these devices were already in separate IOMMU groups, or bundeled together in [group 14]. Use these values modify kernel modules via a script or with a kernel mod line in /etc/defaul/grub

- /etc/defaut/grub

  ```zsh
  GRUB_CMDLINE_LINUX_DEFAULT="amd_iommu=on iommu=pt kvm.ignore_msrs=1 vfio-pci.ids=<someID-0>,<someID-1>"
  ```

- module script

  ```zsh

  cat << EOF > /etc/initramfs-tools/scripts/init-top/vfio.sh
  #!/bin/sh

  # VGA-compatible-controller
  PCIbusID0="01:00.0"

  # audio-device
  PCIbusID1="01:00.1"

  PREREQ=""

  prereqs()
  {
     echo "$PREREQ"
  }

  case $1 in
  prereqs)
     prereqs
     exit 0
     ;;
  esac

  for dev in 0000:"$PCIbusID0" 0000:"$PCIbusID1"
  do 
   echo "vfio-pci" > /sys/bus/pci/devices/$dev/driver_override 
   echo "$dev" > /sys/bus/pci/drivers/vfio-pci/bind 
  done

  exit 0

  EOF

  ```

3. Set the kernel module options by creating a replacement config file for: "/etc/initramfs-tools/modules"


- Create the file in the local dir

  ```zsh

  cat << EOF > modules
  # List of modules that you want to include in your initramfs.
  # They will be loaded at boot time in the order below.
  #
  # Syntax:  module_name [args ...]
  #
  # You must run update-initramfs(8) to effect this change.
  #
  # Examples:
  #
  # raid1
  # sd_mod
  options kvm ignore_msrs=1
  EOF

  ```

- Move it into place and correct the ownership and pemrissions

  ```zsh
  sudo mv /etc/initramfs-tools/modules /etc/initramfs-tools/modules.bak
  sudo mv modules /etc/initramfs-tools/
  sudo chown root:root /etc/initramfs-tools/modules 
  sudo chmod 644 /etc/initramfs-tools/modules 
  ```


4. CPU Pinning

```zsh
 <vcpu placement='static'>14</vcpu>
 <iothreads>1</iothreads>
 <cputune>
    <vcpupin vcpu='0' cpuset='1'/>
    <vcpupin vcpu='1' cpuset='2'/>
    <vcpupin vcpu='2' cpuset='3'/>
    <vcpupin vcpu='3' cpuset='4'/>
    <vcpupin vcpu='4' cpuset='5'/>
    <vcpupin vcpu='5' cpuset='6'/>
    <vcpupin vcpu='6' cpuset='7'/>
    <vcpupin vcpu='7' cpuset='9'/>
    <vcpupin vcpu='8' cpuset='10'/>
    <vcpupin vcpu='9' cpuset='11'/>
    <vcpupin vcpu='10' cpuset='12'/>
    <vcpupin vcpu='11' cpuset='13'/>
    <vcpupin vcpu='12' cpuset='14'/>
    <vcpupin vcpu='13' cpuset='15'/>
    <emulatorpin cpuset='0,8'/>
    <iothreadpin iothread='1' cpuset='0,8'/>
 </cputune>
```
 
 
## VM creation

Once we can get into the GUI we must update some group policy values to set the proper GPU for use with RDP connections

```zsh
qemu-system-x86_64 \
    -hda win10.img \
    -boot c \
    -machine type=q35,accel=kvm \
    -cpu host,kvm="off" \
    -smp sockets=1,cores=2,threads=2 \
    -m 8G \
    -vga std
    -serial none \
    -parallel none \
    -device vfio-pci,host=01:00.0,multifunction=on \
    -device vfio-pci,host=01:00.1 \
    -net nic,model=e1000 \
    -net user 
```

We also need to record the ip address for the vm. 
For this example is "10.0.2.15"

Now we can connect via rdp

# Set up a networking bridge, before RDP will work
Make sure bridge-utils is installed:
`sudo apt install bridge-utils`


edit `/etc/network/interfaces`:

```
auto lo
iface lo inet loopback

auto br0
iface br0 inet static
        address 192.168.50.23
        network 192.168.50.0
        netmask 255.255.255.0
        broadcast 192.168.50.255
        gateway 192.168.50.1
        dns-nameservers 192.168.50.1 1.1.1.1
        bridge_ports eth0
        bridge_stp off
        bridge_fd 0
        bridge_maxwait 0
```

Restart networking? :shrug: maybe reboot if you can't figure that out :shrug:

The XML for the networking in virtual manager:
```xml
<interface type="network">
  <mac address="52:54:00:1b:70:45"/>
  <source network="default"/>
  <model type="e1000e"/>
  <address type="pci" domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
</interface>
```

What we're gonna change it to:
```xml
<interface type="bridge">
  <mac address="52:54:00:1b:70:45"/>
  <source brdige="br0"/>
</interface>
```


# with vnc
```zsh
qemu-system-x86_64 \
  -drive id=disk0,if=virtio,cache=none,format=raw,file=Win10-AlternateInstall.img \
  -drive file=Win10_21H2_EnglishInternational_x64.iso,index=1,media=cdrom \
  -boot c \
  -machine type=q35,accel=kvm \
  -cpu host,kvm="off" \
  -smp sockets=1,cores=2,threads=2 \
  -m 8G \
  -vga none -nographic -serial none -parallel none \
  -device vfio-pci,host=01:00.0,multifunction=on \
  -device vfio-pci,host=01:00.1 \
  -device virtio-net,netdev=vmnic \
  -netdev user,id=vmnic \
  -net nic,model=e1000 \
  -net user \
  -vnc 127.0.0.1:2
```

To get to bios, this worked, and spits you into a shell, which you then hit exit on and select boot manager.
  
```zsh
sudo qemu-system-x86_64 \
   # primary hard disk \
   -drive id=disk0,if=virtio,cache=none,format=raw,file=Win10-AlternateInstall.img \
   # Windows Installer ISO Image \
   -drive file=Win10_21H2_EnglishInternational_x64.iso,index=1,media=cdrom \
   # Driver installer ISO \
   #-drive file=virtio-win-0.1.141.iso,index=0,media=cdrom \
   -boot c \
   -machine type=q35,accel=kvm \
   -cpu host,kvm="off" \
   -smp sockets=1,cores=2,threads=2 \
   -m 8G \
   -serial none \
   -parallel none \
   # GTX 1070 TI \
   -device vfio-pci,host=01:00.0,multifunction=on \
   # GTX 1070 TI HDMI Audio \
   -device vfio-pci,host=01:00.1 \
   -net nic,model=e1000 \
   -net user \
   -bios /usr/share/qemu/OVMF.fd \
   # if you need a remote connection
   -vnc 127.0.0.1:2


sudo qemu-system-x86_64 \
   -hda Win10-AlternateInstall.img \
   -boot c \
   -machine type=q35,accel=kvm \
   -cpu host,kvm="off" \
   -smp sockets=1,cores=2,threads=2 \
   -m 8G \
   -serial none \
   -parallel none \
   -device vfio-pci,host=01:00.0,multifunction=on \
   -device vfio-pci,host=01:00.1 \
   -device virtio-net,netdev=vmnic \
   -netdev user,id=vmnic \
   -net nic,model=e1000 \
   -net user \
   -bios /usr/share/qemu/OVMF.fd
```