const std = @import("std");
const build_options = @import("build_options");
const fontconfig = @import("collection/fontconfig.zig");
const directwrite = @import("collection/directwrite.zig");
const noop = @import("collection/noop.zig");
const library = @import("library.zig");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Face = library.Face;

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

    //// Specific font style to search for. This will filter the style
    //// string the font advertises. The "bold/italic" booleans later in this
    //// struct filter by the style trait the font has, not the string, so
    //// these can be used in conjunction or not.
    //style: ?[:0]const u8 = null, // tood make it an enum wtf

    //// A codepoint that this font must be able to render.
    codepoint: u21 = 0,

    //// Font size in points that the font should support. For conversion
    //// to pixels, we will use 72 DPI for Mac and 96 DPI for everything else.
    //// (If pixel conversion is necessary, i.e. emoji fonts)
    //size: f32 = 0.0,

    ///// True if we want to search specifically for a font that supports
    ///// specific styles.
    //bold: bool = false,
    //italic: bool = false,
    //monospace: bool = false,
};

pub const DefferedFace = struct {
    family: [:0]const u8,

    impl: Impl,

    //size: f32,

    //weight: FontWeight,
    //slant: FontSlant,

    pub inline fn deinit(self: DefferedFace) void {
        self.impl.deinit();
    }

    pub fn open(self: DefferedFace, options: Face.OpenFaceOptions) !Face {
        const backend = try library.getFontBackend(); // todo: move this func out of getFontBackend
        return Face.openDefferedFace(backend, self, options);
    }

    pub inline fn hasCodepoint(self: DefferedFace, codepoint: u21) bool {
        return self.impl.hasCodepoint(codepoint);
    }

    const Impl = switch (build_options.font_backend) {
        .FontconfigFreetype => fontconfig.DefferedFace,
        .Directwrite => directwrite.DefferedFace,
        .Freetype => noop.DefferedFace,
    };
};

pub const FontIterator = struct {
    impl: Impl,

    pub const IterateFontsError = error{
        InvalidWtf8,
        OutOfMemory,
        Unexpected,
    };

    // todo: make like if no descriptor is set then prioritize regular fonts on top
    pub fn iterateFonts(backend: library.CollectionBackend, allocator: Allocator, descriptor: Descriptor) IterateFontsError!FontIterator {
        return .{ .impl = try Impl.init(backend, allocator, descriptor) };
    }

    pub inline fn deinit(self: FontIterator) void {
        self.impl.deinit();
    }

    pub fn next(self: *FontIterator) !?DefferedFace {
        const deffered_face = (try self.impl.next()) orelse return null;
        errdefer deffered_face.deinit();

        return .{
            .family = deffered_face.family(),
            .impl = deffered_face,
        };
    }

    const Impl = switch (build_options.font_backend) {
        .FontconfigFreetype => fontconfig.FontIterator,
        .Directwrite => directwrite.FontIterator,
        .Freetype => noop.FontIterator,
    };
};
