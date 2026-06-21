# Running CachyOS + Hyprland in QEMU on WSL2

A runbook for getting THE INDEX rice rendering inside a QEMU/KVM VM under WSL2.
This is the best **VM** option — virtio-gpu gives Hyprland a proper DRM/GBM
device, so it won't hit the VirtualBox `GBM ASSERTION FAILED` crash.

## Read this first (honest expectations)

- ✅ Hyprland should **start and draw** here (virtio-gpu has real DRM/KMS/GBM).
- ⚠️ Rendering is **software (llvmpipe)** — WSL2 can't pass a real GPU to a
  nested VM. Expect **lag**, worst on blur, shadows, the atmosphere particles,
  and animations.
- ⚠️ It can still fail at the GL step. Fallbacks are in the troubleshooting section.
- 🚫 This is "see it move in a VM," **not** smooth/daily-usable. For that you need
  bare metal (live USB / dual-boot) — the only path with a real GPU.

---

## 0. Prerequisites
- Windows 11 with WSL2, and **virtualization enabled in BIOS/UEFI** (VT-x / AMD-V).
- A WSL2 distro (Ubuntu assumed below).
- ~30 GB free on a drive (examples use `D:` → `/mnt/d`).
- The **CachyOS ISO** downloaded on Windows (cachyos.org/download).

## 1. Enable nested virtualization + systemd
On **Windows**, create/edit `C:\Users\<you>\.wslconfig`:
```ini
[wsl2]
nestedVirtualization=true
```
In **WSL2**, edit `/etc/wsl.conf`:
```ini
[boot]
systemd=true
```
Then from **PowerShell**:
```powershell
wsl --shutdown
```
Reopen WSL.

## 2. Install QEMU/KVM in WSL2
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y qemu-system-x86 qemu-utils cpu-checker \
                    libvirglrenderer1 mesa-utils
# confirm KVM is available:
ls -l /dev/kvm          # should exist
kvm-ok                  # should say KVM acceleration can be used
sudo usermod -aG kvm $USER
newgrp kvm
```
If `/dev/kvm` is missing → nested virt isn't on; recheck step 1 and BIOS.

## 3. Make folders + the virtual disk
```bash
mkdir -p /mnt/d/cachyVM /mnt/d/isos
# copy your CachyOS ISO into /mnt/d/isos/cachyos.iso (from Windows is fine)
qemu-img create -f qcow2 /mnt/d/cachyVM/cachy.qcow2 30G
```

## 4. First boot — run the installer
```bash
qemu-system-x86_64 \
  -m 8192 -smp cores=4 \
  -cpu host -machine type=q35,accel=kvm \
  -drive file=/mnt/d/cachyVM/cachy.qcow2,if=virtio \
  -cdrom /mnt/d/isos/cachyos.iso \
  -boot d \
  -device virtio-vga-gl \
  -display gtk,gl=on \
  -usb -device usb-tablet
```
A QEMU window opens (via WSLg) showing CachyOS live. Run the installer
(Calamares). When asked, pick the **Hyprland** edition/profile if offered;
otherwise install the base and add Hyprland in step 6. Shut down when done.

> If the window is black or `gl=on` throws an error, kill it and re-run with
> `-vga virtio` instead of `-device virtio-vga-gl` and `-display gtk` (no
> `gl=on`). The installer is X11/2D and will run fine in software.

## 5. Boot the installed system
Drop `-cdrom` and `-boot d` so it boots from the disk:
```bash
qemu-system-x86_64 \
  -m 8192 -smp cores=4 \
  -cpu host -machine type=q35,accel=kvm \
  -drive file=/mnt/d/cachyVM/cachy.qcow2,if=virtio \
  -device virtio-vga-gl \
  -display gtk,gl=on \
  -usb -device usb-tablet
```

## 6. Install the rice
Inside CachyOS:
```bash
sudo pacman -S --needed git hyprland   # if Hyprland isn't already there
git clone https://github.com/HariUwU/index-OS.git
cd index-OS
chmod +x install.sh
./install.sh
```
Log into Hyprland, open a terminal (Super+Return → foot), and run the bar +
atmosphere with `quickshell`. Then `fastfetch`, Super+L for the lock, etc.

---

## Troubleshooting

**Hyprland won't start / GL errors.** Try launching it with software GL and the
VM cursor fix:
```bash
WLR_NO_HARDWARE_CURSORS=1 LIBGL_ALWAYS_SOFTWARE=1 Hyprland
```

**Black screen but compositor seems up.** Check the guest actually has the
virtio DRM device:
```bash
ls /dev/dri        # expect card0 / renderD128
lsmod | grep virtio_gpu
```
If `/dev/dri` is empty, the virtio-gpu device didn't attach — re-check the
`-device virtio-vga-gl` / `-vga virtio` line.

**It runs but it's painfully laggy.** That's the software rendering. Turn off the
heavy effects: in `~/.config/hypr/will-of-the-city.conf` disable `blur` and
`shadow`, and don't autostart `Atmosphere` (the particle layer is the worst
offender on a software renderer). You'll lose the glow/particles but the bar,
borders, lock, and fastfetch stay.

**Terminal won't open.** kitty needs a GPU; the install already swaps to `foot`,
which software-renders. If you typed a kitty command somewhere, switch it to foot.

---

## Bottom line
If this works, you'll see your rice **move** — bar, borders, lock, maybe the
atmosphere if the CPU keeps up. It will not be smooth, and it may take a couple
of tries with the fallbacks. The moment you want it *real* — full speed, wallpaper
and particles glowing — that's bare metal: a CachyOS **live USB** or **dual-boot**,
where Hyprland finally gets a real GPU.
