#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

LIMINE_DIR=vendor/limine-binary
ISO_ROOT=iso_root
KERNEL_ELF="$ISO_ROOT/boot/kernel.elf"

chmod +x scripts/gen_glue.sh
./scripts/gen_glue.sh

# --- host lib (optional if you only final-link with Zig) ---
mkdir -p platform/targets-out/x64elf
zig build-lib \
  host/host.zig \
  -target x86_64-freestanding-none \
  -fno-entry \
  -OReleaseSafe \
  -mno-red-zone \
  -femit-bin=platform/targets-out/x64elf/libhost.a

roc build --target=x64elf app/main.roc
# produces main.a (or similar)

# --- final kernel: host + Roc app ---
mkdir -p "$ISO_ROOT/boot" "$ISO_ROOT/boot/limine" "$ISO_ROOT/EFI/BOOT"

zig build-exe \
  -target x86_64-freestanding-none \
  -fentry=kmain \
  -T host/linker.ld \
  -mno-red-zone \
  -OReleaseSafe \
  -femit-bin="$KERNEL_ELF" \
  host/host.zig main.a

test -f "$KERNEL_ELF"

# --- Limine files (paths match official template) ---
# Config: limine.conf or limine.cfg depending on Limine major version
if [[ -f limine.conf ]]; then
  cp limine.conf "$ISO_ROOT/boot/limine/"
elif [[ -f limine.cfg ]]; then
  cp limine.cfg "$ISO_ROOT/boot/limine/"
else
  echo "missing limine.conf/cfg" >&2
  exit 1
fi

cp "$LIMINE_DIR/limine-bios.sys"      "$ISO_ROOT/boot/limine/"
cp "$LIMINE_DIR/limine-bios-cd.bin"   "$ISO_ROOT/boot/limine/"
cp "$LIMINE_DIR/limine-uefi-cd.bin"   "$ISO_ROOT/boot/limine/"
cp "$LIMINE_DIR/BOOTX64.EFI"          "$ISO_ROOT/EFI/BOOT/" 2>/dev/null || true
# optional: BOOTIA32.EFI

# --- ISO (no -boot-catalog) ---
xorriso -as mkisofs -R -r -J \
  -b boot/limine/limine-bios-cd.bin \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  --efi-boot boot/limine/limine-uefi-cd.bin \
  -efi-boot-part --efi-boot-image --protective-msdos-label \
  "$ISO_ROOT" -o kernal-roc.iso

# host tool from the binary release (build it if only sources exist)
LIMINE_TOOL="$LIMINE_DIR/limine"
if [[ ! -x "$LIMINE_TOOL" ]]; then
  # binary releases often ship a prebuilt `limine`; else:
  make -C "$LIMINE_DIR" 2>/dev/null || true
fi
"$LIMINE_TOOL" bios-install kernal-roc.iso

qemu-system-x86_64 -m 512M -cdrom kernal-roc.iso -serial stdio
