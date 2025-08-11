const std = @import("std");
const windows = @import("../windows.zig");
const Library = @import("../library.zig");
const collection = @import("../collection.zig");
const assert = std.debug.assert;
const unicode = std.unicode;
const mem = std.mem;
const Allocator = mem.Allocator;

pub fn initIterator(allocator: Allocator, library: *windows.IDWriteFactory, descriptor: collection.Descriptor) !FontIterator {
    const dw_font_collection = try library.impl.dw_factory.GetSystemFontCollection(false);
    errdefer dw_font_collection.Release();

    const family_count = dw_font_collection.GetFontFamilyCount();

    var wtf16_family_name_buf: [256]u16 = undefined;

    var wtf8_family_names_len: usize = 0;
    var fonts_len: usize = 0;

    {
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

            const wtf16_family_name = dw_family_names.GetString(index, &wtf16_family_name_buf) catch |err| return switch (err) {
                error.BufferTooSmall => @panic("TODO"),
                else => |e| e,
            };

            wtf8_family_names_len += unicode.calcWtf8Len(wtf16_family_name) + 1;
            fonts_len += dw_font_family.GetFontCount();
        }
    }

    var family_index: windows.UINT32 = 0;
    var font_index: windows.UINT32 = 0;
    var wtf8_family_names_offset: usize = 0;

    const wtf8_family_names_buf = try allocator.alloc(u8, wtf8_family_names_len);
    errdefer allocator.free(wtf8_family_names_buf);

    var fonts = try allocator.alloc(FontIterator.Font, fonts_len);
    errdefer {
        for (0..font_index) |i| {
            fonts[i].dw_font.Release();
        }
        allocator.free(fonts);
    }

    while (family_index < family_count) : (family_index += 1) {
        const dw_font_family = try dw_font_collection.GetFontFamily(family_index);
        defer dw_font_family.Release();

        const dw_family_names = try dw_font_family.GetFamilyNames();
        defer dw_family_names.Release();

        const index = dw_family_names.FindLocaleName(unicode.wtf8ToWtf16LeStringLiteral("en-US")) catch |err| switch (err) {
            error.LocaleNameNotFound => 0,
            else => |e| return e,
        };

        const family_name = dw_family_names.GetString(index, &wtf16_family_name_buf) catch |err| return switch (err) {
            error.BufferTooSmall => unreachable,
            else => |e| e,
        };

        const wtf16_family_name = wtf16_family_name_buf[0 .. family_name.len + 1];
        const wtf8_family_name_len = unicode.wtf16LeToWtf8(wtf8_family_names_buf[wtf8_family_names_offset..], wtf16_family_name);
        const wtf8_family_name = wtf8_family_names_buf[wtf8_family_names_offset .. wtf8_family_names_offset + wtf8_family_name_len - 1 :0];

        wtf8_family_names_offset += wtf8_family_name_len;

        for (0..dw_font_family.GetFontCount()) |i| {
            const dw_font = try dw_font_family.GetFont(@intCast(i));
            defer font_index += 1;

            const dw_weight = windows.nearestWeight(dw_font.GetWeight()) catch return error.Unexpected;
            const weight: collection.FontWeight = switch (dw_weight) {
                .DWRITE_FONT_WEIGHT_THIN => .thin,
                .DWRITE_FONT_WEIGHT_EXTRA_LIGHT => .extralight,
                .DWRITE_FONT_WEIGHT_LIGHT => .light,
                .DWRITE_FONT_WEIGHT_SEMI_LIGHT => .semilight,
                .DWRITE_FONT_WEIGHT_NORMAL => .regular,
                .DWRITE_FONT_WEIGHT_MEDIUM => .medium,
                .DWRITE_FONT_WEIGHT_DEMI_BOLD => .demibold,
                .DWRITE_FONT_WEIGHT_BOLD => .bold,
                .DWRITE_FONT_WEIGHT_EXTRA_BOLD => .extrabold,
                .DWRITE_FONT_WEIGHT_BLACK => .black,
                .DWRITE_FONT_WEIGHT_EXTRA_BLACK => .extrablack,
            };

            const slant: collection.FontSlant = switch (dw_font.GetStyle()) {
                .DWRITE_FONT_STYLE_NORMAL => .roman,
                .DWRITE_FONT_STYLE_OBLIQUE => .oblique,
                .DWRITE_FONT_STYLE_ITALIC => .italic,
            };

            fonts[font_index] = .{
                .family = wtf8_family_name,
                .size = 0.0,
                .weight = weight,
                .slant = slant,
                .dw_font = dw_font,
            };
        }
    }

    assert(fonts_len == font_index);

    const Context = struct {
        descriptor: collection.Descriptor,

        pub fn lessThan(ctx: @This(), a: FontIterator.Font, b: FontIterator.Font) bool {
            return score(a, ctx.descriptor) > score(b, ctx.descriptor);
        }
    };

    std.sort.block(FontIterator.Font, fonts, Context{ .descriptor = descriptor }, Context.lessThan);

    return .{
        .dw_font_collection = dw_font_collection,
        .allocator = allocator,
        .fonts = fonts,
        .family_names = wtf8_family_names_buf,
        .count = fonts_len,
        .idx = 0,
    };
}

const Score = packed struct {
    const Backing = @typeInfo(@This()).@"struct".backing_integer.?;

    codepoint: bool = false,
    family: bool = false,
    weight: bool = false,
    slant: bool = false,
};

fn score(font: FontIterator.Font, descriptor: collection.Descriptor) Score.Backing {
    var self: Score = .{};

    if (descriptor.codepoint != 0) {
        self.codepoint = font.hasCodepoint(descriptor.codepoint);
    }

    if (descriptor.family) |family| {
        self.family = mem.eql(u8, family, font.family);
    }

    return @bitCast(self);
}

pub const FontIterator = struct {
    dw_font_collection: *windows.IDWriteFontCollection,

    allocator: Allocator,

    fonts: []Font,
    family_names: []u8,

    count: usize,
    idx: usize,

    pub const Font = struct {
        family: [:0]const u8,
        size: f32,

        weight: collection.FontWeight,
        slant: collection.FontSlant,

        dw_font: *windows.IDWriteFont,

        pub inline fn deinit(self: Font) void {
            self.dw_font.Release();
        }

        pub inline fn hasCodepoint(self: Font, codepoint: u21) bool {
            return self.dw_font.HasCharacter(codepoint);
        }
    };

    pub fn next(self: *FontIterator) !?Font {
        if (self.count == self.idx) {
            return null;
        }

        defer self.idx += 1;
        return self.fonts[self.idx];
    }

    pub fn deinit(self: FontIterator) void {
        for (self.idx..self.count) |i| {
            self.fonts[i].dw_font.Release();
        }

        self.allocator.free(self.fonts);
        self.allocator.free(self.family_names);
        self.dw_font_collection.Release();
    }
};
