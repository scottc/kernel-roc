pub const BaseRevision = extern struct {
    revision: u64 = 3, // use the revision your limine.h expects
};

pub const EntryPointRequest = extern struct {
    id: [4]u64 = .{ 0xc7b1dd30df4c8b88, 0x0a82e883a194f07b, 0x13d86c56ee505ba, 0x1e5e7a9db0b5d0 },
    revision: u64 = 0,
    response: ?*EntryPointResponse = null,
    entry: ?*const fn () callconv(.c) noreturn = null,
};

pub const EntryPointResponse = extern struct {
    revision: u64,
    // ...
};

// Simpler approach used by many kernels: just export the entry and
// put requests in .limine_requests — see Limine “minimal kernel” examples.
