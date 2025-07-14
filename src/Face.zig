const std = @import("std");
const builtin = @import("builtin");
const Library = @import("Library.zig");
const freetype = @import("freetype.zig");
const windows = @import("windows.zig");

impl: Impl,

pub const OpenFaceError = error{
    FailedToOpen,
    NotSupported,
    InvalidWtf8,
    OutOfMemory,
    Unexpected,
};

pub fn openFace(library: Library, sub_path: [:0]const u8) OpenFaceError!Face {
    return .{
        .impl = try Impl.openFace(library, sub_path),
    };
}

pub inline fn close(self: Face) void {
    self.impl.close();
}

const Face = @This();

pub const Impl = if (builtin.os.tag == .windows) DWriteImpl else FreetypeImpl;

const DWriteImpl = struct {
    dwrite_face: *windows.IDWriteFontFace,

    pub fn openFace(library: Library, sub_path: [:0]const u8) !DWriteImpl {
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
         
        return .{
            .dwrite_face = try library.impl.dwrite_factory.CreateFontFace(face_type, &.{font_file}, 0, .DWRITE_FONT_SIMULATIONS_NONE),
        };
    }

    pub fn close(self: DWriteImpl) void {
        self.dwrite_face.Release();
    }
};

const FreetypeImpl = struct {
    ft_face: freetype.FT_Face,

    pub fn openFace(library: Library, sub_path: [:0]const u8) !FreetypeImpl {
        var ft_face: freetype.FT_Face = undefined;
        try freetype.FT_New_Face(library.impl.ft_library, sub_path, 0, &ft_face);

        return .{
            .ft_face = ft_face,
        };
    }

    pub fn close(self: FreetypeImpl) void {
        freetype.FT_Done_Face(self.ft_face);
    }
};
