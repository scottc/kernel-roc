// src/serial.zig
const PORT: u16 = 0x3F8;

pub fn init() void {
    // classic 16550 init (baud, etc.) – short sequence
    outb(PORT + 1, 0x00);
    outb(PORT + 3, 0x80);
    outb(PORT + 0, 0x03); // 38400 baud
    outb(PORT + 1, 0x00);
    outb(PORT + 3, 0x03);
    outb(PORT + 2, 0xC7);
    outb(PORT + 4, 0x0B);
}

pub fn write(s: []const u8) void {
    for (s) |c| {
        while ((inb(PORT + 5) & 0x20) == 0) {}
        outb(PORT, c);
    }
}

fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "N{dx}" (port),
    );
}

fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "N{dx}" (port),
    );
}
