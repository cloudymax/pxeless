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
  export GPU_ACCEL="false"

  # set graphics options based on gpu presence.
  if [[ "$GPU_ACCEL" == "false" ]]; then
    export VGA_OPT="-nographic \\"
  else
    export PCI_GPU="-device vfio-pci,host=02:00.0,multifunction=on,x-vga=on \\"
    export VGA_OPT="-vga none -nographic -serial none -parallel none \\"
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

cloud_config_modules:
 - runcmd

cloud_final_modules:
 - [users-groups, always]
 - [scripts-user, once-per-instance]

groups:
  - docker

ssh_pwauth: true
disable_root: false
users:
  - name: ${VM_USER}
    groups: docker, admin, sudo, users
    shell: /bin/bash
    sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]
    lock_passwd: false
    passwd: ${PASSWD}
    ssh-authorized-keys:
      - ${VM_KEY}
EOF
}

# create a disk
create_virtual_disk(){
  #qemu-img create -f qcow2 \
  #  -F qcow2 \
  #  -b "$CLOUD_IMAGE_NAME"_base.qcow2 \
  #  hdd.qcow2 "$DISK_SIZE"
  qemu-img create -f qcow2 /media/hdd.img $DISK_SIZE
}

# Generate an ISO image
generate_seed_iso(){
  cloud-localds seed.img user-data
}

# Boot exisiting cloud-init backed VM
boot_ubuntu_cloud_vm(){
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
    -vnc :0 \
    $@" ENTER
}

# start the cloud-init backed VM
create_ubuntu_cloud_vm(){
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
    -vnc :0 \
    $@" ENTER
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
    -drive if=none,id=disk0,cache=none,format=qcow2,aio=threads,file=/media/hdd.img \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::"$VM_SSH_PORT"-:"$HOST_SSH_PORT" \
    -vga virtio \
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
    -drive if=none,id=disk0,cache=none,format=qcow2,aio=threads,file=/media/hdd.img \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::"$VM_SSH_PORT"-:"$HOST_SSH_PORT" \
    -vga virtio \
    -vnc :0 \
    $@" ENTER
}

create(){
  export_metatdata
  create_dir
  #download_cloud_image
  #expand_cloud_image
  #create_ssh_key
  #create_user_data
  #generate_seed_iso
  create_virtual_disk
  create_vm_from_iso
  #create_ubuntu_cloud_vm
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
  #boot_ubuntu_cloud_vm
  boot_vm_from_iso
  attach_to_vm_tmux
}

"$@"

#
#
#  Connecting to the VM after install is done
#  1. SSH from the Host to Guest
#   ssh -X -Y -p "$VM_SSH_PORT" localhost
#
#  2. SSH from remote client to host and be redirected to guest
#   ssh -X -Y -p "$VM_SSH_PORT" max@"$HOST_ADDRESS"
#
#  3. Connect to Guest using QEMU's VNC server
#   "$HOST_ADDRESS":"$VM_SSH_PORT"
#  Get status of port
#
#  nmap -p 1234 localhost
#
#  VNC tunnel https://gist.github.com/chriszarate/bc34b7378d309f6c3af5
#
#
#  ssh -o "StrictHostKeyChecking no" \
#    -N -L 5001:"$HOST_ADDRESS":5900 \
#    -p "$VM_SSH_PORT" "VM_USER"@"HOST_ADDRESS"
