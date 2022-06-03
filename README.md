# single-gpu-passthrough

### Setup scripts

```sh
git clone https://github.com/Gnarus-G/single-gpu-passthrough.git
cd single-gpu-passthrough;
chmod +x kvmconf vbiospatch;
chmod -R +x hookscripts;
mkdir ~/.local/bin;
mv kvmconf vbiospatch ~/.local/bin/;
```

### IOMMU (AMD)

```bash
sudo vim /etc/default/grub
```
Add 'amd_iommu' like so - `GRUB_CMDLINE_LINUX_DEFAULT="... amd_iommu=on ..."`.  

```sh
sudo dmesg | grep -i -e DMAR -e IOMMU
```
To check that it worked

### Install Qemu and virt-manager
```sh
sudo pacman -S qemu libvirt edk2-ovmf virt-manager iptables-nft dnsmasq
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
sudo cp -r hookscripts/ /etc/libvirt/hooks/qemu.d
```

**NOTE:** Rename the 'amd' or 'nvidia' folder to the VM's name;
The one to use depends on your gpu.

### Hyper-V Elightenments
within the <hyperv/> tags
setting vendor_id as below helps prevent weird bugs like not being able to change the display orientation:
```conf
<vpindex state="on"/>
<synic state="on"/>
<stimer state="on"/>
<reset state="on"/>
<vendor_id state="on" value="whatever"/>
<frequencies state="on"/>
```
Hide kvm to prevent error 43:
```conf
<kvm>
  <hidden state="on"/>
</kvm>
```

### Enabling SMT Performance (for AMD Ryzen CPUs)
Withing the <cpu/> tags
```conf
<feature policy="require" name="topoext"/>
```
### Pin all cpu's for much better performance
```
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
