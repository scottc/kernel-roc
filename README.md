# Kernel-Roc

A proof of concept kernal, roc platform, running on "bare metal", inside of qemu.

## About

Kernal-Roc lets you run roc application code on baremetal. The point of this project is not to be a kernal platform in of itself. But rather a tiny example to prove what is possible...

I hope this inspires you to make awesome roc platforms.

## Install roc, zig, qemu, grub2 & xorriso

```sh
nix run github:lukewilliamboswell/roc-blueprint/0.5.0 -- shell
```

## Build zig host.a

```sh
mkdir -p platform/targets-out/x64elf
zig build-lib \
  -target x86_64-freestanding-none \
  -fno-entry \
  -OReleaseSafe \
  -mno-red-zone \
  -femit-bin=platform/targets-out/x64elf/libhost.a \
  host/host.zig
```

## Build roc platform main.a

```sh
roc build --target=x64elf app/main.roc
# output -> main.a (x86_64 freestanding archive)
```

## Build final zig elf; link zig + roc + linker.ld

```sh
zig build-exe \
  main.a \
  -T host/linker.ld \
  -fentry=_start \
  -target x86_64-freestanding-none \
  -mno-red-zone \
  -OReleaseSafe \
  -femit-bin=kernel.elf \
# output -> kernel.elf (ELF executable; typically the extension is omittied.)
```

## Make ISO

> [!NOTE]
> Bootloader is only required as a workaround, because roc x64 bit only & qemu Multiboot 1 & 2 compatability.
> In theory, any device that supports Multiboot 2, should be able to boot the kernal directly.

```sh
mkdir -p iso/boot/grub
cp kernel.elf iso/boot/
cp grub.cfg iso/boot/grub/

grub-mkrescue -o kernal-roc.iso iso/
```

## Run on "bare metal".

```sh
qemu-system-x86_64 -cdrom kernal-roc.iso -display none -serial stdio
```
```
Kernel Roc boot...
roc_alloc
Kernel Roc boot...
roc_alloc
Kernel Roc boot...
roc_alloc
Kernel Roc boot...
roc_alloc
```

> [!NOTE]
> This is still in development, but this is where we're at.
