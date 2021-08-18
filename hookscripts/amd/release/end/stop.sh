#!/bin/bash

set -x

#load variables
source /etc/libvirt/hooks/kvm.conf
  
# Unload all the vfio modules
modprobe -r vfio_pci
modprobe -r vfio_iommu_type1
modprobe -r vfio

# Rebind VT consoles
echo 1 > /sys/class/vtconsole/vtcon0/bind

# Reattach the gpu
virsh nodedev-reattach $VIRSH_GPU_VIDEO
virsh nodedev-reattach $VIRSH_GPU_AUDIO

# Load all Radeon drivers

modprobe  amdgpu
modprobe  gpu_sched
modprobe  ttm
modprobe  drm_kms_helper
modprobe  i2c_algo_bit
modprobe  drm


# Restart Display Manager
systemctl start display-manager.service
