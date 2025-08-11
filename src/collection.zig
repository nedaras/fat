const std = @import("std");
const build_options = @import("build_options");
const fontconfig = @import("collection/fontconfig.zig");
const directwrite = @import("collection/directwrite.zig");
const library = @import("library.zig");
const mem = std.mem;
const Allocator = std.mem.Allocator;

pub const FontWeight = enum {
    thin,
    extralight,
    light,
    semilight,
    book, // mb just make this one regular
    regular,
    medium,
    demibold,
    bold,
    extrabold,
    black,
    extrablack,
};

pub const FontSlant = enum {
    roman,
    italic,
    oblique,
};

/// Descriptor is used to search for fonts. The only required field
/// is "family". The rest are ignored unless they're set to a non-zero
/// value.
pub const Descriptor = struct {
    /// Font family to search for. This can be a fully qualified font
    /// name such as "Fira Code", "monospace", "serif", etc. Memory is
    /// owned by the caller and should be freed when this descriptor
    /// is no longer in use. The discovery structs will never store the
    /// descriptor.
    ///
    /// On systems that use fontconfig (Linux), this can be a full
    /// fontconfig pattern, such as "Fira Code-14:bold".
    family: ?[:0]const u8 = null,

    /// Specific font style to search for. This will filter the style
    /// string the font advertises. The "bold/italic" booleans later in this
    /// struct filter by the style trait the font has, not the string, so
    /// these can be used in conjunction or not.
    style: ?[:0]const u8 = null, // tood make it an enum wtf

    /// A codepoint that this font must be able to render.
    codepoint: u21 = 0, // todo: make it codepoints

    /// Font size in points that the font should support. For conversion
    /// to pixels, we will use 72 DPI for Mac and 96 DPI for everything else.
    /// (If pixel conversion is necessary, i.e. emoji fonts)
    size: f32 = 0.0,

    pub const C = extern struct {
        family: ?[*:0]const u8 = null,
        style: ?[*:0]const u8 = null,
        codepoint: u32 = 0,
        size: f32 = 0.0,
    };

    ///// True if we want to search specifically for a font that supports
    ///// specific styles.
    //bold: bool = false,
    //italic: bool = false,
    //monospace: bool = false,
};

pub const InitError = error{
    OutOfMemory,
    Unexpected,
};

// todo: remove this this is b shit
pub const FontIterator = switch (build_options.font_backend) {
    .FontconfigFreetype => fontconfig.FontIterator,
    .Directwrite => directwrite.FontIterator,
    .Freetype => Noop.FontIterator,
};

pub inline fn initIterator(allocator: Allocator, backend: library.CollectionBackend, descriptor: Descriptor) InitError!FontIterator {
    return switch (build_options.font_backend) {
        .FontconfigFreetype => fontconfig.initIterator(allocator, backend, descriptor),
        .Directwrite => directwrite.initIterator(allocator, backend, descriptor),
        .Freetype => Noop.initIterator(allocator, backend, descriptor),
    };
}

pub const Noop = struct {
    pub fn initIterator(_: Allocator, _: void, _: Descriptor) InitError!Noop.FontIterator {
        return .{};
    }

    pub const FontIterator = struct {
        pub const Font = struct {
            family: [:0]const u8,
            size: f32,

            pub fn deinit(_: Font) void {}

            pub inline fn hasCodepoint(_: Font, _: u21) bool {
                return false;
            }
        };

        pub fn next(_: *Noop.FontIterator) !?Font {
            return null;
        }

        pub fn deinit(_: Noop.FontIterator) void {}
    };
};
