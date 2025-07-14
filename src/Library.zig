const builtin = @import("builtin");
const windows = @import("windows.zig");
const freetype = @import("freetype.zig");
const Face = @import("Face.zig");

impl: Impl,

const Library = @This();

const InitError = error{
    OutOfMemory,
    Unexpected,
};

pub fn init() InitError!Library {
    return .{ .impl = try Impl.init() };
}

pub fn deinit(self: *Library) void {
    self.impl.deinit();
    self.* = undefined;
}

pub fn openFace(self: Library, sub_path: [:0]const u8) !Face {
    return Face.openFace(self, sub_path);
}

pub const Impl = if (builtin.os.tag == .windows) DWriteImpl else FreetypeImpl;

const DWriteImpl = struct {
    dwrite_factory: *windows.IDWriteFactory,

    pub fn init() InitError!DWriteImpl {
        var dwrite_factory: *windows.IDWriteFactory = undefined;

        try windows.DWriteCreateFactory(
            .DWRITE_FACTORY_TYPE_SHARED,
            windows.IDWriteFactory.UUID,
            @ptrCast(&dwrite_factory),
        );

        return .{
            .dwrite_factory = dwrite_factory,
        };
    }

    pub fn deinit(self: *DWriteImpl) void {
        self.dwrite_factory.Release();
    }
};

const FreetypeImpl = struct {
    ft_library: freetype.FT_Library,

    pub fn init() InitError!FreetypeImpl {
        var ft_library: freetype.FT_Library = undefined;
        try freetype.FT_Init_FreeType(&ft_library);

        return .{
            .ft_library = ft_library,
        };
    }

    pub fn deinit(self: *FreetypeImpl) void {
        freetype.FT_Done_FreeType(self.ft_library);
    }
};
