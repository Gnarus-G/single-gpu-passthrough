#!/bin/bash
proc() {
  set -x

  #load variables
  source /etc/libvirt/hooks/kvm.conf

  # Unload all the vfio modules
  modprobe -r vfio_iommu_type1
  modprobe -r vfio_pci
  modprobe -r vfio

  # Rebind VT consoles
  echo 1 > /sys/class/vtconsole/vtcon0/bind

  # Reattach the gpu
  virsh nodedev-reattach $VIRSH_GPU_VIDEO
  virsh nodedev-reattach $VIRSH_GPU_AUDIO

  # Load all Radeon drivers
  modprobe amdgpu

  # Bind EFI Framebuffer
  # echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/bind

  # Restart Display Manager
  systemctl start display-manager.service
}

proc 2> /etc/libvirt/hooks/qemu.d/end_std_err.log
