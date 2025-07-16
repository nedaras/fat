const std = @import("std");
const windows = @import("../windows.zig");
const harfbuzz = @import("../harfbuzz.zig");
const shared = @import("shared.zig");
const Library = @import("../Library.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

pub const Face = struct {
    library: Library,

    dw_face: *windows.IDWriteFontFace,
    hb_font: *harfbuzz.hb_font_t,

    size: shared.DesiredSize,

    pub fn openFace(library: Library, sub_path: [:0]const u8, options: shared.OpenFaceOptions) !Face {
        var tmp_path: windows.PathSpace = undefined;
        tmp_path.len = try std.unicode.wtf8ToWtf16Le(&tmp_path.data, sub_path);
        tmp_path.data[tmp_path.len] = 0;

        const font_file = library.impl.dw_factory.CreateFontFileReference(tmp_path.span(), null) catch |err| return switch (err) {
            error.FontNotFound, error.AccessDenied => error.FailedToOpen,
            else => |e| e,
        };
        defer font_file.Release();

        var file_type: windows.DWRITE_FONT_FILE_TYPE = undefined;
        var face_type: windows.DWRITE_FONT_FACE_TYPE = undefined;

        var faces: u32 = undefined;

        try font_file.Analyze(&file_type, &face_type, &faces);

        const dw_face = try library.impl.dw_factory.CreateFontFace(face_type, &.{font_file}, options.face_index, .DWRITE_FONT_SIMULATIONS_NONE);
        errdefer dw_face.Release();

        const hb_font = try harfbuzz.hb_directwrite_font_create(dw_face);
        errdefer harfbuzz.hb_font_destroy(hb_font);

        return .{
            .library = library,
            .dw_face = dw_face,
            .hb_font = hb_font,
            .size = options.size,
        };
    }

    pub fn close(self: Face) void {
        harfbuzz.hb_font_destroy(self.hb_font);
        self.dw_face.Release();
    }

    pub fn setSize(self: *Face, size: shared.DesiredSize) !void {
        self.size = size;
    }

    pub fn gyphIndex(self: Face, codepoint: u21) ?u32 {
        const codepoints = [1]windows.UINT32{codepoint};
        var indicies = [1]windows.UINT16{0};

        self.dw_face.GetGlyphIndices(&codepoints, &indicies);

        return if (indicies[0] == 0) null else indicies[0];
    }

    pub fn glyphBoundingBox(self: Face, glyph_index: u32) !shared.GlyphBoundingBox {
        const matrix = &windows.DWRITE_MATRIX{
            .m11 = 1.0,
            .m12 = 0.0,
            .m21 = 0.0,
            .m22 = 1.0,
            .dx = 0.0,
            .dy = 0.0,
        };

        const indicies = [1]windows.UINT16{@intCast(glyph_index)};

        const glyph_run = windows.DWRITE_GLYPH_RUN{
            .fontFace = self.dw_face,
            .fontEmSize = @floatFromInt(self.size.pixels()),
            .glyphCount = 1,
            .glyphIndices = &indicies,
            .glyphAdvances = null,
            .glyphOffsets = null,
            .isSideways = windows.FALSE,
            .bidiLevel = 0,
        };

        const run_analysis = try self.library.impl.dw_factory.CreateGlyphRunAnalysis(
            &glyph_run,
            1.0,
            matrix,
            .DWRITE_RENDERING_MODE_NATURAL,
            .DWRITE_MEASURING_MODE_NATURAL,
            0.0,
            0.0,
        );
        defer run_analysis.Release();

        const bounds = try run_analysis.GetAlphaTextureBounds(.DWRITE_TEXTURE_CLEARTYPE_3x1);

        return .{
            .width = @intCast(bounds.right - bounds.left),
            .height = @intCast(bounds.bottom - bounds.top),
        };
    }

    pub fn renderGlyph(self: Face, allocator: Allocator, glyph_index: u32) !shared.GlyphRender {
        const matrix = &windows.DWRITE_MATRIX{
            .m11 = 1.0,
            .m12 = 0.0,
            .m21 = 0.0,
            .m22 = 1.0,
            .dx = 0.0,
            .dy = 0.0,
        };

        const indicies = [1]windows.UINT16{@intCast(glyph_index)};

        const glyph_run = windows.DWRITE_GLYPH_RUN{
            .fontFace = self.dw_face,
            .fontEmSize = @floatFromInt(self.size.pixels()),
            .glyphCount = 1,
            .glyphIndices = &indicies,
            .glyphAdvances = null,
            .glyphOffsets = null,
            .isSideways = windows.FALSE,
            .bidiLevel = 0,
        };

        const run_analysis = try self.library.impl.dw_factory.CreateGlyphRunAnalysis(
            &glyph_run,
            1.0,
            matrix,
            .DWRITE_RENDERING_MODE_NATURAL,
            .DWRITE_MEASURING_MODE_NATURAL,
            0.0,
            0.0,
        );
        defer run_analysis.Release();

        const bounds = try run_analysis.GetAlphaTextureBounds(.DWRITE_TEXTURE_CLEARTYPE_3x1);

        const width: u32 = @intCast(bounds.right - bounds.left);
        const height: u32 = @intCast(bounds.bottom - bounds.top);

        const bitmap_len = @as(usize, @intCast(width)) * @as(usize, @intCast(height));

        const bitmap = try allocator.alloc(u8, bitmap_len * 3);
        errdefer allocator.free(bitmap);

        try run_analysis.CreateAlphaTexture(.DWRITE_TEXTURE_CLEARTYPE_3x1, &bounds, bitmap);

        for (0..bitmap_len) |i| {
            const r: f32 = @floatFromInt(bitmap[i * 3 + 0]);
            const g: f32 = @floatFromInt(bitmap[i * 3 + 1]);
            const b: f32 = @floatFromInt(bitmap[i * 3 + 2]);

            bitmap[i] = @intFromFloat(r * 0.2989 + g * 0.587 + b * 0.114);
        }

        assert(allocator.resize(bitmap, bitmap_len));

        return .{
            .width = width,
            .height = height,
            .bitmap = bitmap,
        };
    }
};
