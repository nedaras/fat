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

pub inline fn openFace(self: Library, sub_path: [:0]const u8, options: Face.OpenFaceOptions) !Face {
    return Face.openFace(self, sub_path, options);
}

pub const Impl = if (builtin.os.tag == .windows) DWriteImpl else FreetypeImpl;

const DWriteImpl = struct {
    dw_factory: *windows.IDWriteFactory,

    pub fn init() InitError!DWriteImpl {
        var dw_factory: *windows.IDWriteFactory = undefined;

        try windows.DWriteCreateFactory(
            .DWRITE_FACTORY_TYPE_SHARED,
            windows.IDWriteFactory.UUID,
            @ptrCast(&dw_factory),
        );

        return .{
            .dw_factory = dw_factory,
        };
    }

    pub fn deinit(self: *DWriteImpl) void {
        self.dw_factory.Release();
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
