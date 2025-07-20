const std = @import("std");
const build_options = @import("build_options");
const windows = @import("windows.zig");
const fontconfig = @import("fontconfig.zig");
const Library = @import("Library.zig");
const mem = std.mem;
const math = std.math;
const unicode = std.unicode;
const assert = std.debug.assert;
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
pub const GenericFontIterator = switch (build_options.font_backend) {
    .FontconfigFreetype => FontConfig.FontIterator,
    .Directwrite => DirectWrite.FontIterator,
    .Freetype => Noop.FontIterator,
};

pub inline fn initIterator(allocator: Allocator, library: Library, descriptor: Descriptor) InitError!GenericFontIterator {
    return switch (build_options.font_backend) {
        .FontconfigFreetype => FontConfig.initIterator(allocator, library, descriptor),
        .Directwrite => DirectWrite.initIterator(allocator, library, descriptor),
        .Freetype => Noop.initIterator(allocator, library, descriptor),
    };
}

pub const FontConfig = struct {
    pub fn initIterator(_: Allocator, library: Library, descriptor: Descriptor) InitError!FontIterator {
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

            family: [:0]const u8,
            size: f32,

            weight: FontWeight,
            slant: FontSlant,

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

            const fc_charset = (try fontconfig.FcPatternGetCharSet(fc_pattern, "charset", 0)).?;

            const family = (try fontconfig.FcPatternGetString(fc_pattern, "family", 0)).?;
            const size = (try fontconfig.FcPatternGetDouble(fc_pattern, "size", 0)).?;

            const fc_weight: fontconfig.FcWeight = fontconfig.nearestWeight((try fontconfig.FcPatternGetInteger(fc_pattern, "weight", 0)).?) catch unreachable;
            const fc_slant: fontconfig.FcSlant = @enumFromInt((try fontconfig.FcPatternGetInteger(fc_pattern, "slant", 0)).?);

            const weight: FontWeight = switch (fc_weight) {
                .FC_WEIGHT_THIN => .thin,
                .FC_WEIGHT_EXTRALIGHT,
                .FC_WEIGHT_ULTRALIGHT => .extralight,
                .FC_WEIGHT_LIGHT => .light,
                .FC_WEIGHT_DEMILIGHT,
                .FC_WEIGHT_SEMILIGHT => .semilight,
                .FC_WEIGHT_BOOK => .book,
                .FC_WEIGHT_REGULAR,
                .FC_WEIGHT_NORMAL =>  .regular,
                .FC_WEIGHT_MEDIUM => .medium,
                .FC_WEIGHT_DEMIBOLD,
                .FC_WEIGHT_SEMIBOLD => .demibold,
                .FC_WEIGHT_BOLD => .bold,
                .FC_WEIGHT_EXTRABOLD,
                .FC_WEIGHT_ULTRABOLD => .extrabold,
                .FC_WEIGHT_BLACK,
                .FC_WEIGHT_HEAVY => .black,
                .FC_WEIGHT_EXTRABLACK,
                .FC_WEIGHT_ULTRABLACK => .extrablack,
            };

            const slant: FontSlant = switch (fc_slant) {
                .FC_SLANT_ROMAN => .roman,
                .FC_SLANT_ITALIC => .italic,
                .FC_SLANT_OBLIQUE => .oblique,
            };

            return .{
                .fc_pattern = fc_pattern,
                .fc_charset = fc_charset,

                .family = family,
                .size = @floatCast(size),
                .weight = weight,
                .slant = slant,
            };
        }

        pub fn deinit(self: FontIterator) void {
            fontconfig.FcFontSetDestroy(self.fc_font_set);
            fontconfig.FcPatternDestroy(self.fc_pattern);
        }
    };
};

// TODO: first we clean this shit up and then we can move on
// cuz this is fucking hell

pub const DirectWrite = struct {
    pub fn initIterator(allocator: Allocator, library: Library, descriptor: Descriptor) InitError!FontIterator {
        _ = descriptor;

        const dw_font_collection = try library.impl.dw_factory.GetSystemFontCollection(false);
        errdefer dw_font_collection.Release();

        const family_count = dw_font_collection.GetFontFamilyCount();

        var family_names: std.ArrayList(u8) = .init(allocator);
        defer family_names.deinit();

        var family_index: windows.UINT32 = 0;
        while (family_index < family_count) : (family_index += 1) {
            const dw_font_family = try dw_font_collection.GetFontFamily(family_index);
            defer dw_font_family.Release(); 

            const dw_family_names = try dw_font_family.GetFamilyNames();
            defer dw_family_names.Release();

            assert(dw_family_names.GetCount() > 0);

            const index = dw_family_names.FindLocaleName(unicode.wtf8ToWtf16LeStringLiteral("en-US")) catch |err| switch (err) {
                error.LocaleNameNotFound => 0, 
                else => |e| return e,
            };

            const family_name_len = dw_family_names.GetStringLength(index);
            var wtf16_buf: [256]u16 = undefined;

            if (family_name_len + 1 > wtf16_buf.len) {
                @panic("yikes");
            }

            _ = dw_family_names.GetString(index, &wtf16_buf) catch |err| return switch(err) {
                error.BufferTooSmall => unreachable,
                else => |e| e,
            };

            const wtf16_family_name = wtf16_buf[0..family_name_len + 1];

            const wtf8_len = unicode.calcWtf8Len(wtf16_family_name);

            try family_names.ensureUnusedCapacity(wtf8_len);
            assert(unicode.wtf16LeToWtf8(family_names.unusedCapacitySlice(), wtf16_family_name) == wtf8_len);

            family_names.items.len += wtf8_len;
        }

        return .{
            .dw_font_collection = dw_font_collection,
            .allocator = allocator,
            .family_names_buf = try family_names.toOwnedSlice(),
            .family_names_idx = 0,
            .count = family_count,
            .idx = 0,
        };
    }

    pub const FontIterator = struct {
        dw_font_collection: *windows.IDWriteFontCollection,

        allocator: Allocator,

        family_names_buf: []u8,
        family_names_idx: usize,

        count: usize,
        idx: usize,

        pub const Font = struct {
            family: [:0]const u8,
            size: f32,

            weight: FontWeight,
            slant: FontSlant,

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
            if (self.count == self.idx) {
                return null;
            }

            defer self.idx += 1;
            
            assert(@mod(self.family_names_idx, 2) == 0);

            const slice_ptr: [*:0]u8 = @ptrCast(&self.family_names_buf[self.family_names_idx]);
            const family = mem.span(slice_ptr);

            self.family_names_idx += family.len + 1;

            return .{
                .family = family,
                .size = 0.0,
                .weight = .book,
                .slant = .roman,
            };
        }

        pub fn deinit(self: FontIterator) void {
            self.allocator.free(self.family_names_buf);
            self.dw_font_collection.Release();
        }
    };
};

pub const Noop = struct {
    pub fn initIterator(_: Allocator, library: Library, descriptor: Descriptor) InitError!FontIterator {
        _ = library;
        _ = descriptor;
        return .{};
    }

    pub const FontIterator = struct {
        pub const Font = struct {
            family: [:0]const u8,
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
