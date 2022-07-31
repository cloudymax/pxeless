#!/bin/bash
############
# Script to launch qemu-kvm guest VMs on a headless remote host
# This script utilizes qemu-system-x86_64 to create the VM instead of
# using virt-manager to prevent the need to create XML config files
# as well as to be able to manage the VMs without a UI/GUI
#
# This bash script is a proof-of-concept that ports the previous 
# VMM work found here: https://www.cloudydev.net/dev_ops/multipass/
# from multipass to QEMU/KVM
#
# The need to remove multipass derives from the fact that multipas 
# does not easliy work with non-ubuntu images, nor will it work to
# test .iso live usb images, which I need.
# 
# Multipass also cannot provide hardware accelerated (GPU) windows
# guest VMs, which I also need.
#
# Depends on grub-pc-bin, nmap, net-tools, cloud-image-utils, whois
set -Eeuo pipefail

deps(){
    sudo apt-get install \
      qemu-kvm \
      bridge-utils \
      virtinst \
      ovmf \
      qemu-utils \
      cloud-image-utils
}

# VM metadata
export_metatdata(){
  export IMAGE_TYPE="img" #img or iso
  export HOST_ADDRESS="192.168.50.100"
  export HOST_SSH_PORT="22"
  export VM_NAME="testvm"
  export VM_USER="vmadmin"
  export VM_SSH_PORT="1234"
  export DISK_NAME="boot.img"
  export DISK_SIZE="16G"
  export ISO_FILE="/home/ubuntu/public-infra/virtual-machines/qemu/debian-live-11.3.0-amd64-cinnamon.iso"
  export UBUNTU_CODENAME="jammy"
  export CLOUD_IMAGE_NAME="${UBUNTU_CODENAME}-server-cloudimg-amd64"
  export CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current"
  export MEMORY="8G"
  export SOCKETS="1"
  export PHYSICAL_CORES="4"
  export THREADS="1"
  export VGA="virtio"
  export VM_KEY=""
  export VM_KEY_FILE="$VM_USER"
  export UUID="none"
  export PASSWD="\$6\$saltsaltlettuce\$ua5R/p0ntvbHjz.RpRPLi7yx9Q731MsYUlxpUTojnjI8..EUtcoLF6HYEI0YrxKybdzfWIneiK6WH0uhH0FP01"
  export GPU_ACCEL="true"

  # set graphics options based on gpu presence.
  if [[ "$GPU_ACCEL" == "false" ]]; then
    export VGA_OPT="-nographic \\"
    export PCI_GPU="\\"
  else
    export PCI_GPU="-device vfio-pci,host=02:00.0,multifunction=on,x-vga=on \\"
    export VGA_OPT="-serial none -parallel none -parallel none \\"
  fi
}

# password hashing notes
# mkpasswd -m sha-512 password -s "saltsaltlettuce"

# create a directory to hold the VM assets
create_dir(){
  mkdir -p "$VM_NAME"
  cd "$VM_NAME"
  export UUID=$(uuidgen)
}

# download a cloud image as .img
download_cloud_image(){
  wget -c -O "$CLOUD_IMAGE_NAME".img \
  "$CLOUD_IMAGE_URL"/"$CLOUD_IMAGE_NAME".img
}

# Create and expanded image
expand_cloud_image(){
  qemu-img create -b ${CLOUD_IMAGE_NAME}.img -f qcow2 \
  	-F qcow2 ${CLOUD_IMAGE_NAME}-new.img \
  	"$DISK_SIZE"
}

# convert the .img to qcow2 to use as base layer
img_to_qcow(){
  qemu-img convert -f raw \
    -O qcow2 "$CLOUD_IMAGE_NAME"_original.img \
    "$CLOUD_IMAGE_NAME".qcow2
}

# create the next layer on the image
create_qcow_image(){
  qemu-img create -f qcow2 \
    -F qcow2 \
    -o backing_file="$CLOUD_IMAGE_NAME"_base.qcow2 \
    "$VM_NAME".qcow2
}

# create a ssh key for the user and save as a file w/ prompt
create_ssh_key(){
  ssh-keygen -C "$VM_USER" \
    -f "$VM_KEY_FILE" \
    -N '' \
    -t rsa

  VM_KEY_FILE=$(find "$(cd ..; pwd)" -name $VM_USER)
  VM_KEY=$(cat "$VM_KEY_FILE".pub)
}

