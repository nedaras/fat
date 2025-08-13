const std = @import("std");
const collection = @import("../collection.zig");
const fontconfig = @import("../fontconfig.zig");
const Allocator = std.mem.Allocator;

pub const DefferedFace = struct {
    fc_pattern: *fontconfig.FcPattern,

    pub fn family(self: DefferedFace) [:0]const u8 {
        // todo: figure out if its good todo it like this like can it error somehow
        return (fontconfig.FcPatternGetString(self.fc_pattern, "family", 0) catch unreachable).?;
    }

    pub fn deinit(self: DefferedFace) void {
        fontconfig.FcPatternDestroy(self.fc_pattern);
    }
};

pub const FontIterator = struct {
    fc_config: *fontconfig.FcConfig,
    fc_pattern: *fontconfig.FcPattern,
    fc_font_set: *fontconfig.FcFontSet,

    idx: c_uint,

    pub fn init(fc_config: *fontconfig.FcConfig, _: Allocator, descriptor: collection.Descriptor) !FontIterator {
        const fc_pattern = try fontconfig.FcPatternCreate();
        errdefer fontconfig.FcPatternDestroy(fc_pattern);

        if (descriptor.family) |family| {
            fontconfig.FcPatternAddString(fc_pattern, "falimy", family);
        }

        //if (descriptor.style) |style| {
            //fontconfig.FcPatternAddString(fc_pattern, "style", style);
        //}

        //if (descriptor.codepoint != 0) {
            //const charset = try fontconfig.FcCharSetCreate();
            //defer fontconfig.FcCharSetDestroy(charset);

            //fontconfig.FcCharSetAddChar(charset, descriptor.codepoint);
            //fontconfig.FcPatternAddCharSet(fc_pattern, "charset", charset);
        //}

        //if (descriptor.size != 0.0) {
            //fontconfig.FcPatternAddDouble(fc_pattern, "size", descriptor.size);
        //}

        fontconfig.FcConfigSubstitute(fc_config, fc_pattern, .FcMatchPattern);
        fontconfig.FcDefaultSubstitute(fc_pattern);

        // todo: we need to sort it alphabetic ordeer as that how it is in windows
        // but do we? we can idk have some of like caveats

        const fc_font_set = try fontconfig.FcFontSort(fc_config, fc_pattern, false, null);
        errdefer fontconfig.FcFontSetDestroy(fc_font_set);

        return .{
            .fc_config = fc_config,
            .fc_pattern = fc_pattern,
            .fc_font_set = fc_font_set,
            .idx = 0,
        };
    }

    pub fn deinit(self: FontIterator) void {
        fontconfig.FcFontSetDestroy(self.fc_font_set);
        fontconfig.FcPatternDestroy(self.fc_pattern);
    }

    pub fn next(self: *FontIterator) !?DefferedFace {
        if (self.idx == self.fc_font_set.nfont) {
            return null;
        }
        defer self.idx += 1;

        const fc_pattern = try fontconfig.FcFontRenderPrepare(self.fc_config, self.fc_pattern, self.fc_font_set.fonts[self.idx].?);
        errdefer fontconfig.FcPatternDestroy(fc_pattern);

        //const fc_charset = (try fontconfig.FcPatternGetCharSet(fc_pattern, "charset", 0)).?;

        //const family = (try fontconfig.FcPatternGetString(fc_pattern, "family", 0)).?;
        //const size = (try fontconfig.FcPatternGetDouble(fc_pattern, "size", 0)).?;

        //_ = fc_charset;
        //_ = family;
        //_ = size;

        return .{
            .fc_pattern = fc_pattern,
        };
    }
};
