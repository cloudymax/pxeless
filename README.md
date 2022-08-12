# **PXEless**

PXEless is single-machine imaging and provisioning tool for environments where PXE is not an option or are not an option *yet*. 

It delivers a PXE-like imaging experience without the PXE-server by chaining together Cloud-Init, Ubiquity, and Ansible.

In this way, PXEless builds the "paved-road" upon which to deploy further applications and infrastructure.

## **Some uses for PXEless**

- Re-image a personal computer when combined with tools like [Onboardme!](https://github.com/jessebot/onboardme)
- Securely provision an IOT device.
- Bootstrap your initial host for tools like [Tinkerbell](https://github.com/tinkerbell), [Metal-As-A-Service](https://maas.io/) 
or [Metal3](https://metal3.io/).
- Deploy a self-hosted github/gitlab runner on metal or in a VM.
- Create a GPU-enabled VM Host/Kubernetes Node 
- Build a fully hyper-converged stack using your customized images and QEMU/KVM.

## **Components**

### **1. The Image Creator**

The Image Creator generates a customized Ubuntu/Debian cloud-image or Live image using Cloud-init and Ubiquity. 
These images can be mounted to a USB drive to re-image a metal host. They can also be used to boot Virtual Machines.


### **2. The Virtual Machines**

The included QEMU/multipass libraries create virtual machines that utilize the outputs of Image Creator.
This is useful for testing Live ISOs, creating GPU-enabled VM's with IOMMU passthrough, and more.


### **3. The Provisioner**

Provisioner is an ansible playbook + role library that accepts simple yaml files, and executes the defined actions.
It's agent-less and works on localhost, remote machines, containers, or anything else you can ssh into.

```bash
bash user-data.sh --update --upgrade \
  --password "password" \
  --github-username "cloudymax" \
  --username "max" \
  --vm-name "testvm" \
  --output-path "."

```

```yaml
  - name: ${VM_USER}
    gecos: system acct
    groups: users, admin, docker, sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: ${PASSWD}
    ssh_authorized_keys:
      - ${VM_KEY}
apt:
  primary:
    - arches: [default]
      uri: http://us.archive.ubuntu.com/ubuntu/
  sources:
    kubectl.list:
      source: deb [arch=amd64] https://apt.kubernetes.io/ kubernetes-xenial main
      keyid: 59FE0256827269DC81578F928B57C5C2836F4BEB
    helm.list:
      source: deb https://baltocdn.com/helm/stable/debian/ all main
      keyid: 81BF832E2F19CD2AA0471959294AC4827C1A168A
package_update: ${UPDATE}
package_upgrade: ${UPGRADE}
packages:
  - kubectl
  - wget
  - helm
  - htop
  - docker.io
  - build-essential
  - python3-pip
  - procps
  - file
  - ubuntu-drivers-common
  - xinit
  - xterm
  - xfce4
  - xfce4-goodies
  - x11vnc
runcmd:
  - mkdir -p /new_kernel
  - wget -O /new_kernel/linux-headers-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.19/amd64/linux-headers-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb
  - wget -O /new_kernel/linux-headers-5.19.0-051900_5.19.0-051900.202207312230_all.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.19/amd64/linux-headers-5.19.0-051900_5.19.0-051900.202207312230_all.deb
  - wget -O /new_kernel/linux-image-unsigned-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.19/amd64/linux-image-unsigned-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb
  - wget -O /new_kernel/linux-modules-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.19/amd64/linux-modules-5.19.0-051900-generic_5.19.0-051900.202207312230_amd64.deb
  - dpkg -i /new_kernel/*
  - apt-get purge linux-headers-5.15*
  - apt-get purge linux-image-5.15*
  - apt-get --purge autoremove
  - ubuntu-drivers autoinstall
  - wget https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
  - chmox +x /install.sh
  - chmod 777 /install.sh
  - sudo -u ${VM_USER} NONINTERACTIVE=1 /bin/bash /install.sh
  - sudo -u ${VM_USER} /home/linuxbrew/.linuxbrew/bin/brew shellenv >> /home/${VM_USER}/.profile
  - sudo -u max /home/linuxbrew/.linuxbrew/bin/brew shellenv >> /home/max/.profile
  - reboot now
```