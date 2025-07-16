pub const FT_Int32 = i32;
pub const FT_Int = c_int;
pub const FT_Pos = c_long;
pub const FT_Long = c_long;
pub const FT_UInt = c_uint;
pub const FT_Fixed = c_long;
pub const FT_Short = c_short;
pub const FT_ULong = c_ulong;
pub const FT_F26Dot6 = c_long;
pub const FT_UShort = c_ushort;
pub const FT_Face = *FT_FaceRec;
pub const FT_String = [*:0]const u8;
pub const FT_GlyphSlot = *FT_GlyphSlotRec;
pub const FT_Error = @import("FT_Error.zig").FT_Error;

pub const FT_Library = *opaque {};
pub const FT_CharMap = *opaque {};
pub const FT_Generic_Finalizer = *opaque {};

pub const FT_Glyph_Format = c_uint;

pub const LoadFlags = packed struct(i32) {
    no_scale: bool = false,
    no_hinting: bool = false,
    render: bool = false,
    no_bitmap: bool = false,
    vertical_layout: bool = false,
    force_autohint: bool = false,
    crop_bitmap: bool = false,
    pedantic: bool = false,
    ignore_global_advance_with: bool = false,
    no_recurse: bool = false,
    ignore_transform: bool = false,
    monochrome: bool = false,
    linear_design: bool = false,
    no_autohint: bool = false,
    _padding1: u1 = 0,
    target_normal: bool = false,
    target_light: bool = false,
    target_mono: bool = false,
    target_lcd: bool = false,
    target_lcd_v: bool = false,
    color: bool = false,
    compute_metrics: bool = false,
    bitmap_metrics_only: bool = false,
    _padding2: u1 = 0,
    no_svg: bool = false,
    _padding3: u7 = 0,
};

pub const FT_Generic = extern struct {
    data: ?*anyopaque,
    finalizer: FT_Generic_Finalizer,
};

pub const FT_Bitmap_Size = extern struct {
    height: FT_Short,
    width: FT_Short,
    size: FT_Pos,
    x_ppem: FT_Pos,
    y_ppem: FT_Pos,
};

pub const FT_BBox = extern struct {
    xMin: FT_Pos,
    yMin: FT_Pos,
    xMax: FT_Pos,
    yMax: FT_Pos,
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
    num_charmaps: FT_Int,
    charmaps: [*]const FT_CharMap,
    generic: FT_Generic,
    bbox: FT_BBox,
    units_per_EM: FT_UShort,
    ascender: FT_Short,
    descender: FT_Short,
    height: FT_Short,
    max_advance_width: FT_Short,
    max_advance_height: FT_Short,
    underline_position: FT_Short,
    underline_thickness: FT_Short,
    glyph: FT_GlyphSlot,
    // ...
};

pub const FT_Glyph_Metrics = extern struct {
    width: FT_Pos,
    height: FT_Pos,
    horiBearingX: FT_Pos,
    horiBearingY: FT_Pos,
    horiAdvance: FT_Pos,
    vertBearingX: FT_Pos,
    vertBearingY: FT_Pos,
    vertAdvance: FT_Pos,
};

pub const FT_Vector = extern struct {
    x: FT_Pos,
    y: FT_Pos,
};

pub const FT_Bitmap = extern struct {
    rows: c_uint,
    width: c_uint,
    pitch: c_int,
    buffer: [*]const u8,
    num_grays: c_ushort,
    pixel_mode: u8,
    palette_mode: u8,
    palette: ?*anyopaque,
};

const FT_GlyphSlotRec = extern struct {
    library: FT_Library,
    face: FT_Face,
    next: FT_GlyphSlot,
    glyph_index: FT_UInt,
    generic: FT_Generic,
    metrics: FT_Glyph_Metrics,
    linearHoriAdvance: FT_Fixed,
    linearVertAdvance: FT_Fixed,
    advance: FT_Vector,
    format: FT_Glyph_Format,
    bitmap: FT_Bitmap,
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

pub extern fn FT_Get_Char_Index(face: FT_Face, charcode: FT_ULong) callconv(.C) FT_UInt;

pub extern fn FT_Load_Glyph(face: FT_Face, glyph_index: FT_UInt, load_flags: LoadFlags) callconv(.C) FT_Error;
