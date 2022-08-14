#!/bin/bash

set -o pipefail
set -o errexit

deps(){
    sudo apt-get -y install \
      qemu-kvm \
      bridge-utils \
      virtinst \
      ovmf \
      qemu-utils \
      cloud-image-utils
}

# credit goes to leduccc for this stanza.
# source: https://leduccc.medium.com/simple-dgpu-passthrough-on-a-dell-precision-7450-ebe65b2e648e
get_iommu_data(){
    shopt -s nullglob
    for d in /sys/kernel/iommu_groups/{0..64}/devices/*; do
        n=${d#*/iommu_groups/*}; n=${n%%/*}
        printf 'IOMMU Group %s ' "$n" 
        lspci -nns "${d##*/}"
    done;
}

# Takes a vendor name: NVIDIA/Intel/AMD etc...
# Only tested on NVIDIA hardware.
get_iommu_ids(){

    LIST=$(get_iommu_data)
    COUNT=$(echo "$LIST" |grep -c $1 )
    DEVICE_IDS=""

    for ((i=1;i<=$COUNT;i++)); do

        ID=$(echo "$LIST" |grep $1 |awk '{print $(NF-2)}' |head -$i |tail -1 |sed 's/[][]//g')
        
        # Regex Explanation:
        # 1. search the data for lines onctaining VENDOR_NAME
        #    echo "$LIST" |grep $1
        # 2. find the second-to-last field of the line
        #    awk '{print $(NF-2)}'
        # 3. Show only the current item in the itteration
        #    head -$i |tail -1
        # 4. cut off bracktes from the resulting value
        #    sed 's/[][]//g'

        if [[ "$i" -eq 1 ]]; then
            DEVICE_IDS="$ID"
        else
            DEVICE_IDS="$DEVICE_IDS,$ID"
        fi

    done

    echo $DEVICE_IDS
}

# create config files in local dir then move into place
make_configs(){

sudo mkdir "/etc/initram-fs"

cat > $(pwd)/modules <<EOF    
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF

cat > $(pwd)/local.conf <<EOF    
options vfio-pci ids=$VFIO_PCI_IDS
options vfio-pci disable_vga=1
EOF
    
sudo mv $(pwd)/modules /etc/initram-fs/modules
sudo mv $(pwd)/local.conf /etc/modprobe.d/local.conf
}

# write the new grub line
write_grub(){
    if [ ! -f "/etc/default/grub.bak" ]; then
        echo "No grub backups found, making one now..."
        sudo cp /etc/default/grub /etc/default/grub.bak
    fi
    sleep 1
    sudo sed "s/.*GRUB_CMDLINE_LINUX_DEFAULT=.*/${GRUB_CMDLINE_LINUX_DEFAULT}/" /etc/default/grub

}

# reset grub to a blank defaults line
reset_grub(){
    sudo cp /etc/default/grub.bak /etc/default/grub
}

# generate all our names, strings, and grab the IDs we need
generate_kernel_params(){
export IOMMU="pt"
export AMD_IOMMU="on"
export I915_ENABLE_GVT="1"
export INTEL_IOMMU="on"
export PREEMPT="voluntary"
export VFIO_PCI_IDS=$(get_iommu_ids "$1")
export KVM_IGNORE_MSRS="1"
export KVM_REPORT_IGNORED_MSRS="0"
export RD_DRIVER_PRE="vfio-pci"
export VIDEO_FLAG="efifb:off"
export GRUB_CMDLINE_LINUX_DEFAULT="GRUB_CMDLINE_LINUX_DEFAULT=\"iommu="$IOMMU" \
vfio-pci.ids="$VFIO_PCI_IDS" \
amd_iommu="$AMD_IOMMU" \
i915.enable_gvt="$I915_ENABLE_GVT" \
intel_iommu="$INTEL_IOMMU" \
rd.driver.pre="$RD_DRIVER_PRE" \
video="$VIDEO_FLAG" \
kvm.ignore_msrs="$KVM_IGNORE_MSRS" \
kvm.report_ignored_msrs="$KVM_REPORT_IGNORED_MSRS" \
preempt="$PREEMPT"\""
}

# run the full script
full_run(){

    if [ -z "$1" ]; then
      echo "Missing required argument for get_iommu_ids <VENDOR NAME>, use a vendor name like 'NVIDIA', 'AMD', or 'Intel'."
      exit
    fi
    
    deps
    generate_kernel_params $1
    write_grub
    make_configs
    sudo update-grub
    sudo update-initramfs -k all -u

    echo "New Grub Config:"
    echo "$(cat /etc/default/grub |grep GRUB_CMDLINE_LINUX_DEFAULT)"
    echo " "
    echo "/etc/initram-fs/modules:"
    echo "$(cat /etc/initram-fs/modules)"
    echo " "
    echo "/etc/modprobe.d/local.conf:"
    echo "$(cat /etc/modprobe.d/local.conf)"
}

# reset our changes by deleting the configs we made and resetting grub
reset(){
    echo "Restoring backup of /etc/default/grub..."
    sudo cp /etc/default/grub.bak /etc/default/grub
    cat /etc/default/grub |grep GRUB_CMDLINE_LINUX_DEFAULT
    
    echo "Removing /etc/modprobe.d/local.conf..."
    sudo rm /etc/modprobe.d/local.conf 
    
    echo "Removing /etc/initram-fs/modules..."  
    sudo rm /etc/initram-fs/modules
}


"$@"