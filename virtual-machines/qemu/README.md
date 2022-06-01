# GPU Accelereated Virtual Machines

## Hypervisor

[QEMU](https://www.qemu.org/documentation/) is an open source machine emulator and virtualizer. It can be used for __system emulation__, where it provides a virtual model of an entire machine to run a guest OS or it may work with a another hypervisor like KVM or Xen. QEMU can also provide __user mode emulation__, where QEMU can launch processes compiled for one CPU on another CPU via emulation.

QEMU is special amongst its counterparts for a couple important reasons:

  - Like [ESXi](https://www.vmware.com/nl/products/esxi-and-esx.html), its capable of PCI passthrough for GPUs ([VirtualBox](https://docs.oracle.com/en/virtualization/virtualbox/6.0/user/guestadd-video.html) cant help us here)
  - Unlike ESXi, it's free
  - It's multi-platform
  - It's fast - not as fast as [LXD](https://linuxcontainers.org/lxd/introduction/), [FireCracker](https://firecracker-microvm.github.io/), or [Cloud-Hypervisor](https://github.com/cloud-hypervisor/cloud-hypervisor) (formerly [NEMU](https://github.com/intel/nemu)), but its far more mature and thoroughly documented. 
  - Unlike a [system container](https://linuxcontainers.org/lxd/introduction/) or [Multipass](https://multipass.run/docs) it can create windows hosts 
  - [Unlike Firecracker](https://github.com/firecracker-microvm/firecracker/issues/849#issuecomment-464731628) it supports pinning memmory addresses, and wont because it would break their core feature of over-subscription.

These qualities make QEMU well-suited for those seeking a hypervisor running the first layer of virtualization. In your second layer though, you should consider the lighter and faster LXD, Firecracker, or Cloud-Hypervisor.

## Requirements

WiP

## Usage

WiP - WiP -WiP

On the metal host: 

1. Clone the repo

2. `cd public-infra/virtual-machines/qemu/host-config-resources/`

3. `bash vmhost.sh full_run "NVIDIA"`

4. Reboot the metal host

5. `cd public-infra/virtual-machines/qemu/`

6. `bash vm.sh create`

7. press `ctrl` + `b`, then `d` to detach from the tmux session

8. connect to the vm with `bash vm.sh ssh_to_vm` or over VNC at `<metal-host-ip>:5900`


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
