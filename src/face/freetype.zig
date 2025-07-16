const std = @import("std");
const freetype = @import("../freetype.zig");
const harfbuzz = @import("../harfbuzz.zig");
const shared = @import("shared.zig");
const Library = @import("../Library.zig");
const Allocator = std.mem.Allocator;

// todo: make freetype threadsafe dwrite

pub const Face = struct {
    ft_face: freetype.FT_Face,
    hb_font: *harfbuzz.hb_font_t,

    size: shared.DesiredSize,

    pub fn openFace(library: Library, sub_path: [:0]const u8, options: shared.OpenFaceOptions) !Face {
        var ft_face: freetype.FT_Face = undefined;

        try freetype.FT_New_Face(library.impl.ft_library, sub_path, options.face_index, &ft_face);
        errdefer freetype.FT_Done_Face(ft_face);

        const hb_font = try harfbuzz.hb_ft_font_create_referenced(ft_face);
        errdefer harfbuzz.hb_font_destroy(hb_font);

        var res: Face = .{
            .ft_face = ft_face,
            .hb_font = hb_font,
            .size = undefined,
        };

        try res.setSize(options.size);
        return res;
    }

    pub fn close(self: Face) void {
        harfbuzz.hb_font_destroy(self.hb_font);
        freetype.FT_Done_Face(self.ft_face);
    }

    pub fn setSize(self: *Face, size: shared.DesiredSize) !void {
        self.size = size;

        if (!freetype.FT_IS_SCALABLE(self.ft_face)) {
            @branchHint(.cold);

            var i: i32 = 0;
            var best_i: i32 = 0;
            var best_diff: i32 = 0;
            while (i < self.ft_face.num_fixed_sizes) : (i += 1) {
                const width = self.ft_face.available_sizes[@intCast(i)].width;
                const diff = @as(i32, @intCast(size.pixels())) - @as(i32, @intCast(width));
                if (i == 0 or diff < best_diff) {
                    best_diff = diff;
                    best_i = i;
                }
            }

            return freetype.FT_Select_Size(self.ft_face, best_i);
        }

        const size_26dot6: i32 = @intFromFloat(@round(size.points * 64));
        return freetype.FT_Set_Char_Size(self.ft_face, 0, size_26dot6, size.xdpi, size.ydpi) catch |err| switch (err) {
            error.InvalidSize => unreachable,
            else => |e| e,
        };
    }

    pub inline fn gyphIndex(self: Face, codepoint: u21) ?u32 {
        return freetype.FT_Get_Char_Index(self.ft_face, codepoint);
    }

    pub fn glyphBoundingBox(self: Face, glyph_index: u32) !shared.GlyphBoundingBox {
        try freetype.FT_Load_Glyph(self.ft_face, glyph_index, .{});
        const bitmap = self.ft_face.glyph.bitmap;
        return .{
            .width = bitmap.width,
            .height = bitmap.rows,
        };
    }

    // todo: add options for colors and stuff
    // idk maybe its possible to directly copy into bitmap not needing like 2 allocations
    pub fn renderGlyph(self: Face, allocator: Allocator, glyph_index: u32) !shared.GlyphRender {
        try freetype.FT_Load_Glyph(self.ft_face, glyph_index, .{ .render = true });
        const bitmap = self.ft_face.glyph.bitmap;

        if (bitmap.pitch != bitmap.width) {
            @panic("not handling bitmap fonts");
        }

        return .{
            .width = bitmap.width,
            .height = bitmap.rows,
            .bitmap = try allocator.dupe(u8, bitmap.buffer[0 .. bitmap.rows * @abs(bitmap.pitch)]),
        };
    }
};
