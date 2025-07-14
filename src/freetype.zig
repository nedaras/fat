const std = @import("std");
const abi = @import("freetype/abi.zig");
const assert = std.debug.assert;

// todo: remove this
//const c = @cImport({
    //@cInclude("freetype/ftadvanc.h");
//});

const FT_Long = abi.FT_Long;
const FT_Error = abi.FT_Error;

pub const FT_Face = abi.FT_Face;
pub const FT_Library = abi.FT_Library;

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
        .Unknown_File_Format, 
        .Invalid_File_Format => error.NotSupported,
        else => unexpectedError(err),
    };
}

pub inline fn FT_Done_Face(face: FT_Face) void {
    assert(abi.FT_Done_Face(face) == .Ok);
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
