# single-gpu-passthrough

### Setup scripts

```sh
git clone https://github.com/Gnarus-G/single-gpu-passthrough.git
cd single-gpu-passthrough;
chmod +x kvmconf;
chmod -R +x hookscripts;
mkdir ~/.local/bin;
mv kvmconf ~/.local/bin/;
```

### IOMMU (AMD)

```bash
sudo vim /etc/default/grub
```

Add 'amd_iommu' like so - `GRUB_CMDLINE_LINUX_DEFAULT="... amd_iommu=on iommu=pt iommu=1..."`.

```sh
sudo dmesg | grep -i -e DMAR -e IOMMU
```

To check that it worked

### VFIO

```bash
sudo nvim /etc/dracut.conf.d/local.conf
```

write therein: add_drivers+=" vfio vfio_iommu_type1 vfio-pci vfio-virqfd "

```bash
sudo dracut -f --kver `uname -r`
```

### Install Qemu and virt-manager

```sh
sudo pacman -S qemu-desktop libvirt edk2-ovmf virt-manager iptables-nft dnsmasq
```

### Enable and start necessary services

```sh
sudo systemctl enable libvirtd.service --now
sudo systemctl enable virtlogd.socket --now
```

Enable default libvirt network

```sh
sudo virsh net-autostart default
sudo virsh net-start default
```

### Add user to groups

```bash
sudo usermod -aG libvirt,kvm,input $USER
```

### Hook Manager

```bash
sudo mkdir /etc/libvirt/hooks
sudo wget 'https://raw.githubusercontent.com/PassthroughPOST/VFIO-Tools/master/libvirt_hooks/qemu' \
    -O /etc/libvirt/hooks/qemu
sudo chmod +x /etc/libvirt/hooks/qemu
```

### Place Hook scripts

Assuming the hookscripts directory is in $(pwd)

```bash
sudo kvmconf
sudo cp -r hookscripts/* /etc/libvirt/hooks/qemu.d
sudo touch /etc/libvirt/hooks/qemu.d/begin_std_err.log
sudo touch /etc/libvirt/hooks/qemu.d/end_std_err.log
```

**NOTE:** Rename the 'amd' or 'nvidia' folder to the VM's name;
The one to use depends on your gpu.

### Hyper-V Elightenments

within the <hyperv/> tags, under <features/>
setting vendor_id as below helps prevent weird bugs like not being able to change the display orientation:

```xml
<vpindex state="on"/>
<synic state="on"/>
<stimer state="on"/>
<reset state="on"/>
<vendor_id state="on" value="whatever"/>
<frequencies state="on"/>
```

Hide kvm to prevent error 43:
under <features/>

```xml
<kvm>
  <hidden state="on"/>
</kvm>
```

### Enabling SMT Performance (for AMD Ryzen CPUs)

Withing the <cpu/> tags

```xml
<feature policy="require" name="topoext"/>
```

### Pin all cpu's for much better performance

```xml
<cputune>
    <vcpupin vcpu="0" cpuset="0"/>
    <vcpupin vcpu="1" cpuset="1"/>
    <vcpupin vcpu="2" cpuset="2"/>
    <vcpupin vcpu="3" cpuset="3"/>
    <vcpupin vcpu="4" cpuset="4"/>
    <vcpupin vcpu="5" cpuset="5"/>
    <vcpupin vcpu="6" cpuset="6"/>
    <vcpupin vcpu="7" cpuset="7"/>
    <vcpupin vcpu="8" cpuset="8"/>
    <vcpupin vcpu="9" cpuset="9"/>
    <vcpupin vcpu="10" cpuset="10"/>
    <vcpupin vcpu="11" cpuset="11"/>
    <vcpupin vcpu="12" cpuset="12"/>
    <vcpupin vcpu="13" cpuset="13"/>
    <vcpupin vcpu="14" cpuset="14"/>
    <vcpupin vcpu="15" cpuset="15"/>
</cputune>
```

### References

Arch wiki: https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Setting_up_an_OVMF-based_guest_VM  
SomeOrdinaryGamer: https://www.youtube.com/watch?v=BUSrdUoedTo  
Reddit:

- https://www.reddit.com/r/VFIO/comments/t5h0r4/single_gpusingle_nvme_passhthrough_endeavouros/
- https://www.reddit.com/r/VFIO/comments/rp0vbi/single_gpu_guides_need_to_stop_putting_forbidden/

Other Guides:

- https://github.com/QaidVoid/Complete-Single-GPU-Passthrough
- https://youtu.be/eTWf5D092VY
