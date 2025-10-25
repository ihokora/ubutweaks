# 🛠 ubutweaks — Ubuntu Tweaks & Fixes

![Bash](https://img.shields.io/badge/shell-bash-orange)
![Linux](https://img.shields.io/badge/platform-linux-blue)

`ubutweaks` is a lightweight collection of scripts to setup/tweak/fix Ubuntu

---

## ⚡ Scripts

### `enable-fn-keys.sh` — Fn Key Fix for NuPhy / Apple-style / NOT QMK-BASED BOARD keyboards

**Problem:**  
External keyboards like NuPhy are often misdetected as Apple HID devices.  
The kernel sets `hid_apple fnmode=1` (media-first), so F1–F12 **don't work**, even with Fn pressed.

**Solution:**  
- **Temporary:** Apply `fnmode=2` immediately (`/sys/module/hid_apple/parameters/fnmode`) until reboot.  
- **Permanent:** Add `options hid_apple fnmode=2` to `/etc/modprobe.d/hid_apple.conf` and update initramfs.

**Why fnmode=2:**  
- `1` → media-first (macOS style)  
- `2` → F1–F12 standard, Fn modifies to media keys ✅  
- `3` → auto-detect, may fail on external keyboards ⚠️

### Function Key Behavior Settings

The `fnmode` values control how function keys behave:
- `0` = disabled: Fn key disabled, Fn+F8 acts as F8
- `1` = fkeyslast: F8 acts as special key, Fn+F8 acts as F8
- `2` = fkeysfirst: F8 acts as F8, Fn+F8 acts as special key

### Usage

```bash
# Temporary fix
sudo ./enable-fn.sh  # choose Temporary

# Permanent fix
sudo ./enable-fn.sh  # choose Permanent
```

### Verification

Check current runtime value:
```bash
cat /sys/module/hid_apple/parameters/fnmode
```

### Manual Configuration

For permanent changes:
1. Add configuration:
```bash
echo options hid_apple fnmode=2 | sudo tee -a /etc/modprobe.d/hid_apple.conf
```

2. Update initramfs:
```bash
sudo update-initramfs -u -k all
```

3. Reboot (optional):
```bash
sudo reboot
```

## 📂 Adding New Scripts

- Place scripts in `scripts/`
- Document problem, solution, and usage in README.md

