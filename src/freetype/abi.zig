pub const FT_Long = c_long;
pub const FT_Error = @import("FT_Error.zig").FT_Error;

pub const FT_Library = *opaque {};
pub const FT_Face = *opaque {};

pub extern fn FT_Init_FreeType(alibrary: *FT_Library) callconv(.C) FT_Error;

pub extern fn FT_Done_FreeType(library: FT_Library) callconv(.C) FT_Error;

pub extern fn FT_New_Face(library: FT_Library, filepathname: [*]const u8, face_index: FT_Long, aface: *FT_Face) callconv(.C) FT_Error;

pub extern fn FT_Done_Face(face: FT_Face) callconv(.C) FT_Error;
