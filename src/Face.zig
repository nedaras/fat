const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");
const Library = @import("Library.zig");
const directwrite = @import("face/directwrite.zig");
const freetype = @import("face/freetype.zig");
const shared = @import("face/shared.zig");
const Allocator = std.mem.Allocator;

pub const GlyphRender = shared.GlyphRender;
pub const GlyphBoundingBox = shared.GlyphBoundingBox;
/// The desired size for loading a font.
pub const DesiredSize = shared.DesiredSize;
pub const OpenFaceOptions = shared.OpenFaceOptions;

impl: Impl,

pub const OpenFaceError = error{
    FailedToOpen,
    NotSupported,
    InvalidWtf8,
    OutOfMemory,
    Unexpected,
};

/// Open a new font face with the given file path.
pub fn openFace(library: Library, sub_path: [:0]const u8, options: OpenFaceOptions) OpenFaceError!Face {
    return .{
        .impl = try Impl.openFace(library, sub_path, options),
    };
}

pub inline fn close(self: Face) void {
    self.impl.close();
}

/// Resize the font in-place.
pub inline fn setSize(self: *Face, size: DesiredSize) !void {
    return self.impl.setSize(size);
}

pub inline fn glyphIndex(self: Face, codepoint: u21) ?u32 {
    return self.impl.gyphIndex(codepoint);
}

pub inline fn glyphBoundingBox(self: Face, glyph_index: u32) !GlyphBoundingBox {
    return self.impl.glyphBoundingBox(glyph_index);
}

pub inline fn renderGlyph(self: Face, allocator: Allocator, glyph_index: u32) !GlyphRender {
    return self.impl.renderGlyph(allocator, glyph_index);
}

const Face = @This();

pub const Impl = switch (build_options.font_backend) {
    .Freetype,
    .FontconfigFreetype => freetype.Face,

    .Directwrite => directwrite.Face,
};
