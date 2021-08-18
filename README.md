# single-gpu-passthrough

### Use scripts

```sh
git clone git@github.com:Gnarus-G/single-gpu-passthrough.git
cd single-gpu-passthrough;
chmod +x kvmconf vbiospatch;
chmod -R +x hookscripts;
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
cp -r hookscripts/ /etc/libvirt/hooks/qemu.d
```

### Hyper-V Elightenments

```conf
<vpindex state="on"/>
<synic state="on"/>
<stimer state="on"/>
<reset state="on"/>
<vendor_id state="on" value="whatever_value"/>
<frequencies state="on"/>
<kvm>
  <hidden state="on"/>
</kvm>
```

### Enabling SMT Performance (for AMD Ryzen CPUs)

```conf
<feature policy="require" name="topoext"/>
```
