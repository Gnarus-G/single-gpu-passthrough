#!/bin/bash
# Helpful to read output when debugging
set -x

#load variables
source /etc/libvirt/hooks/kvm.conf

# Stop your display manager. If youre on kde it ll be sddm.service. Gnome users should use killall gdm-x-session instead
systemctl stop display-manager.service
killall gdm-x-session
pulse_pid=$(pgrep -u gnarus pulseaudio)
pipewire_pid=$(pgrep -u gnarus pipewire-media)
kill $pulse_pid
kill $pipewire_pid

# Unbind VTconsoles
echo 0 > /sys/class/vtconsole/vtcon0/bind

# Avoid a race condition by waiting a couple of seconds. This can be calibrated to be shorter or longer if required for your system
sleep 2

# Unload all Radeon drivers

modprobe -r amdgpu
modprobe -r gpu_sched
modprobe -r ttm
modprobe -r drm_kms_helper
modprobe -r i2c_algo_bit
modprobe -r drm

# Unbind the GPU from display driver
virsh nodedev-detach $VIRSH_GPU_VIDEO
virsh nodedev-detach $VIRSH_GPU_AUDIO

# Load VFIO kernel module
modprobe vfio
modprobe vfio_pci
modprobe vfio_iommu_type1
