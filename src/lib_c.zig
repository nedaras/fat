const std = @import("std");
const Library = @import("Library.zig");
const Face = @import("Face.zig");
const mem = std.mem;
const c_allocator = std.heap.c_allocator;

const fat_error_e = enum(c_int) {
    ok = 0,
    failed_to_open,
    not_supported,
    invalid_wtf_8,
    invalid_pointer,
    out_of_memory,
    unexpected,
};

export fn fat_error_name(err: c_int) [*:0]const u8 {
    const err_e = std.meta.intToEnum(fat_error_e, err) catch .unexpected;
    return @tagName(err_e).ptr;
}

export fn fat_init_library(clibrary: ?**Library) callconv(.C) fat_error_e {
    const out = clibrary orelse return fat_error_e.invalid_pointer;
    const lib = c_allocator.create(Library) catch return fat_error_e.out_of_memory;

    lib.* = Library.init() catch |err| {
        c_allocator.destroy(lib);
        return switch (err) {
            error.OutOfMemory => fat_error_e.out_of_memory,
            error.Unexpected => fat_error_e.unexpected,
        };
    };

    out.* = lib;
    return fat_error_e.ok;
}

export fn fat_library_done(clibrary: ?*Library) callconv(.C) fat_error_e {
    const lib = clibrary orelse return fat_error_e.invalid_pointer;
    lib.deinit();

    c_allocator.destroy(lib);
    return fat_error_e.ok;
}

export fn fat_open_face(clibrary: ?*Library, cface: ?**Face, sub_path: [*:0]const u8, coptions: Face.OpenFaceOptions.C) callconv(.C) fat_error_e {
    const lib = clibrary orelse return fat_error_e.invalid_pointer;
    const out = cface orelse return fat_error_e.invalid_pointer;

    const face = c_allocator.create(Face) catch return fat_error_e.out_of_memory;
    const options: Face.OpenFaceOptions = .{
        .size = .{ .points = coptions.size },
        .face_index = coptions.face_index,
    };

    face.* = lib.openFace(mem.span(sub_path), options) catch |err| {
        c_allocator.destroy(face);
        return switch (err) {
            error.FailedToOpen => fat_error_e.failed_to_open,
            error.NotSupported => fat_error_e.not_supported,
            error.InvalidWtf8 => fat_error_e.invalid_wtf_8,
            error.OutOfMemory => fat_error_e.out_of_memory,
            error.Unexpected => fat_error_e.unexpected,
        };
    };

    out.* = face;
    return fat_error_e.ok;
}

export fn fat_face_done(cface: ?*Face) callconv(.C) fat_error_e {
    const face = cface orelse return fat_error_e.invalid_pointer;
    face.close();

    c_allocator.destroy(face);
    return fat_error_e.ok;
}

export fn fat_face_glyph_index(cface: ?*Face, codepoint: u32, o_glyph_index: ?*u32) callconv(.C) fat_error_e {
    const face = cface orelse return fat_error_e.invalid_pointer;
    const glyph_index = o_glyph_index orelse return fat_error_e.invalid_pointer;

    glyph_index.* = face.glyphIndex(@intCast(codepoint)) orelse 0;
    return fat_error_e.ok;
}

export fn fat_face_glyph_bbox(cface: ?*Face, glyph_index: u32, o_bbox: ?*Face.GlyphBoundingBox.C) callconv(.C) fat_error_e {
    const face = cface orelse return fat_error_e.invalid_pointer;
    const bbox = o_bbox orelse return fat_error_e.invalid_pointer;

    const box = face.glyphBoundingBox(glyph_index) catch |err| return switch (err) {
        error.Unexpected => fat_error_e.unexpected,
    };

    bbox.* = .{
        .width = box.width,
        .height = box.height,
    };
    return fat_error_e.ok;
}
