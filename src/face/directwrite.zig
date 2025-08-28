const std = @import("std");
const windows = @import("../windows.zig");
const shared = @import("shared.zig");
const DefferedFace = @import("../collection/directwrite.zig").DefferedFace;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

pub const Face = struct {
    dw_factory: *windows.IDWriteFactory,
    dw_face: *windows.IDWriteFontFace,

    size: shared.DesiredSize,

    pub fn openFace(dw_factory: *windows.IDWriteFactory, sub_path: [:0]const u8, options: shared.OpenFaceOptions) !Face {
        var tmp_path: windows.PathSpace = undefined;
        tmp_path.len = try std.unicode.wtf8ToWtf16Le(&tmp_path.data, sub_path);
        tmp_path.data[tmp_path.len] = 0;

        const font_file = dw_factory.CreateFontFileReference(tmp_path.span(), null) catch |err| return switch (err) {
            error.FontNotFound, error.AccessDenied => error.FailedToOpen,
            else => |e| e,
        };
        defer font_file.Release();

        var file_type: windows.DWRITE_FONT_FILE_TYPE = undefined;
        var face_type: windows.DWRITE_FONT_FACE_TYPE = undefined;

        var faces: u32 = undefined;

        try font_file.Analyze(&file_type, &face_type, &faces);

        const dw_face = try dw_factory.CreateFontFace(face_type, &.{font_file}, options.face_index, .DWRITE_FONT_SIMULATIONS_NONE);
        errdefer dw_face.Release();

        return .{
            .library = dw_factory,
            .dw_face = dw_face,
            .size = options.size,
        };
    }

    pub fn openDefferedFace(dw_factory: *windows.IDWriteFactory, deffered_face: DefferedFace, options: shared.OpenFaceOptions) !Face {
        const dw_face = try deffered_face.dw_font.CreateFontFace();
        errdefer dw_face.Release();

        return .{
            .dw_factory = dw_factory,
            .dw_face = dw_face,
            .size = options.size,
        };
    }

    pub fn close(self: Face) void {
        self.dw_face.Release();
    }

    pub fn setSize(self: *Face, size: shared.DesiredSize) !void {
        self.size = size;
    }

    pub fn glyphIndex(self: Face, codepoint: u21) ?u32 {
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

        const run_analysis = try self.dw_factory.CreateGlyphRunAnalysis(
            &glyph_run,
            1.0,
            matrix,
            .DWRITE_RENDERING_MODE_NATURAL_SYMMETRIC,
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

        const run_analysis = try self.dw_factory.CreateGlyphRunAnalysis(
            &glyph_run,
            1.0,
            matrix,
            .DWRITE_RENDERING_MODE_NATURAL_SYMMETRIC, // makes it look mutch better
            .DWRITE_MEASURING_MODE_NATURAL,
            0.0,
            0.0,
        );
        defer run_analysis.Release();

        const bounds = try run_analysis.GetAlphaTextureBounds(.DWRITE_TEXTURE_CLEARTYPE_3x1);

        const width: u32 = @intCast(bounds.right - bounds.left);
        const height: u32 = @intCast(bounds.bottom - bounds.top);

        if (width == 0 or height == 0) {
            return .{
                .width = 0,
                .height = 0,
                .bitmap = &.{},
            };
        }

        const bitmap_len = @as(usize, @intCast(width)) * @as(usize, @intCast(height));
        const bitmap = try allocator.alloc(u8, bitmap_len * 3);
        // cant do errdefer here as we can invoke double free

        {
            errdefer allocator.free(bitmap);
            try run_analysis.CreateAlphaTexture(.DWRITE_TEXTURE_CLEARTYPE_3x1, &bounds, bitmap);

            for (0..bitmap_len) |i| {
                // todo: simd or check if compiler does it for us
                const r: f32 = @floatFromInt(bitmap[i * 3 + 0]);
                const g: f32 = @floatFromInt(bitmap[i * 3 + 1]);
                const b: f32 = @floatFromInt(bitmap[i * 3 + 2]);

                bitmap[i] = @intFromFloat(@round(r * 0.2989 + g * 0.587 + b * 0.114));
            }
        }

        if (allocator.remap(bitmap, bitmap_len)) |new_bitmap| return .{
            .width = width,
            .height = height,
            .bitmap = new_bitmap,
        };

        defer allocator.free(bitmap);

        const new_bitmap = try allocator.alloc(u8, bitmap_len);
        errdefer allocator.free(new_bitmap);

        @memcpy(new_bitmap, bitmap[0..bitmap_len]);

        return .{
            .width = width,
            .height = height,
            .bitmap = new_bitmap,
        };
    }

    pub fn glyphMetrics(self: Face, glyph_index: u32) !shared.GlyphMetrics {
        //const metrics = self.dw_face.GetMetrics();
        //const scale = @as(f32, @floatFromInt(self.size.pixels())) / @as(f32, @floatFromInt(metrics.designUnitsPerEm));

        const indicies = [1]windows.UINT16{@intCast(glyph_index)};
        var glyph_metrics = [1]windows.DWRITE_GLYPH_METRICS{undefined};

        try self.dw_face.GetGdiCompatibleGlyphMetrics(
            @floatFromInt(self.size.pixels()),
            1.0,
            null,
            windows.FALSE,
            &indicies,
            &glyph_metrics,
            windows.FALSE,
        );

        return .{
            //.bearing_x = @intFromFloat(@as(f32, @floatFromInt(glyph_metrics[0].leftSideBearing)) * scale),
            //.bearing_y = @intFromFloat(@as(f32, @floatFromInt(glyph_metrics[0].topSideBearing)) * scale),
            //.advance_x = @intFromFloat(@as(f32, @floatFromInt(glyph_metrics[0].advanceWidth)) * scale),
            //.advance_y = @intFromFloat(@as(f32, @floatFromInt(glyph_metrics[0].advanceHeight)) * scale),
            .bearing_x = glyph_metrics[0].leftSideBearing,
            .bearing_y = glyph_metrics[0].topSideBearing,
            .advance_x = glyph_metrics[0].advanceWidth,
            .advance_y = glyph_metrics[0].advanceHeight,
        };
    }
};
