# Public Infra

Open-source tooling for creating compute environments in various virtualization layers.

![img](media/Virtualization.drawio.svg)

## Image Creator

Create a customized Ubuntu/Debian cloud-image or Ubuntu Live image utilizing cloud-init. Use these images to boot and pre-provision bare-metal boxes or virtual machines.

## Virtual Machines

Create a VM to boot the custom image you just made.

Supported:
- Cloud-init customization for cloud and live images
- Boot from live-iso or cloud image
- QEMU/KVM + GPU Passthrough (WiP)
- Multipass w/out PCI/GPU passthrough
- Microvms (WiP)

## Ansible

Provision/configure the thing that we just booted. Works on containers too.

