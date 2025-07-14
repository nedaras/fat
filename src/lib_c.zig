const std = @import("std");
const Library = @import("Library.zig");
const c_allocator = std.heap.c_allocator;

const fat_error_e = enum(c_int) {
    ok = 0,
    invalid_pointer,
    out_of_memory,
    unexpected,
};

export fn fat_init_library(clibrary: ?**Library) callconv(.C) fat_error_e {
    const clib = clibrary orelse return fat_error_e.invalid_pointer;
    const lib = c_allocator.create(Library) catch return fat_error_e.out_of_memory;

    lib.* = Library.init() catch |err| {
        c_allocator.destroy(lib);
        return switch (err) {
            error.OutOfMemory => fat_error_e.out_of_memory,
            error.Unexpected => fat_error_e.unexpected,
        };
    };

    clib.* = lib;
    return fat_error_e.ok;
}

export fn fat_library_done(clibrary: ?*Library) callconv(.C) fat_error_e {
    const clib = clibrary orelse return fat_error_e.invalid_pointer;
    clib.deinit();

    c_allocator.destroy(clib);
    return fat_error_e.ok;
}
