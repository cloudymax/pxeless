#!/bin/bash

log() {
    echo >&2 -e "[$(date +"%Y-%m-%d %H:%M:%S")] ${1-}"
}

# VM metadata
export_metatdata(){
  export IMAGE_TYPE="img" #img or iso
  export VM_NAME="test"
  export VM_USER="${VM_NAME}admin"
  export GITHUB_USER="cloudymax"
  export USER="max"
  export DISK_NAME="boot.img"
  export DISK_SIZE="16G"
  export MEMORY="4G"
  export SOCKETS="1"
  export PHYSICAL_CORES="1"
  export THREADS="2"
  export VM_KEY=""
  export VM_KEY_FILE="$VM_USER"
  export UUID="none"
  export MAC_ADDR=$(printf 'AC:AB:13:12:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)))
  export PASSWD=$(mkpasswd -m sha-512 --rounds=4096 "password" -s "saltsaltlettuce")
  export GPU_ACCEL="false"
}

# set network options
set_network(){
  log "📞 Setting networking options."
  export STATIC_IP="false"
  export HOST_ADDRESS="192.168.50.100"
  export HOST_SSH_PORT="22"
  export VM_SSH_PORT="1234"
  export VNC_PORT="0"

  if [[ "$STATIC_IP" == "true" ]]; then
    log " - Static IP selected."
    export NETDEV="-netdev bridge,br=br0,id=net0 \\"
    export DEVICE="-device virtio-net-pci,netdev=net0,mac=$MAC_ADDR \\"
  else
    log " - Port Forwarding selected."
    export NETDEV="-device virtio-net-pci,netdev=net0 \\"
    export DEVICE="-netdev user,id=net0,hostfwd=tcp::"${VM_SSH_PORT}"-:"${HOST_SSH_PORT}" \\"
  fi
}

# set gpu acceleration options
set_gpu(){
  log "🖥 Set graphics options based on gpu presence."
  if [[ "$GPU_ACCEL" == "false" ]]; then
    export VGA_OPT="-nographic \\"
    export PCI_GPU="\\"
    log " - GPU not attached"
  else
    export VGA_OPT="-serial stdio -parallel none \\"
    export PCI_GPU="-device vfio-pci,host=02:00.0,multifunction=on,x-vga=on \\"
    log " - GPU attached"
  fi
}

# select a cloud image to download
select_image(){
  log "🌧 Selecting a cloud image to download"
  export ISO_FILE="/home/${USER}/pxeless/virtual-machines/qemu/debian-live-11.3.0-amd64-cinnamon.iso"
  export UBUNTU_CODENAME="jammy"
  export CLOUD_IMAGE_NAME="${UBUNTU_CODENAME}-server-cloudimg-amd64"
  export CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current"
  log " - Done!"
}

# create a directory to hold the VM assets
create_dir(){
  log "📂 Creating VM directory."
  mkdir -p "$VM_NAME"
  cd "$VM_NAME"
  export UUID=$(uuidgen)
  log " - Done!"
}

# download a cloud image as .img
download_cloud_image(){

  log "⬇️ Downloading cloud image..."
  if [ -f "$CLOUD_IMAGE_NAME.img" ]; then
    log "- ⛔️ image already present"
  else
    tmux kill-session -t "download" || true
    tmux new-session -d -s "download"
    tmux send-keys -t "download" "wget -c -O "$CLOUD_IMAGE_NAME".img \
    "$CLOUD_IMAGE_URL"/"$CLOUD_IMAGE_NAME".img" ENTER
    monitor_download
  fi 
}

monitor_download(){
  DONE=$(tmux capture-pane -t "download" -p |tac |grep -ai -c "saved" )
  while [[ "$DONE" != "1" ]]; do
      printf '\r%s' "  " "$(tmux capture-pane -t "download" -p |tac | grep -v "^$" | head -1)"
      sleep .1 
      DONE=$(tmux capture-pane -t "download" -p |tac |grep -ai -c "saved" )
  done
  printf "\n"
  log " - Done!"
}

# Create and expanded image
expand_cloud_image(){
  log "📈 Expanding image"
  qemu-img create -b ${CLOUD_IMAGE_NAME}.img -f qcow2 \
  	-F qcow2 ${CLOUD_IMAGE_NAME}-new.img \
  	"$DISK_SIZE" 1> /dev/null
  log " - Done!"
}

# convert the .img to qcow2 to use as base layer
img_to_qcow(){
  log "🐄 Converting img to qcow2"
  qemu-img convert -f raw \
    -O qcow2 "$CLOUD_IMAGE_NAME"_original.img \
    "$CLOUD_IMAGE_NAME".qcow2
  log " - Done!"
}

# create the next layer on the image
create_qcow_image(){
  log "🐄 Creating qcow2 image"
  qemu-img create -f qcow2 \
    -F qcow2 \
    -o backing_file="$CLOUD_IMAGE_NAME"_base.qcow2 \
    "$VM_NAME".qcow2
  log " - Done!"
}

# create a disk
create_virtual_disk(){
  log "💾 Creating virtual disk"
  qemu-img create -f qcow2 hdd.img $DISK_SIZE &>/dev/null
  log " - Done!"
}

# Generate an ISO image
generate_seed_iso(){
  log "🌱 Generating seed iso containing user-data"
  cloud-localds seed.img user-data
  log " - Done!"
}

tmux_to_vm(){
  export_metatdata
  tmux attach-session -t "${VM_NAME}_session"
}

# tail out a remote tmux window
tmux_stream(){
  STAGE=1
  STAGE_DONE=$(tmux capture-pane -t "${VM_NAME}_session" -p |grep -ai -c "${VM_NAME} Login:" )
  while [[ "$STAGE" != "2" ]]; do
      STAGE_DONE=$(tmux capture-pane -t "${VM_NAME}_session" -p |grep -ai -c "${VM_NAME} Login:" )
      printf '\r'"$(tmux capture-pane -t "${VM_NAME}_session" -p |tail -1)"
      printf '\r'"$(tmux capture-pane -t "${VM_NAME}_session" -p |tail -2 |head -1)"
      if [[ $STAGE_DONE == "1" ]]; then
        let "++$STAGE"
      fi
  done
  printf "\n"
  log " - Done!"
}

ssh_to_vm(){
  export_metatdata
  set_network
    # clear known_hosts and connect to the ip
    if [[ "$STATIC_IP" == "true" ]]; then
      if [ -f "/home/${USER}/.ssh/known_hosts" ]; then
        ssh-keygen -f "/home/${USER}/.ssh/known_hosts" -R "[${HOST_ADDRESS}]"
      fi

      ssh -o "StrictHostKeyChecking no" \
        -X \
        -i "$VM_NAME"/"$VM_USER" \
        "$VM_USER"@"$HOST_ADDRESS"

    else
      # clear known_hosts and connect to the port on the host
      if [ -f "/home/${USER}/.ssh/known_hosts" ]; then
        ssh-keygen -f "/home/${USER}/.ssh/known_hosts" -R "[${HOST_ADDRESS}]:${VM_SSH_PORT}"
      fi
      
      ssh -o "StrictHostKeyChecking no" \
        -X \
        -i "$VM_NAME"/"$VM_USER" \
        -p"${VM_SSH_PORT}" "${VM_USER}"@"${HOST_ADDRESS}" 
    fi
}

vnc_tunnel(){
  export_metatdata
  ssh -o "StrictHostKeyChecking no" \
    -N -L 5001:"$HOST_ADDRESS":5900 \
    -i "/home/max/pxeless/virtual-machines/qemu/testvm/vmadmin" \
    -p "$VM_SSH_PORT" "$VM_USER"@"$HOST_ADDRESS"
}

# luanch the VM to install from ISO to Disk
create_vm_from_iso(){
  log "💿 Creating VM from iso file"
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
    tmux_stream
}

boot_vm_from_iso(){
  log "🥾 Booting VM"
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
    tmux_stream
}

# start the cloud-init backed VM
create_ubuntu_cloud_vm(){
  log "🌥 Creating cloud-image based VM"
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
      tmux_stream
  fi
}

boot_ubuntu_cloud_vm(){
  log "🥾 Booting VM"
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
      tmux_stream
  fi
}

# create a windows vm
create_windows_vm(){
  log "📎 Looks like you're creating a Windows VM"
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
    $NETDEV
    $DEVICE
    -vnc $HOST_ADDRESS:$VNC_PORT \
    $@" ENTER
}

boot_windows_vm(){
  log "🥾 Booting VM"
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
    $NETDEV
    $DEVICE
    -vnc $HOST_ADDRESS:$VNC_PORT \
    $@" ENTER
}

create_user_data(){
  log "👤 Generating user data"
  bash /home/max/pxeless/virtual-machines/user-data.sh --update --upgrade \
    --password "${PASSWD}" \
    --github-username "$GITHUB_USER" \
    --username "$USER" \
    --vm-name "$VM_NAME"
}

create_windows(){
  export_metatdata
  set_network
  select_image
  set_gpu
  create_dir
  create_virtual_disk
  create_windows_vm
  tmux_to_vm
}

boot_windows(){
  export_metatdata
  set_network
  select_image
  set_gpu
  create_dir
  boot_windows_vm
  tmux_to_vm
}

create(){
  export_metatdata
  set_network
  select_image
  set_gpu
  create_dir
  download_cloud_image
  expand_cloud_image
  create_user_data
  generate_seed_iso
  create_virtual_disk
  #create_vm_from_iso
  create_ubuntu_cloud_vm
  #ssh_to_vm
}

boot(){
  export_metatdata
  set_network
  select_image
  set_gpu
  create_dir
  boot_ubuntu_cloud_vm
  #boot_vm_from_iso
  tmux_to_vm
}

"$@"

