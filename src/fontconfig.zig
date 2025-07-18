const std = @import("std");
const assert = std.debug.assert;

const abi = @cImport({
    @cInclude("fontconfig/fontconfig.h");
});

pub const FcConfig = abi.FcConfig;
pub const FcPattern = abi.FcPattern;
pub const FcChar8 = abi.FcChar8;
pub const FcMatrix = abi.FcMatrix;
pub const FcBool = abi.FcBool;
pub const FcCharSet = abi.FcCharSet;
pub const FcLangSet = abi.FcLangSet;
pub const FcRange = abi.FcRange;
pub const FcChar32 = abi.FcChar32;
pub const FcFontSet = abi.FcFontSet;

pub const FcMatchKind = enum(c_uint) {
    FcMatchPattern,
    FcMatchFont,
    FcMatchScan,
};


pub const FcResult = enum(c_uint) {
    FcResultMatch,
    FcResultNoMatch,
    FcResultTypeMismatch,
    FcResultNoId,
    FcResultOutOfMemory,
    _
};

// kinda sucks when we dont have info to errors
pub const Error = error{
    OutOfMemory,
};

pub inline fn FcInitLoadConfigAndFonts() Error!*FcConfig {
    return abi.FcInitLoadConfigAndFonts() orelse return error.OutOfMemory;
}

pub inline fn FcConfigDestroy(config: *FcConfig) void {
    abi.FcConfigDestroy(config);
}

pub inline fn FcPatternCreate() Error!*FcPattern {
    return abi.FcPatternCreate() orelse error.OutOfMemory;
}

pub inline fn FcPatternDestroy(p: *FcPattern) void {
    abi.FcPatternDestroy(p);
}

pub inline fn FcPatternAddCharSet(p: *FcPattern, object: [:0]const u8, c: *const FcCharSet) void {
    assert(abi.FcPatternAddCharSet(p, object, c) == abi.FcTrue);
}

pub inline fn FcPatternAddString(p: *FcPattern, object: [:0]const u8, s: [:0]const u8) void {
    assert(abi.FcPatternAddString(p, object, s) == abi.FcTrue);
}

pub inline fn FcPatternAddDouble(p: *FcPattern, object: [:0]const u8, d: f64) void {
    assert(abi.FcPatternAddDouble(p, object.ptr, d) == abi.FcTrue);
}

pub inline fn FcCharSetCreate() Error!*FcCharSet{ 
    return abi.FcCharSetCreate() orelse error.OutOfMemory;
}

pub inline fn FcCharSetDestroy(fcs: *FcCharSet) void {
    abi.FcCharSetDestroy(fcs);
}

pub inline fn FcCharSetAddChar(fcs: *FcCharSet, ucs4: FcChar32) void {
    assert(abi.FcCharSetAddChar(fcs, ucs4) == abi.FcTrue);
}

pub inline fn FcConfigSubstitute(config: *FcConfig, p: *FcPattern, kind: FcMatchKind) void {
    assert(abi.FcConfigSubstitute(config, p, @intFromEnum(kind)) == abi.FcTrue);
}

pub inline fn FcDefaultSubstitute(pattern: *FcPattern) void {
    abi.FcDefaultSubstitute(pattern);
}

pub const FcFontSortError = error{
    MatchNotFound,
    OutOfMemory,
    Unexpected,
};

pub fn FcFontSort(config: *FcConfig, p: *FcPattern, trim: bool, csp: ?[:null]?*FcCharSet) FcFontSortError!*FcFontSet {
    const csp_ptr = if (csp) |slice| slice.ptr else null;
    var result: FcResult = undefined;

    const font_set = abi.FcFontSort(config, p, @intFromBool(trim), @ptrCast(csp_ptr), @ptrCast(&result));
    return switch (result) {
        .FcResultMatch => font_set,
        .FcResultNoMatch => error.MatchNotFound,
        .FcResultOutOfMemory => error.OutOfMemory,
        else => error.Unexpected,
    };
}

pub inline fn FcFontSetDestroy(s: *FcFontSet) void {
    abi.FcFontSetDestroy(s);
}

pub inline fn FcFontRenderPrepare(config: *FcConfig, pat: *FcPattern, font: *FcPattern) Error!*FcPattern {
    return abi.FcFontRenderPrepare(config, pat, font) orelse error.OutOfMemory;
}

pub const FcPatternGetCharSetError = error{
    MatchNotFound,
    Unexpected,
};

pub fn FcPatternGetCharSet(p: *const FcPattern, object: [:0]const u8, n: c_int) FcPatternGetCharSetError!*const FcCharSet {
    var c: *FcCharSet = undefined;

    const result: FcResult = @enumFromInt(abi.FcPatternGetCharSet(p, object, n, @ptrCast(&c)));
    return switch (result) {
        .FcResultMatch => c,
        .FcResultNoMatch => error.MatchNotFound,
        else => error.Unexpected,
    };
}

pub const FcPatternGetStringError = error{
    MatchNotFound,
    Unexpected,
};

pub fn FcPatternGetString(p: *const FcPattern, object: [:0]const u8, n: c_int) FcPatternGetStringError![:0]const u8 {
    var s: [*:0]const u8 = undefined;

    const result: FcResult = @enumFromInt(abi.FcPatternGetString(p, object, n, @ptrCast(&s)));
    return switch (result) {
        .FcResultMatch => std.mem.span(s),
        .FcResultNoMatch => error.MatchNotFound,
        else => error.Unexpected,
    };
}

pub const FcPatternGetDoubleError = error{
    MatchNotFound,
    Unexpected,
};

pub fn FcPatternGetDouble(p: *const FcPattern, object: [:0]const u8, n: c_int) FcPatternGetStringError!f64 {
    var d: f64 = undefined;

    const result: FcResult = @enumFromInt(abi.FcPatternGetDouble(p, object, n, &d));
    return switch (result) {
        .FcResultMatch => d,
        .FcResultNoMatch => error.MatchNotFound,
        else => error.Unexpected,
    };
}

pub const FcPatternGetIntegerError = error{
    MatchNotFound,
    Unexpected,
};

pub fn FcPatternGetInteger(p: *const FcPattern, object: [:0]const u8, n: c_int) FcPatternGetIntegerError!c_int {
    var i: c_int = undefined;

    const result: FcResult = @enumFromInt(abi.FcPatternGetInteger(p, object, n, &i));
    return switch (result) {
        .FcResultMatch => i,
        .FcResultNoMatch => error.MatchNotFound,
        else => error.Unexpected,
    };
}

pub inline fn FcCharSetHasChar(fsc: *const FcCharSet, usc4: FcChar32) bool {
    return abi.FcCharSetHasChar(fsc, usc4) == abi.FcTrue;
}

pub inline fn FcPatternPrint(p: *const FcPattern) void {
    abi.FcPatternPrint(p);
}
