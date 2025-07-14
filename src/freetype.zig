const std = @import("std");
const assert = std.debug.assert;

// todo: remove this
const c = @cImport({
    @cInclude("freetype/ftadvanc.h");
});

const FT_Long = c.FT_Long;
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
        else => unexpectedError(err),
    };
}

pub inline fn FT_Done_FreeType(library: FT_Library) void {
    assert(c.FT_Done_FreeType(library) == c.FT_Err_Ok);
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
    const err = c.FT_New_Face(library, filepathname.ptr, face_index, aface);
    return switch (err) {
        c.FT_Err_Ok => {},
        c.FT_Err_Out_Of_Memory => error.OutOfMemory,
        c.FT_Err_Cannot_Open_Resource => error.FailedToOpen,
        c.FT_Err_Unknown_File_Format, 
        c.FT_Err_Invalid_File_Format => error.NotSupported,
        else => unexpectedError(err),
    };
}

pub inline fn FT_Done_Face(face: FT_Face) void {
    assert(c.FT_Done_Face(face) == c.FT_Err_Ok);
}

const UnexpectedError = error{
    Unexpected,
};

fn unexpectedError(err: c.FT_Error) UnexpectedError {
    if (std.posix.unexpected_error_tracing) {
        std.debug.print("error.Unexpected FT_Error=0x{x}\n", .{
            err,
        });
        std.debug.dumpCurrentStackTrace(@returnAddress());
    }
    return error.Unexpected;
}
