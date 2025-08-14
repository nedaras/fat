const std = @import("std");
const windows = @import("../windows.zig");
const collection = @import("../collection.zig");
const Face = @import("../face/directwrite.zig").Face;
const assert = std.debug.assert;
const unicode = std.unicode;
const mem = std.mem;
const Allocator = mem.Allocator;

pub const DefferedFace = struct {
    dw_font: *windows.IDWriteFont,

    allocator: Allocator,
    family_name: [:0]u8,

    pub fn deinit(self: DefferedFace) void {
        self.allocator.free(self.family_name);
        self.dw_font.Release();
    }

    pub inline fn family(self: DefferedFace) [:0]const u8 {
        return self.family_name;
    }

    pub inline fn hasCodepoint(self: DefferedFace, codepoint: u21) bool {
        return self.dw_font.HasCharacter(codepoint);
    }
};

pub const FontIterator = struct {
    dw_font_collection: *windows.IDWriteFontCollection,

    allocator: Allocator,
    dw_fonts: []*windows.IDWriteFont,

    idx: usize,

    const Score = packed struct {
        const Backing = @typeInfo(@This()).@"struct".backing_integer.?;

        codepoint: bool = false,
        family: bool = false,
    };

    pub fn init(dw_factory: *windows.IDWriteFactory, allocator: Allocator, descriptor: collection.Descriptor) !FontIterator {
        const dw_font_collection = try dw_factory.GetSystemFontCollection(false);
        errdefer dw_font_collection.Release();

        const family_count = dw_font_collection.GetFontFamilyCount();
        const deffered_faces_len = blk: {
            var len: usize = 0;
            var idx: windows.UINT32 = 0;

            while (idx < family_count) : (idx += 1) {
                const dw_font_family = try dw_font_collection.GetFontFamily(idx);
                defer dw_font_family.Release();

                len += dw_font_family.GetFontCount();
            }

            break :blk len;
        };

        var idx: usize = 0;

        const dw_fonts = try allocator.alloc(*windows.IDWriteFont, deffered_faces_len);
        errdefer {
            for (dw_fonts[0..idx]) |dw_font| {
                dw_font.Release();
            }
            allocator.free(dw_fonts);
        }

        var family_idx: windows.UINT32 = 0;
        while (family_idx < family_count) : (family_idx += 1) {
            const dw_font_family = try dw_font_collection.GetFontFamily(family_idx);
            defer dw_font_family.Release();

            const font_len = dw_font_family.GetFontCount();
            var font_idx: windows.UINT32 = 0;

            while (font_idx < font_len) : (font_idx += 1) {
                dw_fonts[idx] = try dw_font_family.GetFont(font_idx);
                idx += 1;
            }
        }

        if (descriptor.family) |family| {
            if (!unicode.wtf8ValidateSlice(family)) {
                return error.InvalidWtf8;
            }
        }

        std.sort.pdq(*windows.IDWriteFont, dw_fonts, descriptor, struct {
            fn lessThan(desc: collection.Descriptor, a: *windows.IDWriteFont, b: *windows.IDWriteFont) bool {
                return score(a, desc) > score(b, desc);
            }
        }.lessThan);

        return .{
            .dw_font_collection = dw_font_collection,
            .allocator = allocator,
            .dw_fonts = dw_fonts,
            .idx = 0,
        };
    }

    pub fn deinit(self: FontIterator) void {
        for (self.dw_fonts[self.idx..]) |dw_font| {
            dw_font.Release();
        }

        self.allocator.free(self.dw_fonts);
        self.dw_font_collection.Release();
    }

    pub fn next(self: *FontIterator) !?DefferedFace {
        if (self.idx == self.dw_fonts.len) {
            return null;
        }

        defer self.idx += 1;

        const dw_font = self.dw_fonts[self.idx];
        errdefer dw_font.Release();

        const dw_font_family = try dw_font.GetFontFamily();
        defer dw_font_family.Release();

        const dw_family_names = try dw_font_family.GetFamilyNames();
        defer dw_family_names.Release();

        assert(dw_family_names.GetCount() > 0);

        const dw_family_names_idx = dw_family_names.FindLocaleName(unicode.wtf8ToWtf16LeStringLiteral("en-US")) catch |err| switch (err) {
            error.LocaleNameNotFound => 0,
            else => |e| return e,
        };

        var wtf16_buf: [256]u16 = undefined;
        const wtf16_family_name = dw_family_names.GetString(dw_family_names_idx, &wtf16_buf) catch |err| return switch (err) {
            error.BufferTooSmall => @panic("TODO"), // just alloc that buffer temp
            else => |e| e,
        };

        // i can use std::string here like alot of family names are less then 16 chars, so we would not even need to allocate it

        const wtf8_family_name = try unicode.wtf16LeToWtf8AllocZ(self.allocator, wtf16_family_name);
        errdefer self.allocator.free(wtf8_family_name);

        return .{
            .dw_font = dw_font,
            .allocator = self.allocator,
            .family_name = wtf8_family_name,
        };
    }

    fn score(dw_font: *windows.IDWriteFont, descriptor: collection.Descriptor) Score.Backing {
        var self: Score = .{};

        if (descriptor.family) |wtf8_family_name| blk: {
            // todo: i need to check refs of these objects as probs it just has it in some array so like it cant even error
            const dw_font_family = dw_font.GetFontFamily() catch @panic("blow up");
            defer dw_font_family.Release();

            const dw_family_names = dw_font_family.GetFamilyNames() catch @panic("blow up");
            defer dw_family_names.Release();

            assert(dw_family_names.GetCount() > 0);

            const dw_family_names_idx = dw_family_names.FindLocaleName(unicode.wtf8ToWtf16LeStringLiteral("en-US")) catch |err| switch (err) {
                error.LocaleNameNotFound => 0,
                else => @panic("blow up"),
            };

            var wtf16_buf: [256]u16 = undefined;
            const wtf16_family_name = dw_family_names.GetString(dw_family_names_idx, &wtf16_buf) catch |err| return switch (err) {
                error.BufferTooSmall => @panic("TODO"),
                else => @panic("blow up"),
            };

            // todo: benchmark this as i think converting wtf8 to wtf16 and doing mem.eql would be faster
            if (wtf8_family_name.len == wtf16_family_name.len) {
                assert(unicode.wtf8ValidateSlice(wtf8_family_name));

                var wtf8_it = unicode.Wtf8Iterator{ .bytes = wtf8_family_name, .i = 0 };
                var wtf16_it = unicode.Wtf16LeIterator{ .bytes = mem.sliceAsBytes(wtf16_family_name), .i = 0 };

                while (true) {
                    const a = wtf8_it.nextCodepoint() orelse break;
                    const b = wtf16_it.nextCodepoint().?;

                    if (a != b) {
                        break :blk;
                    }
                }
                self.family = true;
            }
        }

        if (descriptor.codepoint != 0) {
            self.codepoint = dw_font.HasCharacter(descriptor.codepoint);
        }

        return @bitCast(self);
    }
};
