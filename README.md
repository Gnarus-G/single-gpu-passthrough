# single-gpu-passthrough

### Setup scripts

```sh
git clone git@github.com:Gnarus-G/single-gpu-passthrough.git
cd single-gpu-passthrough;
chmod +x kvmconf vbiospatch;
chmod -R +x hookscripts;
mv kvmconf vbiospatch ~/.local/bin/;
```

### IOMMU (AMD)

```bash
sudo vim /etc/default/grub
```

Add 'amd_iommu' like so - `GRUB_CMDLINE_LINUX_DEFAULT="... amd_iommu=on ..."`

### Hook Manager

```bash
sudo wget 'https://raw.githubusercontent.com/PassthroughPOST/VFIO-Tools/master/libvirt_hooks/qemu' \
    -O /etc/libvirt/hooks/qemu
sudo chmod +x /etc/libvirt/hooks/qemu
```

### Place Hook scripts

```bash
sudo kvmconf
```

```bash
cp -r hookscripts/ /etc/libvirt/hooks/qemu.d
```

**NOTE:** Rename the 'amd' or 'nvidia' folder to the VM's name;

### Hyper-V Elightenments

```conf
<vpindex state="on"/>
<synic state="on"/>
<stimer state="on"/>
<reset state="on"/>
<vendor_id state="on" value="whatever_value"/>
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
