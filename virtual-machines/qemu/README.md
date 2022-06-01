# GPU Accelereated Virtual Machines with QEMU

[QEMU](https://www.qemu.org/documentation/) is an open source machine emulator and virtualizer. It can be used for __system emulation__, where it provides a virtual model of an entire machine to run a guest OS or it may work with a another hypervisor like KVM or Xen. QEMU can also provide __user mode emulation__, where QEMU can launch processes compiled for one CPU on another CPU via emulation.

QEMU is special amongst its counterparts for a couple important reasons:

  - Like [ESXi](https://www.vmware.com/nl/products/esxi-and-esx.html), its capable of PCI passthrough for GPUs ([VirtualBox](https://docs.oracle.com/en/virtualization/virtualbox/6.0/user/guestadd-video.html) cant help us here)
  - Unlike ESXi, it's free
  - It's multi-platform
  - It's fast - not as fast as [LXD](https://linuxcontainers.org/lxd/introduction/), [FireCracker](https://firecracker-microvm.github.io/), or [Cloud-Hypervisor](https://github.com/cloud-hypervisor/cloud-hypervisor) (formerly [NEMU](https://github.com/intel/nemu)), but its far more mature and thoroughly documented. 
  - Unlike a [system container](https://linuxcontainers.org/lxd/introduction/) or [Multipass](https://multipass.run/docs) it can create windows hosts 
  - [Unlike Firecracker](https://github.com/firecracker-microvm/firecracker/issues/849#issuecomment-464731628) it supports pinning memmory addresses, and wont because it would break their core feature of over-subscription.

These qualities make QEMU well-suited for those seeking a hypervisor running the first layer of virtualization. In your second layer though, you should consider the lighter and faster LXD, Firecracker, or Cloud-Hypervisor.

## References

GPU Passthrough:

There's not a concensus among the industry on the exact way to handle the vfio configurations. Some people prefer to use kernel parameters, other prefer config files/modules etc. You'll find a mix among the various articles here.

|Author| CPU | GPU | modules | pci-ids |
|--|--|--|--|--|
|leducc|Intel|Nvidia|/etc/mkinitcpio.conf |GRUB_CMDLINE_LINUX_DEFAULT| 
|Mathias Hüber|AMD|Nvidia|/etc/initramfs-tools/modules|GRUB_CMDLINE_LINUX_DEFAULT and /etc/initramfs-tools/scripts/init-top/vfio.sh|
|Cale Rogers|Intel|Nvidia| GRUB_CMDLINE_LINUX and /etc/initram-fs/modules|/etc/modprobe.d/local.conf|
|Adam Gradzki|Intel|Intel| | |

- [GPU Passthrough on a Dell Precision 7540 and other high end laptops](https://leduccc.medium.com/simple-dgpu-passthrough-on-a-dell-precision-7450-ebe65b2e648e) - leduccc

- [Improving the performance of a Windows Guest on KVM/QEMU](https://leduccc.medium.com/improving-the-performance-of-a-windows-10-guest-on-qemu-a5b3f54d9cf5) - leduccc

- [Comprehensive guide to performance optimizations for gaming on virtual machines with KVM/QEMU and PCI passthrough](https://mathiashueber.com/performance-tweaks-gaming-on-virtual-machines/) - Mathias Hüber

- [gpu-virtualization-with-kvm-qemu](https://medium.com/@calerogers/gpu-virtualization-with-kvm-qemu-63ca98a6a172) - Cale Rogers

Adam Gradzki has an alternative method utilizing Intel GVT-g to shard an integrated Intel GPU

- [Faster Virtual Machines on Linux Hosts with GPU Acceleration](https://adamgradzki.com/2020/04/06/faster-virtual-machines-linux/)

Alex Williamson's guide is sadly a bit out of date, but still contains lots of worthwhile information.

- [vfio-gpu-how-to-series](http://vfio.blogspot.com/2015/05/vfio-gpu-how-to-series-part-1-hardware.html) by Alex Williamson

Everyone agrees on how to verufy the status of the system though:

```zsh
sudo lspci -nnk |grep -A4 NVIDIA |grep "Kernel driver"

sudo find /sys/kernel/iommu_groups/ -type l
```

Cloud-Init:

- [My Magical Adventure With cloud-init](https://christine.website/blog/cloud-init-2021-06-04) - Xe Iaso

Hypervisors:

- [A Study of Performance and Security Across the Virtualization Spectrum](https://repository.tudelft.nl/islandora/object/uuid:34b3732e-2960-4374-94a2-1c1b3f3c4bd5/datastream/OBJ/download) - Vincent van Rijn

- [virtualization-hypervisors-explaining-qemu-kvm-libvirt](https://sumit-ghosh.com/articles/virtualization-hypervisors-explaining-qemu-kvm-libvirt/) by Sumit Ghosh

Kubernetes/Docker:

- [Schedule GPUs in K8s](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/#deploying-amd-gpu-device-plugin)

- [NVIDIA Container Toolkit install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

Kernel Options:

- [Linux Kernel Params](https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html)

- [Intel i915 Driver Options](https://www.kernel.org/doc/html/latest/gpu/i915.html?highlight=vfio%20pci)

- [PCI VFIO options](https://www.kernel.org/doc/html/latest/driver-api/vfio-pci-device-specific-driver-acceptance.html?highlight=vfio%20pci)

- [KMV Ignore MSRs](https://www.kernel.org/doc/html/latest/virt/kvm/x86/msr.html?highlight=kvm%20ignore%20msrs)

- [root device (rd) kernel options](https://man7.org/linux/man-pages/man7/dracut.cmdline.7.html)

## Tested Hardware

```yaml
Node0:
  - GPU: "GTX 1070ti"
  - CPU: "i7-4770k"
  - RAM: "16GB"

Node1:
  - GPU: "RTX 2060"
  - CPU: "i7-11700"
  - RAM: "72GB"

Node2:
  - GPU: "gtx 970m"
  - CPU: "i7 4720HQ"
  - RAM: "16GB"
```

## Metal/Host PCIe Pass-Through Configuration

1. Getting your GPU PCIe Information

    Your GPU that you wish to pass through to the VM will often have other devices in its IOMMU group. If this is the case, ALL devices in that IOMMU group should be passed through to your VM. This shouldnt be too much of a problem, as those companion devices will likely be audio or busses that are attached to the GPU as well. This is only really an issue if your GPU for the Host and the GPU for the Guest are in the same IOMMU Group. If that's the case, you need to put the GPU in a differient PCI-e slot on your motherboard.

      - The [iommu-finder.sh](virtual-machines/qemu/host-config-resources/iommu-finder.sh) script will gather all the PCI devices and sort them cleanly based on their IOMMU Group:

        ```zsh
        # Replace NVIDIA with your grphics card manufacturer assumably. Untested on AMD/RADEON/INTEL.

        > bash iommu-finder.sh |grep NVIDIA |awk '{print $1$2,$3,$4,$5,$(NF-2)}'

        IOMMU Group 14 02:00.0 VGA [10de:1f08]
        IOMMU Group 14 02:00.1 Audio [10de:10f9]
        IOMMU Group 14 02:00.2 USB [10de:1ada]
        IOMMU Group 14 02:00.3 Serial [10de:1adb]
        ```

2. Enable IOMMU via Kernel Modules/Grub configuration

    From the output in the previous step, get the PCI Bus, Device ID, IOMMU Group, and Type of NVIDIA pci devices. Fortunately, all needed of these devices were already in separate IOMMU groups, or bundeled together in [group 14]. Use [vmhost.sh](https://github.com/cloudymax/public-infra/blob/main/virtual-machines/qemu/host-config-resources/vmhost.sh) to generate a GRUB_CMDLINE_LINUX_DEFAULT string.

    - example

      ```zsh
      GRUB_CMDLINE_LINUX_DEFAULT="amd_iommu=on iommu=pt kvm.ignore_msrs=1 vfio-pci.ids=10de:1f08,10de:10f9,10de:1ada,10de:1adb i915.enable_gvt=1 intel_iommu=igfx_off kvm.report_ignored_msrs=0 preempt=voluntary"
      ```

## Optimizations

- kernel upgrade:

  Get the latest from here: https://kernel.ubuntu.com/~kernel-ppa/mainline/?C=N;O=D

  ```zsh
  mkdir kernel_upgrade 
  cd kernel_upgrade

  wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.18/amd64/linux-headers-5.18.0-051800-generic_5.18.0-051800.202205222030_amd64.deb

  wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.18/amd64/linux-headers-5.18.0-051800_5.18.0-051800.202205222030_all.deb

  wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.18/amd64/linux-image-unsigned-5.18.0-051800-generic_5.18.0-051800.202205222030_amd64.deb

  wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.18/amd64/linux-modules-5.18.0-051800-generic_5.18.0-051800.202205222030_amd64.deb

  sudo dpkg -i *.deb
  ```

1. CPU Topology
    
    This one is pretty simple, when we allow QEMU/KVM to access the Host's CPU firectly without emulation, performance is better.


1. CPU Pinning

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
 
 
## VM creation (revision in progress)

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

## Set up a networking bridge, before RDP will work
Make sure bridge-utils is installed:
`sudo apt install bridge-utils`


edit `/etc/network/interfaces`:

```bash
auto lo
iface lo inet loopback

auto br0
iface br0 inet static
        address 192.168.50.100
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

reboot the host pc.


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


## with vnc
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

## Packages

```bash
sudo apt-get install qemu-kvm libvirt-bin bridge-utils virtinst ovmf qemu-utils
```

## Terms and Definitions

What do all the acronyms and buzzwords even *mean*?

|Term | Definition|
|---|---|
|**KMV**| Kernel Virtual Machine |
|**ESXi**| Elastic Sky X Integrated |
|**VFIO**| Virtual FunctionI/O |
|**QEMU**| Quick Emulator |
|**Metal Host**| A physical computer that runs VMs or containers |
|**Guest**| A VM or Container running on a Host |
