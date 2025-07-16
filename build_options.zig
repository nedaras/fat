const std = @import("std");
const options = @import("build_options");

pub const font_backend = std.meta.stringToEnum(FontBackend, @tagName(options.font_backend)).?;

pub const FontBackend = enum {
    Directwrite,
    Freetype,

    pub fn default(target: std.Target) FontBackend {
        return if (target.os.tag == .windows) .Directwrite else .Freetype;
    }

    pub fn hasFreetype(self: FontBackend) bool {
        return switch (self) {
            .Directwrite => false,
            .Freetype => true,
        };
    }
};
