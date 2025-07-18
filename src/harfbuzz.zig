const builtin = @import("builtin");
const build_options = @import("build_options");
const freetype = @import("freetype.zig");
const windows = @import("windows.zig");

const c = @cImport({
    @cInclude("hb.h");
    switch (build_options.font_backend) {
        .Freetype, .FontconfigFreetype => @cInclude("hb-ft.h"),

        .Directwrite => @cInclude("hb-directwrite.h"),
    }
});

pub const hb_face_t = c.hb_face_t;
pub const hb_font_t = c.hb_font_t;

pub inline fn hb_ft_face_create(ft_face: freetype.FT_Face) error{OutOfMemory}!*hb_face_t {
    return c.hb_ft_face_create(@ptrCast(@alignCast(ft_face)), null) orelse error.OutOfMemory;
}

pub inline fn hb_face_destroy(face: *hb_face_t) void {
    c.hb_face_destroy(face);
}

pub inline fn hb_ft_font_create(face: *hb_face_t) error{OutOfMemory}!*hb_font_t {
    return c.hb_font_create(face) orelse return error.OutOfMemory;
}

pub inline fn hb_font_destroy(face: *hb_font_t) void {
    c.hb_font_destroy(face);
}

pub inline fn hb_ft_font_create_referenced(ft_face: freetype.FT_Face) error{OutOfMemory}!*hb_font_t {
    return c.hb_ft_font_create_referenced(@ptrCast(ft_face)) orelse return error.OutOfMemory;
}

pub inline fn hb_directwrite_font_create(dw_face: *windows.IDWriteFontFace) error{OutOfMemory}!*hb_font_t {
    return c.hb_directwrite_font_create(@ptrCast(dw_face)) orelse return error.OutOfMemory;
}
