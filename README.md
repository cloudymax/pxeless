# **PXEless**

PXEless is a provisioning tool for environments where PXE is not an option. 

It delivers PXE-like experience without a server by chaining together Cloud-Init, Ubiquity, and Ansible.

It is a single-machine bootstrapper that provisions metal hosts using a customized Live USB
instead of a network connection.

## **Some uses for PXEless:**

- Re-image a personal computer when combined with tools like [Onboardme!](https://github.com/jessebot/onboardme)
- Securely provision an IOT device.
- Bootstrap your initial host for tools like [Tinkerbell](https://github.com/tinkerbell), [Metal-As-A-Service](https://maas.io/) 
or [Metal3](https://metal3.io/).
- Deploy a self-hosted github/gitlab runner on metal or in a VM.
- Create a GPU-enabled Kubernetes Cluster 
- Build a fully hyper-converged stack using your customized images and QEMU/KVM.

## **Components**

### **1. The Image Creator**

The Image Creator generates a customized Ubuntu/Debian cloud-image or Live image using Cloud-init and Ubiquity. 
These images can be mounted to a USB drive to re-image a metal host. 
They can also be used to boot Virtual Machines.


### **2. The Virtual Machines**

The included QEMU/multipass libraries create virtual machines that utilize the outputs of Image Creator.
This is useful for testing Live ISOs, creating GPU-enabled VM's with IOMMU passthrough, and more.


### **3. The Provisioner**

Provisioner is an ansible playbook + role library that accepts simple yaml files, and executes the defined actions.
It's agent-less and works on localhost, remote machines, containers, or anything else you can ssh into.

