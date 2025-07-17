const std = @import("std");
const Library = @import("Library.zig");
const fontconfig = @import("fontconfig.zig");

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
    style: ?[:0]const u8 = null,

    /// A codepoint that this font must be able to render.
    codepoint: u21 = 0,

    /// Font size in points that the font should support. For conversion
    /// to pixels, we will use 72 DPI for Mac and 96 DPI for everything else.
    /// (If pixel conversion is necessary, i.e. emoji fonts)
    size: f32 = 0.0,

    /// True if we want to search specifically for a font that supports
    /// specific styles.
    bold: bool = false,
    italic: bool = false,
    monospace: bool = false,
};

// kinda weird having it here
// idea is to store this inside Library impl as null when we req for fonts we init it and cache it
fc_config: *fontconfig.FcConfig,

const Collection = @This();

pub const OpenError = error{
    MatchNotFound,
    OutOfMemory,
    Unexpected,
};

pub fn open(_: Library, descriptor: Descriptor) OpenError!Collection {
    const fc_config = try fontconfig.FcInitLoadConfigAndFonts(); 
    errdefer fontconfig.FcConfigDestroy(fc_config);

    const pattern = try fontconfig.FcPatternCreate();
    defer fontconfig.FcPatternDestroy(pattern);

    if (descriptor.codepoint != 0) {
        const charset = try fontconfig.FcCharSetCreate();
        defer fontconfig.FcCharSetDestroy(charset);

        fontconfig.FcCharSetAddChar(charset, descriptor.codepoint);
        fontconfig.FcPatternAddCharSet(pattern, "charset", charset);
    }

    fontconfig.FcConfigSubstitute(fc_config, pattern, .FcMatchPattern);
    fontconfig.FcDefaultSubstitute(pattern);

    const font_set = try fontconfig.FcFontSort(fc_config, pattern, false, null);
    defer fontconfig.FcFontSetDestroy(font_set);

    for (0..@intCast(font_set.nfont)) |i| {
        const font_pattern = try fontconfig.FcFontRenderPrepare(fc_config, pattern, font_set.fonts[i].?);
        defer fontconfig.FcPatternDestroy(font_pattern);

        const charset = try fontconfig.FcPatternGetCharSet(font_pattern, "charset", 0);
        const family = try fontconfig.FcPatternGetString(font_pattern, "family", 0);
        const file = try fontconfig.FcPatternGetString(font_pattern, "file", 0);
        const index = try fontconfig.FcPatternGetInteger(font_pattern, "index", 0);

        _ = family;

        if (fontconfig.FcCharSetHasChar(charset, descriptor.codepoint)) {
            // we getting big indexes sometimes why?
            std.debug.print("'{s}': {d}\n", .{file, index});
        }

        //std.debug.print("'{s}': has: {}\n", .{family, fontconfig.FcCharSetHasChar(charset, descriptor.codepoint)});
    }

    return .{
        .fc_config = fc_config,
    };
}

pub fn close(self: Collection) void {
    fontconfig.FcConfigDestroy(self.fc_config);
}
