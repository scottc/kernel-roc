chmod +x scripts/gen_glue.sh
./scripts/gen_glue.sh

mkdir -p platform/targets-out/x64elf
zig build-lib \
  host/host.zig \
  -target x86_64-freestanding-none \
  -fno-entry \
  -OReleaseSafe \
  -mno-red-zone \
  -femit-bin=platform/targets-out/x64elf/libhost.a

  roc build --target=x64elf app/main.roc

  zig build-exe \
    main.a \
    -T host/linker.ld \
    -fentry=_start \
    -target x86_64-freestanding-none \
    -mno-red-zone \
    -OReleaseSafe \
    -femit-bin=kernel.elf

mkdir -p iso/boot/grub
cp kernel.elf iso/boot/
cp grub.cfg iso/boot/grub/

grub-mkrescue -o kernal-roc.iso iso/

qemu-system-x86_64 -cdrom kernal-roc.iso -serial stdio
