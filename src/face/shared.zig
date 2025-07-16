const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

pub const default_dpi = if (builtin.os.tag == .macos) 72 else 96;

pub const GlyphRender = struct {
    width: u32,
    height: u32,

    // harfbuzz should give this to us in shaper or smth
    //offset_x: u16,
    //offset_y: u16,

    bitmap: []u8,

    pub const C = extern struct {
        width: u32,
        height: u32,

        bitmap: [*]u8,
    };

    pub fn deinit(self: GlyphRender, allocator: Allocator) void {
        allocator.free(self.bitmap);
    }
};

pub const GlyphBoundingBox = struct {
    width: u32,
    height: u32,

    pub const C = extern struct {
        width: u32,
        height: u32,
    };
};

/// The desired size for loading a font.
pub const DesiredSize = struct {
    // Desired size in points
    points: f32,

    // The DPI of the screen so we can convert points to pixels.
    xdpi: u16 = default_dpi,
    ydpi: u16 = default_dpi,

    // Converts points to pixels
    pub fn pixels(self: DesiredSize) u16 {
        // 1 point = 1/72 inch
        return @intFromFloat(@round((self.points * @as(f32, @floatFromInt(self.ydpi))) / 72));
    }
};

pub const OpenFaceOptions = struct {
    size: DesiredSize,
    face_index: u32 = 0,

    pub const C = extern struct {
        size: f32,
        face_index: u32,
    };
};
