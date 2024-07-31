#!/bin/bash

proc() {
  # Helpful to read output when debugging
  set -x

  #load variables
  source /etc/libvirt/hooks/kvm.conf

  # Stop display manager
  systemctl stop display-manager.service
  killall gdm-x-session

  # Unbind VTconsoles
  echo 0 > /sys/class/vtconsole/vtcon0/bind

  # Unbind EFI-Framebuffer
  echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

  # Avoid a Race condition by waiting 2 seconds. This can be calibrated to be shorter or longer if required for your system
  sleep 2

  # Unbind the GPU from display driver
  virsh nodedev-detach $VIRSH_GPU_VIDEO
  virsh nodedev-detach $VIRSH_GPU_AUDIO

  # Load VFIO Kernel Module  
  modprobe vfio-pci  
}

proc 2> /etc/libvirt/hooks/qemu.d/begin_std_err.log
