const std = @import("std");
const build_options = @import("build_options");
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

// todo: just pick one if theres two
pub const FcWeight = enum (u8) {
    FC_WEIGHT_THIN = 0,
    FC_WEIGHT_EXTRALIGHT,
    FC_WEIGHT_ULTRALIGHT = 40,
    FC_WEIGHT_LIGHT = 50,
    FC_WEIGHT_DEMILIGHT,
    FC_WEIGHT_SEMILIGHT = 55,
    FC_WEIGHT_BOOK = 75,
    FC_WEIGHT_REGULAR,
    FC_WEIGHT_NORMAL = 80,
    FC_WEIGHT_MEDIUM = 100,
    FC_WEIGHT_DEMIBOLD,
    FC_WEIGHT_SEMIBOLD = 180,
    FC_WEIGHT_BOLD = 200,
    FC_WEIGHT_EXTRABOLD,
    FC_WEIGHT_ULTRABOLD = 205,
    FC_WEIGHT_BLACK,
    FC_WEIGHT_HEAVY = 210,
    FC_WEIGHT_EXTRABLACK,
    FC_WEIGHT_ULTRABLACK = 215,
};

pub const FcSlant = enum(c_int) {
    FC_SLANT_ROMAN = 0,
    FC_SLANT_ITALIC = 100,
    FC_SLANT_OBLIQUE = 110,
};

pub fn nearestWeight(weight: anytype) error{InvalidWeight}!FcWeight {
    @setRuntimeSafety(false);

    // has to be in range of all valid FcWeight values
    if (weight < 0 or weight > 215) {
        return error.InvalidWeight;
    }

    const values = comptime std.enums.values(FcWeight);
    const weight_val: u8 = @intCast(weight);
      
    var best_weight: FcWeight = undefined;
    var best_diff: u8 = undefined;

    inline for (values, 0..) |curr_weight, i| {
        const curr_weight_val = @intFromEnum(curr_weight);
        // todo: if im not bored o could make this line branchless
        const diff = if (weight_val > curr_weight_val) 
            weight_val - curr_weight_val else curr_weight_val - weight_val;

        if (i == 0 or diff < best_diff) {
            best_diff = diff;
            best_weight = curr_weight;
        }

        if (diff == 0) {
            break;
        }
    }

    return best_weight;
}

pub const FcResult = enum(c_uint) { FcResultMatch, FcResultNoMatch, FcResultTypeMismatch, FcResultNoId, FcResultOutOfMemory, _, };

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

pub inline fn FcCharSetCreate() Error!*FcCharSet {
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
    OutOfMemory,
    Unexpected,
};

pub fn FcFontSort(config: *FcConfig, p: *FcPattern, trim: bool, csp: ?[:null]?*FcCharSet) FcFontSortError!*FcFontSet {
    const csp_ptr = if (csp) |slice| slice.ptr else null;
    var result: FcResult = undefined;

    const font_set = abi.FcFontSort(config, p, @intFromBool(trim), @ptrCast(csp_ptr), @ptrCast(&result));
    return switch (result) {
        .FcResultMatch => font_set,
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
    Unexpected,
};

pub fn FcPatternGetCharSet(p: *const FcPattern, object: [:0]const u8, n: c_int) FcPatternGetCharSetError!?*const FcCharSet {
    var c: *FcCharSet = undefined;

    const result: FcResult = @enumFromInt(abi.FcPatternGetCharSet(p, object, n, @ptrCast(&c)));
    return switch (result) {
        .FcResultMatch => c,
        .FcResultNoMatch => null,
        else => error.Unexpected,
    };
}

pub const FcPatternGetStringError = error{
    Unexpected,
};

pub fn FcPatternGetString(p: *const FcPattern, object: [:0]const u8, n: c_int) FcPatternGetStringError!?[:0]const u8 {
    var s: [*:0]const u8 = undefined;

    const result: FcResult = @enumFromInt(abi.FcPatternGetString(p, object, n, @ptrCast(&s)));
    return switch (result) {
        .FcResultMatch => std.mem.span(s),
        .FcResultNoMatch => null,
        else => return error.Unexpected,
    };
}

pub const FcPatternGetDoubleError = error{
    Unexpected,
};

pub fn FcPatternGetDouble(p: *const FcPattern, object: [:0]const u8, n: c_int) FcPatternGetStringError!?f64 {
    var d: f64 = undefined;

    const result: FcResult = @enumFromInt(abi.FcPatternGetDouble(p, object, n, &d));
    return switch (result) {
        .FcResultMatch => d,
        .FcResultNoMatch => null,
        else => error.Unexpected,
    };
}

pub const FcPatternGetIntegerError = error{
    Unexpected,
};

pub fn FcPatternGetInteger(p: *const FcPattern, object: [:0]const u8, n: c_int) FcPatternGetIntegerError!?c_int {
    var i: c_int = undefined;

    const result: FcResult = @enumFromInt(abi.FcPatternGetInteger(p, object, n, &i));
    return switch (result) {
        .FcResultMatch => i,
        .FcResultNoMatch => null,
        else => error.Unexpected,
    };
}

pub inline fn FcCharSetHasChar(fsc: *const FcCharSet, usc4: FcChar32) bool {
    return abi.FcCharSetHasChar(fsc, usc4) == abi.FcTrue;
}

pub inline fn FcPatternPrint(p: *const FcPattern) void {
    abi.FcPatternPrint(p);
}
