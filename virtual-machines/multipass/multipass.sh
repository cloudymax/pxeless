#!/bin/bash

set -o nounset
set -o pipefail

#program verbosity
export VERBOSITY="-vvvvv"
export DEBUG="true"
export SQUASH="false"

# Virtual Machine Configuration
export VM_NAME="virtualbradley"
export VM_IMAGE="jammy"
export VM_CPUS="2"
export VM_DISK="20G"
export VM_MEM="4G"
export VM_IP="none"
export VM_USER="max"
export VM_KEY=""
export VM_IP=""
export SSH_PORT="22"

# temporary files
export VM_INIT="cloud-init.yaml"
export VM_KEY_FILE="$(pwd)$VM_USER"

create_ssh_key(){
# create a ssh key for the user and save as a file w/ prompt
    ssh-keygen -C "$VM_USER" \
        -f "$VM_KEY_FILE" \
        -N '' \
        -t rsa
}

push_ssh_key(){
    scp -i $VM_KEY_FILE $VM_KEY_FILE $VM_USER@$REMOTE_HOST:~/.ssh/authorized_keys
}

load_ssh_key(){
# return the absolute path of the key file
    VM_KEY_FILE=$(find "$(cd ..; pwd)" -wholename $(pwd)$VM_USER)
    VM_KEY=$(cat "$VM_KEY_FILE".pub)
}

create_cloud_init(){
# write a cloud-init file that provisions the base VM/container etc..
load_ssh_key
    cat << EOF > ${VM_INIT}
#cloud-config
groups:
  - docker
users:
  - default
  - name: ${VM_USER}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    groups: docker, admin, sudo, users
    no_ssh_fingerprints: true
    ssh-authorized-keys:
      - ${VM_KEY}
packages:
  - sl
  - docker.io
runcmd:
  - [ sed , -i , "s/#Port 22/Port ${SSH_PORT}/g" , /etc/ssh/sshd_config ]
  - [ sed , -i , "s/#PermitRootLogin prohibit-password/PermitRootLogin no/g" , /etc/ssh/sshd_config ]
EOF
}

clear_multipass() {
# delete hanging vms
    multipass stop "$VM_NAME"
    multipass delete "$VM_NAME"
    multipass purge
    # sudo snap restart multipass
    sleep 2
    #ssh-keygen -R $VM_IP
}

create_vm(){
# provision the base VM in a new tmux session
tmux new-session -d -s "${VM_NAME}_session"
tmux send-keys -t "${VM_NAME}_session" "multipass launch --name $VM_NAME \
--cpus $VM_CPUS \
--disk $VM_DISK \
--mem $VM_MEM \
$VM_IMAGE \
--cloud-init $VM_INIT \
--timeout 300 \
$VERBOSITY" ENTER

#tmux attach-session -t "${VM_NAME}_session"
}

set_vm_ip(){
# grab the new VM's IP

  IP_READY=0
  START=$(date +%s)
  NOW=0
  END=0
  DURATION=0

  while [ "${IP_READY}" == "0" ]
  do

    VM_IP=$(multipass list --format yaml \
      |grep -A 4 $VM_NAME \
      |grep -A 1 ipv4 \
      |tail -1 \
      |awk '{print $2}')
    
    if [[ $VM_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      IP_READY=1
      END=$(date +%s)
    else
      NOW=$(date +%s)
      DURATION=$(($NOW - $START))
      echo "waiting for VM's ip-address to become available..." 
      echo "Duration: ${DURATION}"
      tmux_screenshot
      sleep 1
    fi
  done

  DURATION=$(($END - $START))
  echo "VM Ready at ${VM_IP}. Ran in ${DURATION}"
  #tmux kill-session -t "${VM_NAME}_session"
}

tmux_screenshot(){
  SCREEN=$(tmux capture-pane -t "${VM_NAME}_session" -p)
  echo "$SCREEN" |tail -1
}

monitor_progress(){
  list_of_vms=$(multipass list --format yaml)

  # gross regex to get this out of yaml in bash
  # this needs to go to python badly
  # 1. list the multipass instances out as a yaml file
  # 2. search via grep for the vm name, 
  # use the -3 and tail optiion to show the line underneath the ipv4 tag
  # 3. remove the leading spaces with sed
  # 4. remove the - symbol with sed

  ip=$(multipass list --format yaml \
        |grep -3 vsphere \
        |tail -1 \
        | sed 's/ //g'\
        | sed 's/-//g')
}

ssh_to_vm(){
# open a ssh connections into the VM
    VM_IP=$(multipass list |grep "${VM_NAME}" |awk '{print $3}')
    load_ssh_key

    ssh -i $VM_KEY_FILE \
        $VM_USER@$VM_IP \
        -o StrictHostKeyChecking=no \
        -p $SSH_PORT \
        -t \
        /bin/bash
}

main(){
# main program
    create_ssh_key
    create_cloud_init
    clear_multipass
    create_vm
    set_vm_ip
    ssh_to_vm
}

"$@"
