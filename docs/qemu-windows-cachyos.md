# Running CachyOS + Hyprland in QEMU on Windows (no WSL2)

Native QEMU on Windows using **WHPX** (Windows Hypervisor Platform) for
acceleration — no WSL2, no nested virtualization. Simpler than the WSL2 route,
and virtio-gpu still gives Hyprland a real DRM/GBM device, so it avoids the
VirtualBox `GBM ASSERTION FAILED` crash.

## Read this first (honest expectations)

- ✅ No WSL2 layer. WHPX gives near-native **CPU** speed.
- ✅ Hyprland should **start and draw** (virtio-gpu = real DRM/KMS/GBM).
- ⚠️ **GPU**: only accelerated if your QEMU build ships **virglrenderer**
  (many Windows builds don't). If it doesn't, the guest software-renders
  (llvmpipe) → **lag**, worst on blur/shadows/atmosphere/animations.
- 🚫 Smooth, full-speed, everything-glowing = bare metal (live USB / dual-boot).
  This is "see it move," not daily-usable.

---

## 0. Prerequisites
- Windows 11, **virtualization enabled in BIOS/UEFI** (VT-x / AMD-V).
- ~30 GB free disk.
- CachyOS ISO downloaded (cachyos.org/download).

## 1. Turn on Windows Hypervisor Platform
Open **"Turn Windows features on or off"** (`optionalfeatures.exe`) and tick:
- **Windows Hypervisor Platform**
- **Virtual Machine Platform**

Click OK, **reboot**. (This is what gives QEMU its `whpx` accelerator. It
coexists with Hyper-V/WSL if you have them.)

## 2. Install QEMU for Windows
Easiest, in **PowerShell (Admin)**:
```powershell
winget install --id=SoftwareFreedomConservancy.QEMU -e
```
(or grab the installer from qemu.weilnetz.de). Then add QEMU to PATH, or just
`cd` into its folder (default `C:\Program Files\qemu`) for the commands below.
Verify:
```powershell
qemu-system-x86_64.exe --version
```

## 3. Make a working folder + the disk
In a folder of your choice (e.g. `D:\cachyVM`):
```powershell
cd D:\cachyVM
qemu-img.exe create -f qcow2 cachy.qcow2 30G
# put the ISO here too: D:\cachyVM\cachyos.iso
```

## 4. First boot — run the installer
In **cmd** from that folder (`^` = line continuation):
```bat
qemu-system-x86_64.exe ^
  -m 8192 -smp cores=4 ^
  -accel whpx,kernel-irqchip=off ^
  -cpu max ^
  -machine type=q35 ^
  -drive file=cachy.qcow2,if=virtio ^
  -cdrom cachyos.iso ^
  -boot d ^
  -device virtio-vga-gl ^
  -display gtk,gl=on ^
  -usb -device usb-tablet
```
A QEMU window opens with CachyOS live. Run the installer (Calamares); pick the
**Hyprland** profile if offered, else install base and add Hyprland in step 6.
Shut down when done.

> If it says `virtio-vga-gl: opengl is not available` or the window is black,
> your QEMU build has no virgl. Swap `-device virtio-vga-gl` → `-vga virtio`
> and `-display gtk,gl=on` → `-display gtk`. The installer runs fine in 2D.

## 5. Boot the installed system
Drop `-cdrom` and `-boot d`:
```bat
qemu-system-x86_64.exe ^
  -m 8192 -smp cores=4 ^
  -accel whpx,kernel-irqchip=off ^
  -cpu max ^
  -machine type=q35 ^
  -drive file=cachy.qcow2,if=virtio ^
  -device virtio-vga-gl ^
  -display gtk,gl=on ^
  -usb -device usb-tablet
```

## 6. Install the rice
Inside CachyOS:
```bash
sudo pacman -S --needed git hyprland
git clone https://github.com/HariUwU/index-OS.git
cd index-OS && chmod +x install.sh && ./install.sh
```
Log into Hyprland, Super+Return for a foot terminal, run `quickshell` for the
bar + atmosphere, `fastfetch` for the emblem, Super+L for the lock.

---

## Troubleshooting

**WHPX won't start** (`whpx: ... failed` / `Could not access KVM`): the Windows
feature isn't on or BIOS virt is off. Re-do step 1, reboot. If it still errors,
try `-accel whpx,kernel-irqchip=off` (already in the command) or drop to
`-accel tcg` (pure software CPU — slow, last resort).

**`opengl is not available` / black window**: no virgl in your QEMU build. Use
`-vga virtio` (or `-vga std`) and `-display gtk` without `gl=on`. Hyprland then
software-renders.

**Hyprland won't start / GL errors**: launch with software GL + the VM cursor fix:
```bash
WLR_NO_HARDWARE_CURSORS=1 LIBGL_ALWAYS_SOFTWARE=1 Hyprland
```

**No `/dev/dri` in guest**: the virtio-gpu didn't attach — recheck the `-device`/
`-vga` line. `lsmod | grep virtio_gpu` should show it loaded.

**Runs but laggy**: software rendering. In `~/.config/hypr/will-of-the-city.conf`
turn off `blur` and `shadow`, and don't autostart `Atmosphere` (particles are the
heaviest). Bar, borders, lock, and fastfetch stay.

**Terminal won't open**: kitty needs a GPU; the install swaps it to `foot`. If a
kitty reference slipped through, change it to foot.

---

## Bottom line
WHPX makes the CPU fast; the GPU is the question. With virgl it might be
*usable*; without it, it's software-rendered and laggy — but it'll **run**, which
VirtualBox couldn't. For the real thing, full speed with the wallpaper and
particles glowing, it's still a CachyOS **live USB** or **dual-boot** — the only
setups where Hyprland gets a real GPU.
