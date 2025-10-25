#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# enable-fn — interactive Fn key fix for Apple-style and external keyboards
# ==================================================
# Many keyboards (Apple or Apple-like) behave differently on Linux due to hid_apple driver:
#
# fnmode values:
#   0 → macOS-style: media keys by default, Fn+F for F1–F12
#   1 → Fn-locked macOS-style: similar to 0, some keyboards invert Fn behavior
#   2 → Windows-style: F1–F12 default, hold Fn for media keys
#   3 → Auto-detect (newer kernels): tries to detect device type
#
# Important for NuPhy Halo 75 V1 and some external keyboards:
#   - fnmode=3 often behaves like 0 (media keys only)
#   - F1–F12 do NOT work even with Fn
#   → So we need fnmode=2 for correct F-key behavior
#
# This script allows temporary or permanent changes safely.

# ==================================================
# Config
# ==================================================
CONF_FILE="/etc/modprobe.d/hid_apple.conf"
CONF_LINE="options hid_apple fnmode=2"
BACKUP_DIR="/var/backups/enable-fn.d"
SYS_PATH="/sys/module/hid_apple/parameters/fnmode"

# ==================================================
# Colors & formatting
# ==================================================
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
RESET='\033[0m'

log()   { echo -e "${BLUE}[*]${RESET} $*"; }
ok()    { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[!]${RESET} $*"; }
error() { echo -e "${RED}[✗]${RESET} $*" >&2; }

TIMESTAMP() { date +"%Y%m%d-%H%M%S"; }

# ==================================================
# Core helpers
# ==================================================
require_root() {
  if [[ $EUID -ne 0 ]]; then
    error "This action requires root. Re-run with sudo."
    exit 2
  fi
}

backup_file() {
  local f=$1
  mkdir -p "$BACKUP_DIR"
  cp -a "$f" "$BACKUP_DIR/$(basename "$f").$(TIMESTAMP).bak"
  ok "Backup saved to $BACKUP_DIR"
}

append_conf() {
  if [[ -f "$CONF_FILE" && $(grep -Fx "$CONF_LINE" "$CONF_FILE" || true) ]]; then
    ok "Line already present in $CONF_FILE."
  else
    echo "$CONF_LINE" | tee -a "$CONF_FILE" >/dev/null
    ok "Added configuration line to $CONF_FILE"
  fi
}

remove_conf_line() {
  [[ -e "$CONF_FILE" ]] || { warn "$CONF_FILE not present."; return; }
  backup_file "$CONF_FILE"
  sed -i "\|^$CONF_LINE$|d" "$CONF_FILE"
  ok "Removed line from $CONF_FILE"
}

update_initramfs() {
  if command -v update-initramfs >/dev/null 2>&1; then
    log "Updating initramfs..."
    update-initramfs -u -k all
    ok "Initramfs updated."
  else
    warn "update-initramfs not found, skipping."
  fi
}

write_sysfs() {
  local val=$1
  if [[ ! -w "$SYS_PATH" ]]; then
    warn "Sysfs path $SYS_PATH not writable, loading module..."
    modprobe hid_apple || { error "Failed to load hid_apple"; return 1; }
    sleep 0.2
  fi
  echo "$val" | tee "$SYS_PATH" >/dev/null
  ok "Wrote $val to $SYS_PATH"
}

confirm() {
  read -rp "$(echo -e "${BOLD}$1 [y/N]: ${RESET}")" yn
  [[ $yn =~ ^[Yy]$ ]]
}

# ==================================================
# Actions
# ==================================================
temporary() {
  log "Temporary mode: apply fnmode=2 immediately (resets on reboot)."
  echo "→ Function keys (F1–F12) will behave as real F keys."
  echo "→ Media controls (volume, brightness) require holding Fn."
  echo "→ This fixes external keyboards like NuPhy Halo 75 V1."
  confirm "Proceed?" || return
  require_root
  write_sysfs 2 || error "Temporary change failed."
}

permanent() {
  local do_reboot=$1
  log "Permanent mode: set fnmode=2 at boot time via modprobe config."
  echo "→ Creates or updates ${CONF_FILE}"
  echo "→ Ensures F1–F12 work correctly for external keyboards"
  echo "→ Runs update-initramfs so setting is applied at boot"
  confirm "Proceed?" || return
  require_root
  [[ -e "$CONF_FILE" ]] && backup_file "$CONF_FILE" || { touch "$CONF_FILE"; chmod 644 "$CONF_FILE"; }
  append_conf
  update_initramfs
  ok "Permanent change applied. Effective after reboot."
  if [[ $do_reboot -eq 1 ]] && confirm "Reboot now?"; then reboot; fi
}

undo() {
  log "Undo permanent fnmode change (restore default behavior)."
  echo "→ F1–F12 may revert to media keys by default"
  echo "→ Fn key may or may not activate F keys depending on kernel"
  confirm "Proceed?" || return
  require_root
  remove_conf_line
  update_initramfs
  ok "Undo completed."
}

dryrun() {
  log "Dry-run — showing actions (no changes will be made)."
  echo -e "Would ensure ${BOLD}$CONF_FILE${RESET} exists and append:\n  $CONF_LINE\n"
  echo "Would run: update-initramfs -u -k all"
}

status() {
  log "Status:"
  if [[ -r "$SYS_PATH" ]]; then
    local fn=$(cat "$SYS_PATH")
    echo "  sysfs fnmode: $fn"
    if [[ $fn == "3" ]]; then
      warn "  fnmode=3 detected (auto mode)."
      echo "  → May behave incorrectly on external keyboards like NuPhy Halo 75 V1."
      echo "  → F1–F12 may not work even with Fn pressed."
      echo "  → Recommend using fnmode=2 for correct F-key behavior."
    fi
  else
    warn "  sysfs not readable; module may be missing."
  fi
  if [[ -f "$CONF_FILE" ]]; then
    if grep -Fxq "$CONF_LINE" "$CONF_FILE"; then
      ok "  Config line present in $CONF_FILE (permanent fix applied)"
    else
      warn "  $CONF_FILE exists but line missing (permanent fix not applied)"
    fi
  else
    warn "  $CONF_FILE does not exist"
  fi
}

# ==================================================
# Menu
# ==================================================
menu_header() {
  clear
  echo -e "${BOLD}Fn Key Fix Utility for Apple-style and external keyboards${RESET}"
  echo "──────────────────────────────────────────────"
  echo "Fixes F1–F12 behavior on Linux for external keyboards like NuPhy Halo 75 V1."
  echo
  echo "fnmode values:"
  echo "  0 → macOS-style (media keys by default, Fn+F for F1–F12)"
  echo "  1 → Fn-locked macOS style"
  echo "  2 → Windows-style (F1–F12 default, Fn for media) — recommended for external keyboards"
  echo "  3 → Auto-detect (kernel chooses per device, may fail on some external keyboards)"
  echo
}

menu() {
  menu_header
  echo "1) Temporary: apply fnmode=2 now"
  echo "2) Permanent: set fnmode=2 for all future boots"
  echo "3) Permanent + Reboot"
  echo "4) Undo Permanent (restore default behavior)"
  echo "5) Dry-run (show what would happen)"
  echo "6) Status (show current mode and warnings)"
  echo "7) Exit"
  echo
  read -rp "Choose [1-7]: " choice
  echo
  case "$choice" in
    1) temporary ;;
    2) permanent 0 ;;
    3) permanent 1 ;;
    4) undo ;;
    5) dryrun ;;
    6) status ;;
    7) exit 0 ;;
    *) warn "Invalid option." ;;
  esac
}

# ==================================================
# Main loop
# ==================================================
while true; do
  menu
  echo
  read -rp "Press Enter to return to menu..." _
done

