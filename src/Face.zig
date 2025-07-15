const std = @import("std");
const builtin = @import("builtin");
const Library = @import("Library.zig");
const freetype = @import("freetype.zig");
const harfbuzz = @import("harfbuzz.zig");
const windows = @import("windows.zig");

pub const default_dpi = if (builtin.os.tag == .macos) 72 else 96;

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

pub const Options = struct {
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
pub fn openFace(library: Library, sub_path: [:0]const u8, options: Options) OpenFaceError!Face {
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

const Face = @This();

pub const Impl = if (builtin.os.tag == .windows) DWriteImpl else FreetypeImpl;

const DWriteImpl = struct {
    dw_face: *windows.IDWriteFontFace,
    hb_font: *harfbuzz.hb_font_t,

    size: DesiredSize,

    pub fn openFace(library: Library, sub_path: [:0]const u8, options: Options) !DWriteImpl {
        var tmp_path: windows.PathSpace = undefined;
        tmp_path.len = try std.unicode.wtf8ToWtf16Le(&tmp_path.data, sub_path);
        tmp_path.data[tmp_path.len] = 0;

        const font_file = library.impl.dwrite_factory.CreateFontFileReference(tmp_path.span(), null) catch |err| return switch (err) {
            error.FontNotFound,
            error.AccessDenied => error.FailedToOpen,
            else => |e| e,
        };
        defer font_file.Release();

        var file_type: windows.DWRITE_FONT_FILE_TYPE = undefined;
        var face_type: windows.DWRITE_FONT_FACE_TYPE = undefined;

        var faces: u32 = undefined;

        try font_file.Analyze(&file_type, &face_type, &faces);
         
        const dw_face = try library.impl.dwrite_factory.CreateFontFace(face_type, &.{font_file}, options.face_index, .DWRITE_FONT_SIMULATIONS_NONE);
        errdefer dw_face.Release();

        const hb_font = try harfbuzz.hb_directwrite_font_create(dw_face);
        errdefer harfbuzz.hb_font_destroy(hb_font);

        return .{
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
};

const FreetypeImpl = struct {
    ft_face: freetype.FT_Face,
    hb_font: *harfbuzz.hb_font_t,

    size: DesiredSize,

    pub fn openFace(library: Library, sub_path: [:0]const u8, options: Options) !FreetypeImpl {
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

    //pub fn renderGlyph() void {
    //}
};
