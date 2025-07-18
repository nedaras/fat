const std = @import("std");
const options = @import("build_options");

pub const font_backend = std.meta.stringToEnum(FontBackend, @tagName(options.font_backend)).?;

pub const FontBackend = enum {
    Directwrite,
    Freetype,
    FontconfigFreetype,

    pub fn default(target: std.Target) FontBackend {
        return if (target.os.tag == .windows) .Directwrite else .FontconfigFreetype;
    }

    pub inline fn hasFreetype(self: FontBackend) bool {
        return switch (self) {
            .Freetype,
            .FontconfigFreetype => true,
            .Directwrite => false,
        };
    }

    pub inline fn hasDirectWrite(self: FontBackend) bool {
        return self == .Directwrite;
    }

    pub inline fn hasFontConfig(self: FontBackend) bool {
        return self == .FontconfigFreetype;
    }
};
