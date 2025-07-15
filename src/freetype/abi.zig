pub const FT_Short = c_short;
pub const FT_Int = c_int;
pub const FT_Pos = c_long;
pub const FT_Long = c_long;
pub const FT_UInt = c_uint;
pub const FT_F26Dot6 = c_long;
pub const FT_String = [*:0]const u8;
pub const FT_Error = @import("FT_Error.zig").FT_Error;

pub const FT_Library = *opaque {};
pub const FT_Face = *FT_FaceRec;

pub const FT_Bitmap_Size = extern struct {
    height: FT_Short,
    width: FT_Short,
    size: FT_Pos,
    x_ppem: FT_Pos,
    y_ppem: FT_Pos,
};

const FT_FaceRec = extern struct {
    num_faces: FT_Long,
    face_index: FT_Long,
    face_flags: FT_Long,
    style_flags: FT_Long,
    num_glyphs: FT_Long,
    family_name: FT_String,
    style_name: FT_String,
    num_fixed_sizes: FT_Int,
    available_sizes: [*]const FT_Bitmap_Size,
    // ...
};

pub extern fn FT_Init_FreeType(alibrary: *FT_Library) callconv(.C) FT_Error;

pub extern fn FT_Done_FreeType(library: FT_Library) callconv(.C) FT_Error;

pub extern fn FT_New_Face(
    library: FT_Library,
    filepathname: [*]const u8,
    face_index: FT_Long,
    aface: *FT_Face,
) callconv(.C) FT_Error;

pub extern fn FT_Done_Face(face: FT_Face) callconv(.C) FT_Error;

pub extern fn FT_Set_Char_Size(
    face: FT_Face,
    char_width: FT_F26Dot6,
    char_height: FT_F26Dot6,
    horz_resolution: FT_UInt,
    vert_resolution: FT_UInt,
) callconv(.C) FT_Error;


pub extern fn FT_Select_Size(face: FT_Face, strike_index: FT_Int) callconv(.C) FT_Error;
