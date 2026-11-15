# Single-GPU passthrough on Arch Linux

Run a QEMU/KVM guest with the same AMD or NVIDIA GPU that drives the Arch host. Starting the configured VM ends the host graphical session; shutting the guest down restarts the host display manager.

This guide uses current libvirt features instead of a third-party hook manager:

- `managed='yes'` PCI hostdevs let libvirt detach and reattach the GPU and any optional functions.
- A native `/etc/libvirt/hooks/qemu.d/` hook stops and restarts the display manager.
- OVMF firmware auto-selection avoids manual firmware and NVRAM paths.

> **Warning:** Starting the configured VM ends the host graphical session and disconnects its display. Save your work, keep an actual SSH or VT login available for recovery, and start the VM from outside that graphical session. These steps are hardware-specific; read the IOMMU and XML sections before starting a VM.

## Scope and prerequisites

- Arch Linux with GRUB and the monolithic `libvirtd` service. Adapt the kernel-command-line and daemon-restart commands if you use another bootloader or modular libvirt daemons.
- Virtualization and IOMMU enabled in the host firmware: SVM and AMD-Vi/IOMMU on AMD, or VT-x and VT-d on Intel. Firmware menu names vary.
- A GPU whose IOMMU group is suitable for passthrough.
- A guest installation ISO. For Windows 11, install `swtpm` if the guest needs an emulated TPM 2.0 device.

Do **not** bind the host's only display GPU to `vfio-pci` at boot. The runtime `managed='yes'` flow below leaves the GPU available to the host until the VM starts. Early VFIO binding is a different setup for a secondary GPU or a headless host.

## 1. Identify the GPU and its IOMMU group

List PCI addresses, vendor/device IDs, and bound drivers:

```bash
lspci -Dnnk
```

Find the GPU's `VGA compatible controller` or `3D controller` function and the audio function on the same PCI device. This guide uses these **examples only**:

```text
0000:01:00.0  GPU
0000:01:00.1  GPU HDMI/DisplayPort audio
```

Replace every example address with your own. Do not pass through the separate motherboard audio controller.

List IOMMU groups with:

```bash
shopt -s nullglob
for group in /sys/kernel/iommu_groups/*; do
  printf 'IOMMU group %s:\n' "${group##*/}"
  for device in "$group"/devices/*; do
    lspci -nns "${device##*/}"
  done
done
```

The GPU functions must be in a group that can be isolated. Assign all eligible functions from that group to the same guest; do not assign a PCI root port. If unrelated host devices share the group, fix the hardware/slot topology if possible. Do not use `pcie_acs_override` as a routine fix: it does not create real hardware isolation.

## 2. Enable and verify IOMMU

On Intel, add `intel_iommu=on` to the kernel command line. Current AMD systems normally enable AMD-Vi automatically when it is exposed by the firmware; do not add the old `amd_iommu=on` or `iommu=1` settings.

For GRUB, edit `/etc/default/grub`. An Intel example is:

```bash
GRUB_CMDLINE_LINUX_DEFAULT="... intel_iommu=on"
```

`iommu=pt` is optional performance tuning on either vendor, not a passthrough requirement. It selects passthrough mode for DMA translation by default and therefore changes the isolation trade-off. Leave it out unless you deliberately want that behavior.

Regenerate the GRUB configuration and reboot:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
sudo reboot
```

After rebooting, check the kernel log and confirm that the group-listing command above produces groups:

```bash
sudo journalctl -k -b | grep -Ei 'DMAR|IOMMU|AMD-Vi'
```

## 3. Install QEMU and libvirt

```bash
sudo pacman -S --needed qemu-desktop libvirt virt-manager edk2-ovmf dnsmasq nftables
```

`qemu-desktop` is sufficient for an x86-64 desktop guest; `qemu-full` is only needed for QEMU's additional emulators and tools. Current Arch uses the `iptables` package when the iptables backend is wanted; there is no separate `iptables-nft` package to install. Libvirt uses nftables by default when available.

Enable libvirt and allow your user to manage the system instance:

```bash
sudo systemctl enable --now libvirtd.service
sudo usermod -aG libvirt "$USER"
```

Log out and back in so the group change takes effect. `libvirtd.service` pulls in `virtlogd.socket`; enabling it separately is unnecessary. The `input` group is not needed for GPU passthrough and grants broad access to input devices, so do not add it here.

Check and enable the default NAT network:

```bash
sudo virsh net-list --all
sudo virsh net-autostart default
```

If it is inactive, start it:

```bash
sudo virsh net-start default
```

Libvirt starts its own `dnsmasq` instance for this network; do not enable the system `dnsmasq.service`.

## 4. Create the guest

In virt-manager, connect to **QEMU/KVM** system (`qemu:///system`) and select **Customize configuration before install**.

