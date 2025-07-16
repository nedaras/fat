const std = @import("std");
const builtin = @import("builtin");
const Library = @import("Library.zig");
const freetype = @import("freetype.zig");
const harfbuzz = @import("harfbuzz.zig");
const windows = @import("windows.zig");

pub const default_dpi = if (builtin.os.tag == .macos) 72 else 96;

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

impl: Impl,

pub const OpenFaceOptions = struct {
    size: DesiredSize,
    face_index: u32 = 0,

    pub const C = extern struct {
        size: f32,
        face_index: u32,
    };
};

pub const OpenFaceError = error{
    FailedToOpen,
    NotSupported,
    InvalidWtf8,
    OutOfMemory,
    Unexpected,
};

/// Open a new font face with the given file path.
pub fn openFace(library: Library, sub_path: [:0]const u8, options: OpenFaceOptions) OpenFaceError!Face {
    return .{
        .impl = try Impl.openFace(library, sub_path, options),
    };
}

pub inline fn close(self: Face) void {
    self.impl.close();
}


/// Resize the font in-place.
pub inline fn setSize(self: *Face, size: DesiredSize) !void {
    return self.impl.setSize(size);
}

pub inline fn glyphIndex(self: Face, codepoint: u21) ?u32 {
    return self.impl.gyphIndex(codepoint);
}

pub inline fn glyphBoundingBox(self: Face, glyph_index: u32) !GlyphBoundingBox {
    return self.impl.glyphBoundingBox(glyph_index);
}

const Face = @This();

pub const Impl = if (builtin.os.tag == .windows) DWriteImpl else FreetypeImpl;

const DWriteImpl = struct {
    library: Library,

    dw_face: *windows.IDWriteFontFace,
    hb_font: *harfbuzz.hb_font_t,

    size: DesiredSize,

    pub fn openFace(library: Library, sub_path: [:0]const u8, options: OpenFaceOptions) !DWriteImpl {
        var tmp_path: windows.PathSpace = undefined;
        tmp_path.len = try std.unicode.wtf8ToWtf16Le(&tmp_path.data, sub_path);
        tmp_path.data[tmp_path.len] = 0;

        const font_file = library.impl.dw_factory.CreateFontFileReference(tmp_path.span(), null) catch |err| return switch (err) {
            error.FontNotFound,
            error.AccessDenied => error.FailedToOpen,
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

    pub fn close(self: DWriteImpl) void {
        harfbuzz.hb_font_destroy(self.hb_font);
        self.dw_face.Release();
    }

    pub fn setSize(self: *DWriteImpl, size: DesiredSize) !void {
        self.size = size;
    }

    pub fn gyphIndex(self: DWriteImpl, codepoint: u21) ?u32 {
        const codepoints = [1]windows.UINT32{ codepoint };
        var indicies = [1]windows.UINT16{ 0 };

        self.dw_face.GetGlyphIndices(&codepoints, &indicies);

        return if (indicies[0] == 0) null else indicies[0];
    }

    pub fn glyphBoundingBox(self: DWriteImpl, glyph_index: u32) !GlyphBoundingBox {
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
            .fontEmSize = self.size.points,
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
};

const FreetypeImpl = struct {
    ft_face: freetype.FT_Face,
    hb_font: *harfbuzz.hb_font_t,

    size: DesiredSize,

    pub fn openFace(library: Library, sub_path: [:0]const u8, options: OpenFaceOptions) !FreetypeImpl {
        var ft_face: freetype.FT_Face = undefined;

        try freetype.FT_New_Face(library.impl.ft_library, sub_path, options.face_index, &ft_face);
        errdefer freetype.FT_Done_Face(ft_face);

        const hb_font = try harfbuzz.hb_ft_font_create_referenced(ft_face);
        errdefer harfbuzz.hb_font_destroy(hb_font);

        var res: FreetypeImpl = .{
            .ft_face = ft_face,
            .hb_font = hb_font,
            .size = undefined,
        };

        try res.setSize(options.size);
        return res;
    }

    pub fn close(self: FreetypeImpl) void {
        harfbuzz.hb_font_destroy(self.hb_font);
        freetype.FT_Done_Face(self.ft_face);
    }

    pub fn setSize(self: *FreetypeImpl, size: DesiredSize) !void {
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

    pub inline fn gyphIndex(self: FreetypeImpl, codepoint: u21) ?u32 {
        return freetype.FT_Get_Char_Index(self.ft_face, codepoint);
    }

    pub fn glyphBoundingBox(self: FreetypeImpl, glyph_index: u32) !GlyphBoundingBox {
        try freetype.FT_Load_Glyph(self.ft_face, glyph_index, .{});
        const bitmap = self.ft_face.glyph.bitmap;
        return .{
            .width = bitmap.width,
            .height = bitmap.rows,
        };
    }

    //pub fn loadGlyph(glyph_index: u32) ?void {
    //}

};
