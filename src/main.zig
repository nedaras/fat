const std = @import("std");
const freetype = @import("freetype");
const fs = std.fs;
const mem = std.mem;
const sort = std.sort;

const Header = extern struct {
    glyphs_len: u16,
    tex_width: u16,
    tex_height: u16,
};

const Glyph = extern struct {
    unicode: u32,
    width: u8,
    height: u8,
    bearing_x: i8,
    bearing_y: i8,
    advance: u8,
    off_x: u16,
    off_y: u16,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const lib = try freetype.Library.init();
    defer lib.deinit();

    const face = try lib.createFace("/home/nedas/Downloads/SimSun.ttf", 0);
    defer face.deinit();

    const font_size = 16;
    try face.setPixelSizes(0, font_size);

    var tex_width: usize = 0;
    var tex_height: usize = 0;

    var glyphs_len: u16 = 0;

    var it = face.iterateCharmap();
    while (it.next()) |unicode| {
        const idx = face.getCharIndex(unicode) orelse continue;

        try face.loadGlyph(idx, .{});

        const glyph = face.glyph();
        const bitmap = glyph.bitmap();

        tex_width += bitmap.width();
        tex_height = @max(tex_height, bitmap.rows());

        glyphs_len += 1;
    }

    std.debug.print("{}\n", .{glyphs_len});

    const tex = try allocator.alloc(u8, tex_width * tex_height);
    defer allocator.free(tex);

    @memset(tex, 0);

    const glyphs = try allocator.alloc(Glyph, glyphs_len);
    defer allocator.free(glyphs);

    var off_x: usize = 0;
    var i: u16 = 0;

    it = face.iterateCharmap();
    while (it.next()) |unicode| : (i += 1) {
        const idx = face.getCharIndex(unicode) orelse continue;

        try face.loadGlyph(idx, .{ .render = true, .target_normal = true });

        const glyph = face.glyph();
        const metrics = glyph.metrics();

        const bitmap = glyph.bitmap();
        defer off_x += bitmap.width();

        const bearing_x: i8 = @intCast(metrics.horiBearingX >> 6);
        const bearing_y: i8 = font_size - @as(i8, @intCast(metrics.horiBearingY >> 6));

        const advance: u8 = @intCast(glyph.advance().x >> 6);

        if (bitmap.pixelMode() != .gray) {
            std.debug.print("naxui\n", .{});
            continue;
        }

        glyphs[i] = .{
            .unicode = unicode,
            .width = @intCast(bitmap.width()),
            .height = @intCast(bitmap.rows()),
            .bearing_x = bearing_x,
            .bearing_y = bearing_y,
            .advance = advance,
            .off_x = @intCast(off_x),
            .off_y = 0,
        };

        //std.debug.print("{}\n", .{bitmap.pixelMode()});


        const buf = bitmap.buffer() orelse continue;
        for (0..bitmap.rows()) |y| {
            for (0..bitmap.width()) |x| {
                const src = buf[y * bitmap.width() + x];
                const dst = &tex[y * tex_width + (off_x + x)];

                dst.* = src;
            }
        }
    }

    const asc = struct {
        fn inner(_: void, a: Glyph, b: Glyph) bool {
            return a.unicode < b.unicode;
        }
    }.inner;

    sort.block(Glyph, glyphs, {}, asc);

    const head = Header{
        .glyphs_len = glyphs_len,
        .tex_width = @intCast(tex_width),
        .tex_height = @intCast(tex_height),
    };

    const fat = try fs.cwd().createFile("out.fat", .{});
    defer fat.close();

    std.debug.print("{d}x{d}\n", .{tex_width, tex_height});

    try fat.writeAll(mem.asBytes(&head));
    try fat.writeAll(mem.sliceAsBytes(glyphs));
    try fat.writeAll(tex);
}

test {
    const fat = try fs.cwd().openFile("out.fat", .{});
    defer fat.close();

    const reader = fat.reader();

    const head = try reader.readStructEndian(Header, .little);
    for (0..head.glyphs_len) |_| {
        const glyph = try reader.readStructEndian(Glyph, .little);
        _ = glyph;
    }

    try reader.skipBytes(@as(u32, head.tex_width) * @as(u32, head.tex_height), .{});
}
