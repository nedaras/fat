const std = @import("std");
const collection = @import("../collection.zig");
const fontconfig = @import("../fontconfig.zig");
const Library = @import("../Library.zig");
const mem = std.mem;
const Allocator = mem.Allocator;

pub fn initIterator(_: Allocator, library: Library, descriptor: collection.Descriptor) !FontIterator {
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
        family: [:0]const u8,
        size: f32,

        weight: collection.FontWeight,
        slant: collection.FontSlant,

        fc_pattern: *fontconfig.FcPattern,
        fc_charset: *const fontconfig.FcCharSet,

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

        const fc_weight: fontconfig.FcWeight = fontconfig.nearestWeight((try fontconfig.FcPatternGetInteger(fc_pattern, "weight", 0)).?) catch return error.Unexpected;
        const fc_slant: fontconfig.FcSlant = @enumFromInt((try fontconfig.FcPatternGetInteger(fc_pattern, "slant", 0)).?); // todo: return unexpected if invalid

        const weight: collection.FontWeight = switch (fc_weight) {
            .FC_WEIGHT_THIN => .thin,
            .FC_WEIGHT_EXTRALIGHT => .extralight,
            .FC_WEIGHT_LIGHT => .light,
            .FC_WEIGHT_SEMILIGHT => .semilight,
            .FC_WEIGHT_BOOK => .book,
            .FC_WEIGHT_REGULAR => .regular,
            .FC_WEIGHT_MEDIUM => .medium,
            .FC_WEIGHT_DEMIBOLD => .demibold,
            .FC_WEIGHT_BOLD => .bold,
            .FC_WEIGHT_EXTRABOLD => .extrabold,
            .FC_WEIGHT_BLACK => .black,
            .FC_WEIGHT_EXTRABLACK => .extrablack,
        };

        const slant: collection.FontSlant = switch (fc_slant) {
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
