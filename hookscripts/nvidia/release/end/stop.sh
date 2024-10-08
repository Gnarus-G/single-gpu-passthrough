#!/bin/bash

proc() {
  set -x

  #load variables
  source /etc/libvirt/hooks/kvm.conf
    
  # Re-Bind GPU to Nvidia Driver
  virsh nodedev-reattach $VIRSH_GPU_VIDEO
  virsh nodedev-reattach $VIRSH_GPU_AUDIO

  # Reload nvidia modules
  modprobe nvidia
  modprobe nvidia_modeset
  modprobe nvidia_uvm
  modprobe nvidia_drm

  # Rebind VT consoles
  echo 1 > /sys/class/vtconsole/vtcon0/bind
  # Some machines might have more than 1 virtual console. Add a line for each corresponding VTConsole
  #echo 1 > /sys/class/vtconsole/vtcon1/bind

  nvidia-xconfig --query-gpu-info > /dev/null 2>&1
  echo "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/bind

  # Restart Display Manager
  systemctl start display-manager.service
}

proc 2> /etc/libvirt/hooks/qemu.d/end_std_err.log
