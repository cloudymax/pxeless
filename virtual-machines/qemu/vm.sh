#!/bin/bash
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
  export VM_NAME="test"
  export VM_USER="${VM_NAME}admin"
  export DISK_NAME="boot.img"
  export DISK_SIZE="20G"
  export MEMORY="8G"
  export SOCKETS="1"
  export PHYSICAL_CORES="2"
  export THREADS="2"
  export VM_KEY=""
  export VM_KEY_FILE="$VM_USER"
  export UUID="none"
  export MAC_ADDR=$(printf 'DE:AD:BE:EF:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)))
  export PASSWD=$(mkpasswd -m sha-512 "password" -s "saltsaltlettuce" | sed 's/\$/\\$/g')
  export GPU_ACCEL="false"

  # Set network options
  export STATIC_IP="false"
  export HOST_ADDRESS="192.168.50.100"
  export HOST_SSH_PORT="22"
  export VM_SSH_PORT="1234"
  export VNC_PORT="0"

  if [[ "$STATIC_IP" == "true" ]]; then
    export NETDEV="-netdev bridge,br=br0,id=net0 \\"
    export DEVICE="-device virtio-net-pci,netdev=net0,mac=$MAC_ADDR \\"
  else
    export NETDEV="-device virtio-net-pci,netdev=net0 \\"
    export DEVICE="-netdev user,id=net0,hostfwd=tcp::"$VM_SSH_PORT"-:"$HOST_SSH_PORT" \\"
  fi
    
  # set graphics options based on gpu presence.
  if [[ "$GPU_ACCEL" == "false" ]]; then
    export VGA_OPT="-nographic \\"
    export PCI_GPU="\\"
  else
    export VGA_OPT="-serial stdio -parallel none \\"
    export PCI_GPU="-device vfio-pci,host=02:00.0,multifunction=on,x-vga=on \\"
  fi
}

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
    $NETDEV
    $DEVICE
    -bios /usr/share/ovmf/OVMF.fd \
    -vga virtio \
    -usbdevice tablet \
    -vnc $HOST_ADDRESS:$VNC_PORT \
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
    $NETDEV
    $DEVICE
    -bios /usr/share/ovmf/OVMF.fd \
    -vga virtio \
    -usbdevice tablet \
    -vnc $HOST_ADDRESS:$VNC_PORT \
    $@" ENTER
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
      $NETDEV
      $DEVICE
      -drive if=virtio,format=qcow2,file="$CLOUD_IMAGE_NAME"-new.img \
      -bios /usr/share/ovmf/OVMF.fd \
      -usbdevice tablet \
      -vnc $HOST_ADDRESS:$VNC_PORT \
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
      $NETDEV
      $DEVICE
      -drive if=virtio,format=qcow2,file="$CLOUD_IMAGE_NAME"-new.img \
      -drive if=virtio,format=raw,file=seed.img \
      -bios /usr/share/ovmf/OVMF.fd \
      -usbdevice tablet \
      -vnc $HOST_ADDRESS:$VNC_PORT \
      $@" ENTER
  fi
}

# create a windows vm
create_windows_vm(){
  tmux new-session -d -s "${VM_NAME}_session"
  tmux send-keys -t "${VM_NAME}_session" "sudo qemu-system-x86_64 \
    -machine accel=kvm,type=q35 \
    -cpu host,kvm="off",hv_vendor_id="null" \
    -smp sockets="$SOCKETS",cores="$PHYSICAL_CORES",threads="$THREADS" \
    -m "$MEMORY" \
    -drive id=disk0,if=virtio,cache=none,format=qcow2,file=/home/max/pxeless/virtual-machines/${VM_NAME}/$DISK_NAME \
    -drive file=/home/max/pxeless/virtual-machines/images/Windows.iso,index=1,media=cdrom \
    -drive file=/home/max/pxeless/virtual-machines/images/virtio-win-0.1.215.iso,index=2,media=cdrom \
    -boot menu=on \
    -serial none \
    -parallel none \
    -bios /usr/share/ovmf/OVMF.fd \
    -usbdevice tablet \
    -netdev bridge,br=br0,id=net0 \
    -device virtio-net-pci,netdev=net0,mac=$MAC_ADDR \
    -vnc $HOST_ADDRESS:$VNC_PORT \
    $@" ENTER
}

boot_windows_vm(){
  tmux new-session -d -s "${VM_NAME}_session"
  tmux send-keys -t "${VM_NAME}_session" "sudo qemu-system-x86_64 \
    -machine accel=kvm,type=q35 \
    -cpu host,kvm="off",hv_vendor_id="null" \
    -smp sockets="$SOCKETS",cores="$PHYSICAL_CORES",threads="$THREADS" \
    -m "$MEMORY" \
    -hda /home/max/pxeless/virtual-machines/${VM_NAME}/$DISK_NAME \
    -drive file=/home/max/pxeless/virtual-machines/images/Windows.iso,index=1,media=cdrom \
    -drive file=/home/max/pxeless/virtual-machines/images/virtio-win-0.1.215.iso,index=2,media=cdrom \
    -boot c \
    -serial stdio \
    -parallel none \
    $PCI_GPU
    -bios /usr/share/ovmf/OVMF.fd \
    -netdev bridge,br=br0,id=net0 \
    -device virtio-net-pci,netdev=net0,mac=$MAC_ADDR\
    -vnc $HOST_ADDRESS:$VNC_PORT \
    $@" ENTER
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
no_ssh_fingerprints: true
ssh:
  emit_keys_to_console: false
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
  - name: ${VM_USER}
    gecos: system acct
    groups: users, admin, docker, sudo
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: "\$6\$rounds=4096\$9VgQ5dNMNB9DhP09\$zDdZaDx43CfNVFMLMblKTsYLl0P0I0Krh3FZsUVWh2pSv.h40pFAc4wo1sGqsdF2Ayn0Ro5Eai1gWan6uF2Q80"
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
package_update: true
package_upgrade: true
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
EOF
}

create_windows(){
  export_metatdata
  select_image
  set_gpu
  create_dir
  create_virtual_disk
  create_windows_vm
  attach_to_vm_tmux
}

boot_windows(){
  export_metatdata
  select_image
  set_gpu
  create_dir
  boot_windows_vm
  attach_to_vm_tmux
}

create(){
  export_metatdata
  select_image
  set_gpu
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
  select_image
  set_gpu
  create_dir
  boot_ubuntu_cloud_vm
  #boot_vm_from_iso
  attach_to_vm_tmux
}

"$@"

