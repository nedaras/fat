const std = @import("std");
const build_options = @import("build_options");
const windows = @import("windows.zig");
const fontconfig = @import("fontconfig.zig");
const Library = @import("Library.zig");
const unicode = std.unicode;
const assert = std.debug.assert;

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
    MatchNotFound,
    OutOfMemory,
    Unexpected,
};

// todo: remove this this is b shit
pub const GenericFontIterator = switch (build_options.font_backend) {
    .FontconfigFreetype => FontConfig.FontIterator,
    .Directwrite => DirectWrite.FontIterator,
    .Freetype => Noop.FontIterator,
};

pub inline fn initIterator(library: Library, descriptor: Descriptor) InitError!GenericFontIterator {
    return switch (build_options.font_backend) {
        .FontconfigFreetype => FontConfig.initIterator(library, descriptor),
        .Directwrite => DirectWrite.initIterator(library, descriptor),
        .Freetype => Noop.initIterator(library, descriptor),
    };
}

pub const FontConfig = struct {
    pub fn initIterator(library: Library, descriptor: Descriptor) InitError!FontIterator {
        const fc_pattern = try fontconfig.FcPatternCreate();
        errdefer fontconfig.FcPatternDestroy(fc_pattern);

        if (descriptor.family) |family| {
            fontconfig.FcPatternAddString(fc_pattern, "falimy", family);
        }

        if (descriptor.style) |style| {
            fontconfig.FcPatternAddString(fc_pattern, "style", style);
        }

        if (descriptor.codepoint != 0) {
            const charset = try fontconfig.FcCharSetCreate();
            defer fontconfig.FcCharSetDestroy(charset);

            fontconfig.FcCharSetAddChar(charset, descriptor.codepoint);
            fontconfig.FcPatternAddCharSet(fc_pattern, "charset", charset);
        }

        if (descriptor.size != 0.0) {
            fontconfig.FcPatternAddDouble(fc_pattern, "size", descriptor.size);
        }

        fontconfig.FcConfigSubstitute(library.fc_config.?, fc_pattern, .FcMatchPattern);
        fontconfig.FcDefaultSubstitute(fc_pattern);

        const fc_font_set = try fontconfig.FcFontSort(library.fc_config.?, fc_pattern, false, null);
        errdefer fontconfig.FcFontSetDestroy(fc_font_set);

        return .{
            .fc_config = library.fc_config.?,
            .fc_pattern = fc_pattern,
            .fc_font_set = fc_font_set,
            .idx = 0,
        };
    }

    pub const FontIterator = struct {
        fc_config: *fontconfig.FcConfig,
        fc_pattern: *fontconfig.FcPattern,
        fc_font_set: *fontconfig.FcFontSet,

        idx: c_uint,

        pub const Font = struct {
            fc_pattern: *fontconfig.FcPattern,
            fc_charset: *const fontconfig.FcCharSet,

            path: [:0]const u8,
            size: f32,

            pub fn deinit(self: Font) void {
                fontconfig.FcPatternDestroy(self.fc_pattern);
            }

            pub inline fn hasCodepoint(self: Font, codepoint: u21) bool {
                return fontconfig.FcCharSetHasChar(self.fc_charset, codepoint);
            }
        };

        pub fn next(self: *FontIterator) !?Font {
            if (self.idx == self.fc_font_set.nfont) {
                return null;
            }

            defer self.idx += 1;

            const fc_pattern = try fontconfig.FcFontRenderPrepare(self.fc_config, self.fc_pattern, self.fc_font_set.fonts[self.idx].?);
            errdefer fontconfig.FcPatternDestroy(fc_pattern);

            const fc_charset = try fontconfig.FcPatternGetCharSet(fc_pattern, "charset", 0);

            const file = try fontconfig.FcPatternGetString(fc_pattern, "file", 0);
            const size = try fontconfig.FcPatternGetDouble(fc_pattern, "size", 0);

            return .{
                .fc_pattern = fc_pattern,
                .fc_charset = fc_charset,

                .path = file,
                .size = @floatCast(size),
            };
        }

        pub fn deinit(self: FontIterator) void {
            fontconfig.FcFontSetDestroy(self.fc_font_set);
            fontconfig.FcPatternDestroy(self.fc_pattern);
        }
    };
};

pub const DirectWrite = struct {
    pub fn initIterator(library: Library, descriptor: Descriptor) InitError!FontIterator {
        _ = descriptor;

        const dw_font_collection = try library.impl.dw_factory.GetSystemFontCollection(false);
        errdefer dw_font_collection.Release();

        const font_family_len = dw_font_collection.GetFontFamilyCount();
        var font_family_i: windows.UINT32 = 0;

        while (font_family_i < font_family_len) : (font_family_i += 1) {
            const dw_font_family = try dw_font_collection.GetFontFamily(font_family_i);
            defer dw_font_family.Release();

            // seems we cant get path without making a face so im thinking make
            // path() func that would load our face and cache it 
            // and if like load() is called we will pop our cached face but hmmm
            // or idk dont expose path like just have load func cuz yea

            const names = try dw_font_family.GetFamilyNames();
            defer names.Release();

            assert(names.GetCount() > 0);
            
            const idx = names.FindLocaleName(unicode.wtf8ToWtf16LeStringLiteral("en-US")) catch |err| switch (err) {
                error.LocaleNameNotFound => 404, // just for debug
                else => |e| return e,
            };

            var wbuf: [256]u16 = undefined;

            const wstr_len = names.GetStringLength(idx);

            assert(wbuf.len > wstr_len);

            const name = wbuf[0..wstr_len:0];
            try names.GetString(idx, name);

            std.debug.print("n: {d}, {}\n", .{idx, unicode.fmtUtf16Le(name)});
        }

        return .{
            .dw_font_collection = dw_font_collection,
        };
    }

    pub const FontIterator = struct {
        dw_font_collection: *windows.IDWriteFontCollection,

        pub const Font = struct {

            path: [:0]const u8,
            size: f32,

            pub fn deinit(self: Font) void {
                _ = self;
            }

            pub inline fn hasCodepoint(self: Font, codepoint: u21) bool {
                _ = self;
                _ = codepoint;
                return false;
            }
        };

        pub fn next(self: *FontIterator) !?Font {
            _ = self;
            return null;
        }

        pub fn deinit(self: FontIterator) void {
            self.dw_font_collection.Release();
        }
    };
};

pub const Noop = struct {
    pub fn initIterator(library: Library, descriptor: Descriptor) InitError!FontIterator {
        _ = library;
        _ = descriptor;
        return .{};
    }

    pub const FontIterator = struct {
        pub const Font = struct {
            path: [:0]const u8,
            size: f32,

            pub fn deinit(self: Font) void {
                _ = self;
            }

            pub inline fn hasCodepoint(self: Font, codepoint: u21) bool {
                _ = self;
                _ = codepoint;
                return false;
            }
        };

        pub fn next(self: *FontIterator) !?Font {
            _ = self;
            return null;
        }

        pub fn deinit(self: FontIterator) void {
            _ = self;
        }
    };
};
