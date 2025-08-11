const std = @import("std");
//const builtin = @import("builtin");
const build_options = @import("build_options");
const windows = @import("windows.zig");
const freetype = @import("freetype.zig");
const fontconfig = @import("fontconfig.zig");
const collection = @import("collection.zig");
const Allocator = std.mem.Allocator;

pub const Face = @import("Face.zig");
pub const FontSlant = collection.FontSlant;
pub const FontWeight = collection.FontWeight;

pub const FontBackend = switch (build_options.font_backend) {
    .Freetype, .FontconfigFreetype => freetype.FT_Library,

    .Directwrite => *windows.IDWriteFactory,
};

pub const CollectionBackend = switch (build_options.font_backend) {
    .FontconfigFreetype => *fontconfig.FcConfig,
    .Directwrite => *windows.IDWriteFactory,
    .Freetype => void,
};

var mutex: std.Thread.Mutex = .{};

var font_backend: ?FontBackend = null;
var collection_backend: ?CollectionBackend = null;

pub fn getFontBackend() error{OutOfMemory}!FontBackend {
    mutex.lock();
    defer mutex.unlock();

    if (font_backend == null) {
        switch (build_options.font_backend) {
            .Freetype, .FontconfigFreetype => {
                var ft_library: freetype.FT_Library = undefined;
                freetype.FT_Init_FreeType(&ft_library) catch |err| return switch (err) {
                    error.OutOfMemory => |e| e,
                    else => unreachable,
                };

                font_backend = ft_library;
            },
            .Directwrite => {
                var dw_factory: *windows.IDWriteFactory = undefined;

                windows.DWriteCreateFactory(
                    .DWRITE_FACTORY_TYPE_SHARED,
                    windows.IDWriteFactory.UUID,
                    @ptrCast(&dw_factory),
                ) catch |err| return switch (err) {
                    error.OutOfMemory => |e| e,
                    else => unreachable,
                };

                font_backend = dw_factory;
            },
        }
    }

    return font_backend.?;
}

pub fn getCollectionBackend() error{OutOfMemory}!CollectionBackend {
    if (FontBackend == CollectionBackend) {
        return getFontBackend();
    }

    mutex.lock();
    defer mutex.unlock();

    if (collection_backend == null) {
        switch (build_options.font_backend) {
            .FontconfigFreetype => {
                const fc_config = try fontconfig.FcInitLoadConfigAndFonts();
                collection_backend = fc_config;
            },
            .Directwrite => {
                var dw_factory: *windows.IDWriteFactory = undefined;

                windows.DWriteCreateFactory(
                    .DWRITE_FACTORY_TYPE_SHARED,
                    windows.IDWriteFactory.UUID,
                    @ptrCast(&dw_factory),
                ) catch |err| return switch (err) {
                    error.OutOfMemory => |e| e,
                    else => unreachable,
                };

                collection_backend = dw_factory;
            },
            .Freetype => return {},
        }
    }

    return collection_backend.?;
}

pub fn openFace(sub_path: [:0]const u8, options: Face.OpenFaceOptions) !Face {
    const backend = try getFontBackend();
    return Face.openFace(backend, sub_path, options);
}

pub fn iterateCollection(allocator: Allocator, descriptor: collection.Descriptor) !collection.FontIterator {
    const backend = try getCollectionBackend();
    return collection.initIterator(allocator, backend, descriptor);
}

test {
    const face = try openFace("/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf", .{ .size = .{ .points = 12.0 } });
    defer face.close();

    var it = try iterateCollection(std.testing.allocator, .{});
    defer it.deinit();

    while (try it.next()) |f| {
        defer f.deinit();

        std.debug.print("{s}\n", .{f.family});
    }
}
