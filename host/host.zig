// host/host.zig  (or a separate host/roc_runtime.zig that you @import)

const std = @import("std");
const roc_platform_abi = @import("roc_platform_abi.zig");
const serial = @import("serial.zig");

// ---------- required Roc runtime symbols ----------

var heap: [1024 * 1024]u8 = undefined; // 1 MiB bump arena
var heap_offset: usize = 0;

export fn roc_alloc(size: usize, alignment: u32) callconv(.c) ?[*]u8 {
    _ = alignment;

    //serial.write("roc_alloc\n");

    const aligned = std.mem.alignForward(usize, heap_offset, 16);
    const total = size + 16; // room for the refcount word Roc writes at ptr[-8]
    if (aligned + total > heap.len) return null;
    const base: [*]u8 = @ptrCast(heap[aligned..].ptr);
    heap_offset = aligned + total;
    const ptr = base + 8;
    @memset(base[0..total], 0);
    return ptr;
}

export fn roc_dealloc(ptr: ?[*]u8, alignment: u32) callconv(.c) void {
    serial.write("roc_dealloc\n");

    _ = ptr;
    _ = alignment;
    // bump allocator – nothing to do
}

export fn roc_realloc(
    ptr: ?[*]u8,
    new_size: usize,
    old_size: usize,
    alignment: u32,
) callconv(.c) ?[*]u8 {
    _ = ptr;
    _ = old_size;
    serial.write("roc_realloc\n");

    return roc_alloc(new_size, alignment);
}

export fn roc_dbg(ptr: [*]const u8, len: usize) callconv(.c) void {
    serial.write(ptr[0..len]);
    serial.write("\n");
}

export fn roc_expect_failed(ptr: [*]const u8, len: usize) callconv(.c) void {
    serial.write("EXPECT FAILED: ");
    serial.write(ptr[0..len]);
    serial.write("\n");
    while (true) asm volatile ("hlt");
}

export fn roc_crashed(ptr: [*]const u8, len: usize) callconv(.c) void {
    serial.write("ROC CRASHED: ");
    serial.write(ptr[0..len]);
    serial.write("\n");
    while (true) asm volatile ("hlt");
}

// ---------- your effect ----------

export fn roc_write_string(arg0: roc_platform_abi.RocStr) callconv(.c) void {
    serial.write("[write_string] ");
    serial.write(arg0.asSlice());
}

// ---------- entry that Roc will call ----------

extern fn roc_main() callconv(.c) void;

export fn kmain() callconv(.c) noreturn {
    serial.init();
    serial.write("Kernel Roc boot...\n");
    roc_main();
    serial.write("Roc finished. Halting.\n");
    while (true) asm volatile ("hlt");
}

// Minimal freestanding implementations of the symbols the linker wants.

export fn memcpy(noalias dest: [*]u8, noalias src: [*]const u8, n: usize) callconv(.c) [*]u8 {
    serial.write("memcpy\n");

    @memcpy(dest[0..n], src[0..n]);
    return dest;
}

export fn memset(dest: [*]u8, c: u8, n: usize) callconv(.c) [*]u8 {
    //serial.write("memset\n");

    @memset(dest[0..n], c);
    return dest;
}

export fn __zig_probe_stack() callconv(.c) void {
    // no-op is fine for a tiny kernel; real kernels sometimes do a stack check here
}

///////

// pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
//     serial.write("PANIC: ");
//     serial.write(msg);
//     serial.write("\n");
//     while (true) asm volatile ("hlt");
// }

///////

// const multiboot = @import("multiboot.zig");
// host/multiboot.zig  (or top of host.zig)
// host/multiboot.zig  (or put it at the top of host.zig)

const ALIGN = 1 << 0;
const MEMORY_INFO = 1 << 1;
const MAGIC: u32 = 0xE85250D6;
const ARCHITECTURE: u32 = 0; // i386
const HEADER_LENGTH: u32 = @sizeOf(MultibootHeader);
const CHECKSUM: u32 = 0 -% (MAGIC + ARCHITECTURE + HEADER_LENGTH);

const MultibootHeader = extern struct {
    magic: u32 = MAGIC,
    architecture: u32 = ARCHITECTURE,
    header_length: u32 = HEADER_LENGTH,
    checksum: u32 = CHECKSUM,
    // end tag
    end_type: u16 = 0,
    end_flags: u16 = 0,
    end_size: u32 = 8,
};

export const multiboot_header: MultibootHeader align(4) linksection(".multiboot") = .{};

// extern var stack_top;

// Simple entry that Multiboot will jump to
export fn _start() callconv(.naked) noreturn {
    // Set up a stack (you need a symbol from the linker script)
    asm volatile (
        \\ mov $stack_top, %rsp
        \\ call kmain
        \\ hlt
    );
    while (true) {}
}
