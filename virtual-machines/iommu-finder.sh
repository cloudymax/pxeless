#!/bin/bash
shopt -s nullglob
for d in /sys/kernel/iommu_groups/{0..64}/devices/*; do
    n=${d#*/iommu_groups/*}; n=${n%%/*}
    printf 'IOMMU Group %s ' "$n"
    lspci -nns "${d##*/}"
done;