- Use a **Q35** machine type.
- Select **UEFI x86_64** firmware in the Overview page. Modern libvirt can auto-select the installed OVMF firmware and create the guest NVRAM store; do not copy `OVMF_VARS` manually or use obsolete `/usr/share/ovmf/` paths.
- Finish a normal OS installation with virtual storage, network, and display devices before adding the physical GPU.
- For Windows 11, add an emulated TPM 2.0 device when required. Install `swtpm` first:

  ```bash
  sudo pacman -S --needed swtpm
  ```

For a Windows guest, VirtIO storage and network devices avoid emulated-device overhead, but require the guest VirtIO drivers during installation. Add them only when you have the driver ISO available.

## 5. Add the physical GPU

Shut the guest down completely. In virt-manager, use **Add Hardware → PCI Host Device** to add the GPU video function. Video-only passthrough is the simplest baseline; keep emulated audio initially. Optionally add the GPU's HDMI/DisplayPort audio function later if the guest needs it.

Inspect the resulting XML:

```bash
virsh --connect qemu:///system edit win11
```

Replace `win11` with your domain name. Every GPU hostdev entry must use `managed='yes'`; this is what allows the simplified hook to leave all PCI binding and restoration to libvirt. The video entry is required and the audio entry is optional. The addresses below are examples:

```xml
<hostdev mode="subsystem" type="pci" managed="yes">
  <source>
    <address domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
  </source>
</hostdev>
<hostdev mode="subsystem" type="pci" managed="yes">
  <source>
    <address domain="0x0000" bus="0x01" slot="0x00" function="0x1"/>
  </source>
</hostdev>
```

Do not combine this configuration with old hook commands such as `virsh nodedev-detach` or `virsh nodedev-reattach`. Libvirt already performs those operations for managed hostdevs. Also avoid manually detaching the GPU while a guest is using it.

When the optional audio function is detached, PipeWire/WirePlumber should respond to the sound-card removal and release its ALSA handles. If detachment hangs, diagnose which process still holds the GPU's `/dev/snd/` nodes before stopping that specific user service. Do not indiscriminately kill audio processes, and do not pass the motherboard audio controller by mistake.

Connect a physical display to the passed-through GPU and install the normal guest GPU driver. A virtual display adapter can remain temporarily for installation or troubleshooting, but it is not required for PCI passthrough.

## 6. Install the native libvirt hook

The hook in `hookscripts/single-gpu` handles only the configured VM:

- `prepare begin`: stop the display manager **before** libvirt detaches managed PCI devices.
- `release end`: start the display manager **after** libvirt reattaches them.
- With valid configuration, every other VM and hook event is ignored. Missing or invalid shared configuration fails closed and can also block unrelated VM starts.

It does not unload GPU drivers, indiscriminately kill PulseAudio/PipeWire, manipulate VT consoles or EFI framebuffers, or unload global VFIO modules. Libvirt handles PCI binding; any additional session or audio cleanup must be based on the host's actual device users.

### Migrate an existing installation first

Do not run the old PassthroughPOST helper and this native hook together. Migrate any nested `qemu.d/VM/prepare/begin` and `qemu.d/VM/release/end` scripts before installing or restarting anything. If the old helper is used only by this setup, disabling its executable bit prevents it from running without deleting it:

```bash
sudo chmod -x /etc/libvirt/hooks/qemu
```

Do not disable it if other VMs still depend on it; migrate those VMs first. The old nested directory layout belonged to that helper. Native libvirt uses executable files directly inside `qemu.d`, such as the `50-single-gpu` file installed below.

### Install and configure

Install the example configuration and hook:

```bash
sudo install -Dm644 single-gpu.conf /etc/libvirt/hooks/single-gpu.conf
sudo install -Dm755 hookscripts/single-gpu /etc/libvirt/hooks/qemu.d/50-single-gpu
sudoedit /etc/libvirt/hooks/single-gpu.conf
```

Set:

```bash
VM_NAME="win11"
DISPLAY_MANAGER="display-manager.service"
GPU_PCI_ADDRESS="0000:01:00.0"
GPU_READY_TIMEOUT=10
REQUIRED_UNMOUNTED_DISKS=()
```

`GPU_PCI_ADDRESS` enables a bounded wait for that GPU's own DRM device after libvirt reattaches it. On timeout, the hook still tries to restart the display manager and returns an error so libvirt logs the readiness failure. Set it to an empty string to skip the wait.

For a guest that boots an entire physical disk, add its stable `/dev/disk/by-id/` path to `REQUIRED_UNMOUNTED_DISKS`. The hook then rejects startup **before stopping the display manager** if any partition of that disk is mounted on the host. For example:

```bash
REQUIRED_UNMOUNTED_DISKS=("/dev/disk/by-id/replace-with-your-disk-id")
```

Unmount all host partitions of that disk before every launch. Never let the host and guest write to the same mounted filesystem concurrently.

Use the exact domain name from `virsh list --all`. Check the display-manager alias with:

