#!/bin/bash

export GRUB_CMDLINE_LINUX_DEFAULT="amd_iommu=on iommu=pt kvm.ignore_msrs=1 vfio-pci.ids=02:00.0,02:00.1 i915.enable_gvt=1 intel_iommu=igfx_off kvm.report_ignored_msrs=0"

