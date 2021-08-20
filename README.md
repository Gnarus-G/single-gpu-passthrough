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

```conf
<feature policy="require" name="topoext"/>
```
### References
Arch wiki: https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Setting_up_an_OVMF-based_guest_VM  
SomeOrdinaryGamer: https://www.youtube.com/watch?v=BUSrdUoedTo