# cloud-init logs are in /run/cloud-init/result.json
create_user_data(){
cat > user-data <<EOF
#cloud-config
#vim:syntax=yaml
hostname: ${VM_NAME}
fqdn: ${VM_NAME}
manage_etc_hosts: false
disable_root: false
users:
  - name: max
    gecos: Max R.
    groups: users, admin, docker, sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: "\$6\$rounds=4096\$VgM.5FWkzKe2.xhz\$eEUE6.dmeh8Z1bWfrct72DzntG1SjysiVGZ8nBvwjBt5ztFGC9G2iB8JoQwxhXodMrXrEkj647vNKm/uJU/wQ/"
    ssh_import_id:
      - gh:cloudymax
  - name: jesse
    gecos: Jesse H.
    groups: users, admin, docker, sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: "\$6\$rounds=4096\$iyzgS481lBTJsRFi\$TrOLK2ygk6WZ.hjFnew/YyGzX1OMEm.1s2azpuZnMQeNIeRKxegV1/iRo1XatGbr/ms6qBwRkumb63z7pOtvx."
    ssh_import_id:
      - gh:jessebot
  - name: bradley
    gecos: system acct
    groups: users, admin, docker, sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: "\$6\$rounds=4096\$9VgQ5dNMNB9DhP09\$zDdZaDx43CfNVFMLMblKTsYLl0P0I0Krh3FZsUVWh2pSv.h40pFAc4wo1sGqsdF2Ayn0Ro5Eai1gWan6uF2Q80"
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
package_update: true
package_upgrade: true
packages:
  - kubectl
  - helm
  - htop
  - docker.io
  - build-essential 
  - procps 
  - file
  - ubuntu-drivers-common
  - xinit
  - xterm
  - ubuntu-desktop
runcmd:
  - mkdir -p /new_kernel
  - wget -O /new_kernel/linux-headers-5.18.0-051800-generic_5.18.0-051800.202205222030_amd64.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.18/amd64/linux-headers-5.18.0-051800-generic_5.18.0-051800.202205222030_amd64.deb
  - wget -O /new_kernel/linux-headers-5.18.0-051800_5.18.0-051800.202205222030_all.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.18/amd64/linux-headers-5.18.0-051800_5.18.0-051800.202205222030_all.deb
  - wget -O /new_kernel/linux-image-unsigned-5.18.0-051800-generic_5.18.0-051800.202205222030_amd64.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.18/amd64/linux-image-unsigned-5.18.0-051800-generic_5.18.0-051800.202205222030_amd64.deb
  - wget -O /new_kernel/linux-modules-5.18.0-051800-generic_5.18.0-051800.202205222030_amd64.deb https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.18/amd64/linux-modules-5.18.0-051800-generic_5.18.0-051800.202205222030_amd64.deb
  - dpkg -i /new_kernel/*
  - ubuntu-drivers autoinstall
  - reboot now
EOF
}

# create a disk
create_virtual_disk(){
  #qemu-img create -f qcow2 \
  #  -F qcow2 \
  #  -b "$CLOUD_IMAGE_NAME"_base.qcow2 \
  #  hdd.qcow2 "$DISK_SIZE"
  qemu-img create -f qcow2 hdd.img $DISK_SIZE
}

# Generate an ISO image
generate_seed_iso(){
  cloud-localds seed.img user-data
}

# Boot exisiting cloud-init backed VM
boot_ubuntu_cloud_vm(){
  if tmux has-session -t "${VM_NAME}_session" 2>/dev/null; then
    echo "session exists"
  else
    tmux new-session -d -s "${VM_NAME}_session"
    tmux send-keys -t "${VM_NAME}_session" "sudo qemu-system-x86_64  \
      -machine accel=kvm,type=q35 \
      -cpu host,kvm="off",hv_vendor_id=null  \
      -smp sockets="$SOCKETS",cores="$PHYSICAL_CORES",threads="$THREADS" \
      -m "$MEMORY" \
      $VGA_OPT
      $PCI_GPU
      -device virtio-net-pci,netdev=net0 \
      -netdev user,id=net0,hostfwd=tcp::"$VM_SSH_PORT"-:"$HOST_SSH_PORT" \
      -drive if=virtio,format=qcow2,file="$CLOUD_IMAGE_NAME"-new.img \
      -bios /usr/share/ovmf/OVMF.fd \
      -usbdevice tablet \
      -vnc :0 \
      $@" ENTER
  fi
}

# start the cloud-init backed VM
create_ubuntu_cloud_vm(){
  if tmux has-session -t "${VM_NAME}_session" 2>/dev/null; then
    echo "session exists"
  else
    tmux new-session -d -s "${VM_NAME}_session"
    tmux send-keys -t "${VM_NAME}_session" "sudo qemu-system-x86_64  \
      -machine accel=kvm,type=q35 \
      -cpu host,kvm="off",hv_vendor_id="null" \
      -smp sockets="$SOCKETS",cores="$PHYSICAL_CORES",threads="$THREADS" \
      -m "$MEMORY" \
      $VGA_OPT
      $PCI_GPU
      -device virtio-net-pci,netdev=net0 \
      -netdev user,id=net0,hostfwd=tcp::"$VM_SSH_PORT"-:"$HOST_SSH_PORT" \
      -drive if=virtio,format=qcow2,file="$CLOUD_IMAGE_NAME"-new.img \
      -drive if=virtio,format=raw,file=seed.img \
      -bios /usr/share/ovmf/OVMF.fd \
      -usbdevice tablet \
      -vnc :0 \
      $@" ENTER
  fi

}

attach_to_vm_tmux(){
  export_metatdata
  tmux attach-session -t "${VM_NAME}_session"
}

ssh_to_vm(){
  export_metatdata
  ssh-keygen -f "/home/${USER}/.ssh/known_hosts" -R "[${HOST_ADDRESS}]:${VM_SSH_PORT}"
  ssh -o "StrictHostKeyChecking no" \
    -X \
    -i "$VM_NAME"/"$VM_USER" \
    -p "$VM_SSH_PORT" "$VM_USER"@"$HOST_ADDRESS"
}

vnc_tunnel(){
  export_metatdata
  ssh -o "StrictHostKeyChecking no" \
    -N -L 5001:"$HOST_ADDRESS":5900 \
    -i "/home/max/pxeless/virtual-machines/qemu/testvm/vmadmin" \
    -p "$VM_SSH_PORT" "$VM_USER"@"$HOST_ADDRESS"
}

# TODO 
# create an iso image https://quantum-integration.org/posts/install-cloud-guest-with-virt-install-and-cloud-init-configuration.html
#qemu-img create -f qcow2 -o \
#    backing_file=./master/centos-7-cloud.qcow2 \
#    example.qcow2

# luanch the VM to install from ISO to Disk
create_vm_from_iso(){
  tmux new-session -d -s "${VM_NAME}_session"
  tmux send-keys -t "${VM_NAME}_session" "sudo qemu-system-x86_64 \
    -machine accel=kvm,type=q35 \
    -cpu host,kvm="off",hv_vendor_id="null" \
    -smp sockets="$SOCKETS",cores="$PHYSICAL_CORES",threads="$THREADS" \
    -m "$MEMORY" \
    -cdrom $ISO_FILE \
    -object iothread,id=io1 \
    -device virtio-blk-pci,drive=disk0,iothread=io1 \
    -drive if=none,id=disk0,cache=none,format=qcow2,aio=threads,file=hdd.img \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::"$VM_SSH_PORT"-:"$HOST_SSH_PORT" \
    -bios /usr/share/ovmf/OVMF.fd \
    -vga virtio \
    -usbdevice tablet \
    -vnc :0 \
    $@" ENTER
}

boot_vm_from_iso(){
  tmux new-session -d -s "${VM_NAME}_session"
  tmux send-keys -t "${VM_NAME}_session" "sudo qemu-system-x86_64 \
    -machine accel=kvm,type=q35 \
    -cpu host,kvm="off",hv_vendor_id="null" \
    -smp sockets="$SOCKETS",cores="$PHYSICAL_CORES",threads="$THREADS" \
    -m "$MEMORY" \
    -object iothread,id=io1 \
    -device virtio-blk-pci,drive=disk0,iothread=io1 \
    -drive if=none,id=disk0,cache=none,format=qcow2,aio=threads,file=hdd.img \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::"$VM_SSH_PORT"-:"$HOST_SSH_PORT" \
    -bios /usr/share/ovmf/OVMF.fd \
    -vga virtio \
    -usbdevice tablet \
    -vnc :0 \
    $@" ENTER
}

create(){
  export_metatdata
  create_dir
  download_cloud_image
  expand_cloud_image
  create_ssh_key
  create_user_data
  generate_seed_iso
  create_virtual_disk
  #create_vm_from_iso
  create_ubuntu_cloud_vm
  attach_to_vm_tmux
}

boot(){
  export_metatdata
  create_dir
  #download_cloud_image
  #expand_cloud_image
  #create_ssh_key
  #create_user_data
  #generate_seed_iso
  boot_ubuntu_cloud_vm
  #boot_vm_from_iso
  attach_to_vm_tmux
}

"$@"

