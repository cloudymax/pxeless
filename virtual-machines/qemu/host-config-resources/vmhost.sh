#!/bin/bash

set -o nounset
set -o pipefail

# kernel param docs
# https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html?highlight=amd_iommu
# pt - passthrough
export IOMMU="pt"

# Pass parameters to the AMD IOMMU driver in the system.
export AMD_IOMMU="on"

# [DMAR] Intel IOMMU driver (DMAR) options
export INTEL_IOMMU="igfx_off"

# elect preemption mode, large boot-time impact, scales with ram size
export PREEMPT="voluntary"

# The following are not included int he kernel params docs
# https://www.kernel.org/doc/html/latest/gpu/i915.html?highlight=vfio%20pci
# intel graphics driver option
export I915_ENABLE_GVT="1"

# https://www.kernel.org/doc/html/latest/driver-api/vfio-pci-device-specific-driver-acceptance.html?highlight=vfio%20pci
export VFIO_PCI_IDS="10de:1f08,10de:10f9,10de:1ada,10de:1adb"

# MSR = machine specific registers.
# https://www.kernel.org/doc/html/latest/virt/kvm/x86/msr.html?highlight=kvm%20ignore%20msrs
export KVM_IGNORE_MSRS="1"
export KVM_REPORT_IGNORED_MSRS="0"


export GRUB_CMDLINE_LINUX_DEFAULT="GRUB_CMDLINE_LINUX_DEFAULT=\"amd_iommu=$AMD_IOMMU iommu=$IOMMU kvm.ignore_msrs=$KVM_IGNORE_MSRS vfio-pci.ids=$VFIO_PCI_IDS i915.enable_gvt=$I915_ENABLE_GVT intel_iommu=$INTEL_IOMMU kvm.report_ignored_msrs=$KVM_REPORT_IGNORED_MSRS preempt=$PREEMPT\""

#echo $GRUB_CMDLINE_LINUX_DEFAULT

#sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\"/$GRUB_CMDLINE_LINUX_DEFAULT/g" /etc/default/grub