```bash
systemctl status display-manager.service
```

The alias works with display managers that provide it, including common GDM and SDDM installations. If your Wayland compositor is started directly, or your display manager has no alias, replace the configured unit or adapt the hook to the service that actually owns your graphical session. Stopping an unrelated service will not release the GPU reliably.

Restart libvirt after adding a new hook so it detects the executable:

```bash
sudo systemctl restart libvirtd.service
```

With modular libvirt daemons, restart `virtqemud.service` instead. No `/etc/libvirt/hooks/qemu` wrapper is needed with libvirt 6.5.0 or newer.

## 7. Start and stop the VM

Save host work and start the VM from SSH or another VT:

```bash
virsh --connect qemu:///system start win11
```

The host display should turn off and the guest should appear on the monitor attached to the passed-through GPU. Shut down the guest normally to reattach the GPU and restart the host display manager.

Libvirt normally invokes `release end` even when preparation or QEMU launch fails, allowing this hook to restart the display manager after the managed devices are restored. This is not guaranteed if libvirtd is killed, the host crashes, or power is lost. In those cases, use SSH or another VT and run `sudo systemctl start display-manager.service` after confirming that QEMU is no longer using the GPU.

Avoid `virsh destroy` except as a forced power-off; it can lose guest data. Do not manually rebind the GPU while QEMU is still running.

## CPU and guest compatibility settings

### CPU topology and pinning

Use `host-passthrough` for a non-migrating performance guest and configure guest topology to match its vCPU count. CPU pinning is optional and host-specific; do not copy a fixed map that assigns every host CPU.

Inspect the host topology with:

```bash
lscpu -e=CPU,CORE,SOCKET,NODE
```

If pinning helps a measured workload, map guest vCPUs to suitable physical cores and their SMT siblings, and leave capacity for the host when needed. Emulator and I/O thread placement also matters. There is no universally correct pin map.

### Hyper-V and KVM hiding

Keep virt-manager's normal Hyper-V defaults for Windows unless you have a specific compatibility problem. The old claims that `vendor_id` fixes display orientation and that every guest needs hidden KVM are not current baseline guidance.

NVIDIA's R465 driver branch removed the old GeForce VM-detection restriction for its documented passthrough configurations; pre-465 Error 43 workarounds are legacy. That announcement does not certify every single-GPU host. Update the guest driver rather than blindly adding `<kvm><hidden state='on'/></kvm>` or a Hyper-V `vendor_id`. These settings do not fix every Error 43 cause and are not performance options.

### GPU ROM dumps

A dumped or patched VBIOS is not normally required. Use one only for a diagnosed firmware/GPU issue. The optional `vbiospatch` script now requires an explicit PCI address and output path, refuses to overwrite a file, and restores the ROM control after reading:

```bash
chmod +x vbiospatch
sudo ./vbiospatch 0000:01:00.0 ./gpu.rom
```

Dumping the active host GPU's ROM can fail or be unreliable; do not make it part of the basic setup.

## Troubleshooting

Inspect libvirt and kernel messages:

```bash
sudo journalctl -u libvirtd.service -b
sudo journalctl -k -b
```

The hook sends errors to stderr, which libvirt logs. It intentionally does not maintain shared, overwritten log files.

If the host display does not return after the guest exits, use SSH or another VT:

```bash
systemctl status display-manager.service
sudo systemctl restart display-manager.service
```

Check that all GPU hostdevs still have `managed='yes'`. If `GPU_PCI_ADDRESS` is configured, the hook waits up to `GPU_READY_TIMEOUT` seconds for the matching DRM device and then attempts display-manager recovery even on timeout. Increase that timeout only if the logs show a slow but otherwise successful GPU reattachment.

For hook installation problems, verify that the file is executable and was present when the relevant libvirt daemon started:

```bash
sudo systemctl restart libvirtd.service
namei -l /etc/libvirt/hooks/qemu.d/50-single-gpu
```

## Current documentation

- [Arch Wiki: PCI passthrough via OVMF](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [Arch Wiki: libvirt](https://wiki.archlinux.org/title/Libvirt)
- [libvirt: QEMU hooks and native `qemu.d`](https://libvirt.org/hooks.html)
- [libvirt: domain XML, PCI hostdevs, firmware, Hyper-V, and CPU tuning](https://libvirt.org/formatdomain.html)
- [libvirt: `virsh nodedev-detach` and `nodedev-reattach`](https://libvirt.org/manpages/virsh.html#nodedev-commands)
- [Linux kernel: IOMMU kernel parameters](https://docs.kernel.org/admin-guide/kernel-parameters.html)
- [QEMU: Hyper-V enlightenments](https://www.qemu.org/docs/master/system/i386/hyperv.html)
- [NVIDIA: GeForce GPU passthrough support](https://nvidia.custhelp.com/app/answers/detail/a_id/5173)
