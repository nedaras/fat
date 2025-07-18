const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");
const windows = @import("windows.zig");
const freetype = @import("freetype.zig");
const fontconfig = @import("fontconfig.zig");
const collection = @import("collection.zig");
const Face = @import("Face.zig");
const font_backend = build_options.font_backend;

// there is lit no point to have multiple Impl for Library
// as we can have both say freetype for faces and dwrite for fallbacks
// so its best to have like `dw_factory` `ft_library` `fc_condif` `ct_smth` and set unsued ones to voids
// and we should set them all to null like `fc_config` below and only init when we need to to.

impl: Impl,

fc_config: if (font_backend.hasFontConfig()) ?*fontconfig.FcConfig else void =
    if (font_backend.hasFontConfig()) null else {},

const Library = @This();

const InitError = error{
    OutOfMemory,
    Unexpected,
};

pub fn init() InitError!Library {
    return .{ .impl = try Impl.init() };
}

pub fn deinit(self: *Library) void {
    if (font_backend.hasFontConfig()) {
        if (self.fc_config) |fc_config| {
            fontconfig.FcConfigDestroy(fc_config);
        }
    }
    self.impl.deinit();
    self.* = undefined;
}

pub inline fn openFace(self: *const Library, sub_path: [:0]const u8, options: Face.OpenFaceOptions) !Face {
    return Face.openFace(self.*, sub_path, options);
}

pub inline fn fontCollection(self: *Library, descriptor: collection.Descriptor) !collection.GenericFontIterator {
    if (font_backend.hasFontConfig()) {
        if (self.fc_config == null) {
            self.fc_config = try fontconfig.FcInitLoadConfigAndFonts();
        }
    }

    return collection.initIterator(self.*, descriptor);
}

pub const Impl = switch (font_backend) {
    .Freetype, .FontconfigFreetype => FreetypeImpl,

    .Directwrite => DWriteImpl,
};

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

    pub fn deinit(self: DWriteImpl) void {
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

    pub fn deinit(self: FreetypeImpl) void {
        freetype.FT_Done_FreeType(self.ft_library);
    }
};
