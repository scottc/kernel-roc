// host/host.zig  (or a separate host/roc_runtime.zig that you @import)

const std = @import("std");
const roc_platform_abi = @import("roc_platform_abi.zig");
const serial = @import("serial.zig");

// ---------- required Roc runtime symbols ----------

fn writeUsize(n: usize) void {
    var buf: [20]u8 = undefined;
    var i: usize = buf.len;
    var x = n;
    if (x == 0) {
        serial.write("0");
        return;
    }
    while (x > 0) : (x /= 10) {
        i -= 1;
        buf[i] = @intCast('0' + (x % 10));
    }
    serial.write(buf[i..]);
}

// Never null — Roc does not check
// 1 MiB arena at 4 MiB physical — identity-mapped, always present in QEMU
const HEAP_BASE: usize = 0x400000;
const HEAP_SIZE: usize = 4096;
const HEAP_OFFSET_ADDR: usize = 0x3FFFF0; // 16 bytes below the heap

var heap: [HEAP_SIZE]u8 align(16) = undefined;
var heap_offset: usize = 0;

var dummy_block: [256]u8 align(16) = [_]u8{0} ** 256; // global → .bss/.data, stable

fn getOffset() usize {
    return @as(*volatile usize, @ptrFromInt(HEAP_OFFSET_ADDR)).*;
}
fn setOffset(v: usize) void {
    @as(*volatile usize, @ptrFromInt(HEAP_OFFSET_ADDR)).* = v;
}

fn writeHex(n: usize) void {
    const digits = "0123456789abcdef";
    var shift: i32 = @intCast((@sizeOf(usize) * 8) - 4);
    while (shift >= 0) : (shift -= 4) {
        const nib: u8 = @truncate((n >> @intCast(shift)) & 0xf);
        serial.write(digits[nib .. nib + 1]);
    }
}

export fn roc_alloc(length: usize, alignment: usize) callconv(.c) *anyopaque {
    serial.write("A\n");
    if (length == 0 or length > 256 * 1024) {
        serial.write("OOM1\n");
        while (true) asm volatile ("hlt");
    }
    const align_to: usize = if (alignment == 0 or alignment > 4096) 16 else alignment;
    const aligned = std.mem.alignForward(usize, heap_offset, align_to);
    if (aligned >= heap.len or length > heap.len - aligned) {
        serial.write("OOM2\n");
        while (true) asm volatile ("hlt");
    }
    serial.write("M\n");
    const base = @as([*]u8, @ptrCast(&heap)) + aligned;
    @memset(base[0..length], 0);
    heap_offset = aligned + length;
    serial.write("R\n");
    return @ptrCast(base);
}

export fn roc_dealloc(ptr: *anyopaque, alignment: usize) callconv(.c) void {
    _ = ptr;
    _ = alignment;
}

export fn roc_realloc(ptr: *anyopaque, new_length: usize, alignment: usize) callconv(.c) *anyopaque {
    _ = ptr;
    return roc_alloc(new_length, alignment);
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
    serial.write("[write_string entered]\n");

    const len = arg0.len();
    // hard cap so a garbage length cannot spin forever
    const n = if (len > 4096) 4096 else len;

    serial.write("[len=");
    // tiny decimal print if you have one; otherwise skip
    serial.write("] ");

    const slice = arg0.asU8ptr()[0..n];
    serial.write(slice);
    serial.write("\n");
}

// ---------- entry that Roc will call ----------

extern fn roc_main() callconv(.c) void;

extern var __bss_start: u8;
extern var __bss_end: u8;

fn zeroBss() void {
    const start = @intFromPtr(@extern(*u8, .{ .name = "__bss_start" }));
    const end = @intFromPtr(@extern(*u8, .{ .name = "__bss_end" }));
    if (end <= start) return;
    // refuse absurd ranges (protect against bad symbols)
    if (end - start > 32 * 1024 * 1024) return;
    const ptr: [*]u8 = @ptrFromInt(start);
    @memset(ptr[0 .. end - start], 0);
}

export var probe: usize = 0x1122334455667788;

export fn kmain() callconv(.c) noreturn {
    asm volatile ("and $-16, %%rsp" ::: .{ .rsp = true });

    serial.init();
    serial.write("kmain live\n");

    serial.write("Kernel Roc boot...\n");
    serial.write("calling roc_main\n");

    //     // in kmain, before roc_main:
    //     serial.write("probe=");
    //     writeHex(probe);
    //     serial.write("\n");
    //     probe = 0;
    //     serial.write("probe0=");
    //     writeHex(probe);
    //     serial.write("\n");
    //
    //     setOffset(0);
    //     serial.write("off before roc=");
    //     writeHex(getOffset()); // must print 0000000000000000
    //     serial.write("\n");
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

// const ALIGN = 1 << 0;
// const MEMORY_INFO = 1 << 1;
// const MAGIC: u32 = 0xE85250D6;
// const ARCHITECTURE: u32 = 0; // i386
// const HEADER_LENGTH: u32 = @sizeOf(MultibootHeader);
// const CHECKSUM: u32 = 0 -% (MAGIC + ARCHITECTURE + HEADER_LENGTH);
//
// const MultibootHeader = extern struct {
//     magic: u32 = MAGIC,
//     architecture: u32 = ARCHITECTURE,
//     header_length: u32 = HEADER_LENGTH,
//     checksum: u32 = CHECKSUM,
//     // end tag
//     end_type: u16 = 0,
//     end_flags: u16 = 0,
//     end_size: u32 = 8,
// };
//
// export const multiboot_header: MultibootHeader align(4) linksection(".multiboot") = .{};
//
// // extern var stack_top;
//
// // Simple entry that Multiboot will jump to
// export fn _start() callconv(.naked) noreturn {
//     asm volatile (
//         \\ cli
//         \\ mov $stack_top, %rsp
//         \\ and $-16, %rsp
//         \\ call kmain
//         \\ 1: hlt
//         \\ jmp 1b
//     );
//     // while (true) {}
// }
