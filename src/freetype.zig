const std = @import("std");
const abi = @import("freetype/abi.zig");
const assert = std.debug.assert;

// todo: remove this
const c = @cImport({
    @cInclude("freetype/ftadvanc.h");
});

const FT_Int = abi.FT_Int;
const FT_Long = abi.FT_Long;
const FT_UInt = abi.FT_UInt;
const FT_ULong = abi.FT_ULong;
const FT_Error = abi.FT_Error;
const LoadFlags = abi.LoadFlags;
const FT_F26Dot6 = abi.FT_F26Dot6;

pub const FT_Face = abi.FT_Face;
pub const FT_Library = abi.FT_Library;

pub const FT_FACE_FLAG_SCALABLE = 1 << 0;

pub const FTInitFreeTypeError = error{
    OutOfMemory,
    Unexpected,
};

pub fn FT_Init_FreeType(alibrary: *FT_Library) FTInitFreeTypeError!void {
    const err = abi.FT_Init_FreeType(alibrary);
    return switch (err) {
        .Ok => {},
        .Out_Of_Memory => error.OutOfMemory,
        else => unexpectedError(err),
    };
}

pub inline fn FT_Done_FreeType(library: FT_Library) void {
    assert(abi.FT_Done_FreeType(library) == .Ok);
}

pub const FTNewFaceError = error{
    FailedToOpen,
    NotSupported,
    OutOfMemory,
    Unexpected,
};

pub fn FT_New_Face(
    library: FT_Library,
    filepathname: [:0]const u8,
    face_index: FT_Long,
    aface: *FT_Face,
) FTNewFaceError!void {
    const err = abi.FT_New_Face(library, filepathname.ptr, face_index, aface);
    return switch (err) {
        .Ok => {},
        .Out_Of_Memory => error.OutOfMemory,
        .Cannot_Open_Resource => error.FailedToOpen,
        .Unknown_File_Format, .Invalid_File_Format => error.NotSupported,
        else => unexpectedError(err),
    };
}

pub inline fn FT_Done_Face(face: FT_Face) void {
    assert(abi.FT_Done_Face(face) == .Ok);
}

pub const FTSetCharSizeError = error{
    InvalidSize,
    Unexpected,
};

pub fn FT_Set_Char_Size(
    face: FT_Face,
    char_width: FT_F26Dot6,
    char_height: FT_F26Dot6,
    horz_resolution: FT_UInt,
    vert_resolution: FT_UInt,
) FTSetCharSizeError!void {
    const err = abi.FT_Set_Char_Size(face, char_width, char_height, horz_resolution, vert_resolution);
    return switch (err) {
        .Ok => {},
        .Invalid_Pixel_Size => error.InvalidSize,
        else => unexpectedError(err),
    };
}

pub inline fn FT_IS_SCALABLE(face: FT_Face) bool {
    return face.face_flags & FT_FACE_FLAG_SCALABLE != 0;
}

pub const FTSelectSizeError = error{
    Unexpected,
};

pub fn FT_Select_Size(face: FT_Face, strike_index: FT_Int) FTSelectSizeError!void {
    const err = abi.FT_Select_Size(face, strike_index);
    return switch (err) {
        .Ok => {},
        else => unexpectedError(err),
    };
}

pub fn FT_Get_Char_Index(face: FT_Face, charcode: FT_ULong) ?FT_UInt {
    const idx = abi.FT_Get_Char_Index(face, charcode);
    return if (idx == 0) null else idx;
}

pub const FTLoadGlyphError = error{
    OutOfMemory,
    Unexpected,
};

pub fn FT_Load_Glyph(face: FT_Face, glyph_index: FT_UInt, load_flags: LoadFlags) FTLoadGlyphError!void {
    const err = abi.FT_Load_Glyph(face, glyph_index, load_flags);
    return switch (err) {
        .Ok => {},
        .Out_Of_Memory => error.OutOfMemory,
        else => unexpectedError(err),
    };
}

const UnexpectedError = error{
    Unexpected,
};

fn unexpectedError(err: FT_Error) UnexpectedError {
    if (std.posix.unexpected_error_tracing) {
        const tag_name = std.enums.tagName(FT_Error, err) orelse "";
        std.debug.print("error.Unexpected FT_Error=0x{x}: {s}\n", .{
            @intFromEnum(err),
            tag_name,
        });
        std.debug.dumpCurrentStackTrace(@returnAddress());
    }
    return error.Unexpected;
}
