const std = @import("std");
const assert = std.debug.assert;

// todo: remove this
const c = @cImport({
    @cInclude("freetype/ftadvanc.h");
});

const FT_ULong = c.FT_ULong;
pub const FT_Face = c.FT_Face;
pub const FT_Library = c.FT_Library;

pub const FTInitFreeTypeError = error{
    OutOfMemory,
    Unexpected,
};

pub fn FT_Init_FreeType(alibrary: *FT_Library) FTInitFreeTypeError!void {
    const err = c.FT_Init_FreeType(alibrary);
    return switch (err) {
        c.FT_Err_Ok => {},
        c.FT_Err_Out_Of_Memory => error.OutOfMemory,
        else => error.Unexpected, // todo: log this
    };
}

pub inline fn FT_Done_FreeType(library: FT_Library) void {
    assert(c.FT_Done_FreeType(library) == c.FT_Err_Ok);
}

pub const FTNewFaceError = error{
    OutOfMemory,
    Unexpected,
};

pub fn FT_New_Face(
    library: FT_Library,
    filepathname: [:0]const u8,
    face_index: FT_ULong,
    aface: *FT_Face,
) void {
    const err = c.FT_New_Face(library, filepathname.ptr, face_index, aface);
    return switch (err) {
        c.FT_Err_Ok => {},
        c.FT_Err_Out_Of_Memory => error.OutOfMemory,
        else => error.Unexpected, // todo: log this
    };
}

pub inline fn FT_Done_Face(face: FT_Face) void {
    assert(c.FT_Done_Face(face) == c.FT_Err_Ok);
}
