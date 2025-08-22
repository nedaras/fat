const std = @import("std");
const dwrite = @import("windows/dwrite.zig");
const windows = std.os.windows;
const assert = std.debug.assert;

pub const INT = windows.INT;
pub const BOOL = windows.BOOL;
pub const BYTE = windows.BYTE;
pub const GUID = windows.GUID;
pub const RECT = windows.RECT;
pub const FALSE = windows.FALSE;
pub const WCHAR = windows.WCHAR;
pub const FLOAT = windows.FLOAT;
pub const ULONG = windows.ULONG;
pub const HRESULT = windows.HRESULT;
pub const FILETIME = windows.FILETIME;

pub const INT16 = i16;
pub const INT32 = i32;
pub const UINT32 = u32;
pub const UINT16 = u16;
pub const REFIID = *const GUID;

pub const DWRITE_FACTORY_TYPE = enum(INT) {
    DWRITE_FACTORY_TYPE_SHARED,
    DWRITE_FACTORY_TYPE_ISOLATED,
};

pub const DWRITE_FONT_FILE_TYPE = enum(INT) {
    DWRITE_FONT_FILE_TYPE_UNKNOWN,
    DWRITE_FONT_FILE_TYPE_CFF,
    DWRITE_FONT_FILE_TYPE_TRUETYPE,
    DWRITE_FONT_FILE_TYPE_OPENTYPE_COLLECTION,
    DWRITE_FONT_FILE_TYPE_TYPE1_PFM,
    DWRITE_FONT_FILE_TYPE_TYPE1_PFB,
    DWRITE_FONT_FILE_TYPE_VECTOR,
    DWRITE_FONT_FILE_TYPE_BITMAP,
};

pub const DWRITE_FONT_FACE_TYPE = enum(INT) {
    DWRITE_FONT_FACE_TYPE_CFF,
    DWRITE_FONT_FACE_TYPE_TRUETYPE,
    DWRITE_FONT_FACE_TYPE_OPENTYPE_COLLECTION,
    DWRITE_FONT_FACE_TYPE_TYPE1,
    DWRITE_FONT_FACE_TYPE_VECTOR,
    DWRITE_FONT_FACE_TYPE_BITMAP,
    DWRITE_FONT_FACE_TYPE_UNKNOWN,
    DWRITE_FONT_FACE_TYPE_RAW_CFF,
};

pub const DWRITE_FONT_SIMULATIONS = enum(INT) {
    DWRITE_FONT_SIMULATIONS_NONE = 0x0000,
    DWRITE_FONT_SIMULATIONS_BOLD = 0x0001,
    DWRITE_FONT_SIMULATIONS_OBLIQUE = 0x0002,
};

pub const DWRITE_RENDERING_MODE = enum(INT) {
    DWRITE_RENDERING_MODE_DEFAULT,
    DWRITE_RENDERING_MODE_ALIASED,
    DWRITE_RENDERING_MODE_GDI_CLASSIC,
    DWRITE_RENDERING_MODE_GDI_NATURAL,
    DWRITE_RENDERING_MODE_NATURAL,
    DWRITE_RENDERING_MODE_NATURAL_SYMMETRIC,
    DWRITE_RENDERING_MODE_OUTLINE,
};

pub const DWRITE_MEASURING_MODE = enum(INT) {
    DWRITE_MEASURING_MODE_NATURAL,
    DWRITE_MEASURING_MODE_GDI_CLASSIC,
    DWRITE_MEASURING_MODE_GDI_NATURAL,
};

pub const DWRITE_TEXTURE_TYPE = enum(INT) {
    DWRITE_TEXTURE_ALIASED_1x1,
    DWRITE_TEXTURE_CLEARTYPE_3x1,
};

// todo: just pick one if theres two
pub const DWRITE_FONT_WEIGHT = enum(INT) {
    DWRITE_FONT_WEIGHT_THIN = 100,
    DWRITE_FONT_WEIGHT_EXTRA_LIGHT = 200,
    DWRITE_FONT_WEIGHT_LIGHT = 300,
    DWRITE_FONT_WEIGHT_SEMI_LIGHT = 350,
    DWRITE_FONT_WEIGHT_NORMAL = 400,
    DWRITE_FONT_WEIGHT_MEDIUM = 500,
    DWRITE_FONT_WEIGHT_DEMI_BOLD = 600,
    DWRITE_FONT_WEIGHT_BOLD = 700,
    DWRITE_FONT_WEIGHT_EXTRA_BOLD = 800,
    DWRITE_FONT_WEIGHT_BLACK = 900,
    DWRITE_FONT_WEIGHT_EXTRA_BLACK = 950,
};

pub const DWRITE_FONT_STYLE = enum(INT) {
    DWRITE_FONT_STYLE_NORMAL,
    DWRITE_FONT_STYLE_OBLIQUE,
    DWRITE_FONT_STYLE_ITALIC,
};

pub const DWRITE_MATRIX = extern struct {
    m11: FLOAT,
    m12: FLOAT,
    m21: FLOAT,
    m22: FLOAT,
    dx: FLOAT,
    dy: FLOAT,
};

pub const DWRITE_GLYPH_OFFSET = extern struct {
    advanceOffset: FLOAT,
    ascenderOffset: FLOAT,
};

pub const DWRITE_GLYPH_RUN = extern struct {
    fontFace: *IDWriteFontFace,
    fontEmSize: FLOAT,
    glyphCount: UINT32,
    glyphIndices: ?[*]const UINT16,
    glyphAdvances: ?[*]const FLOAT,
    glyphOffsets: ?[*]const DWRITE_GLYPH_OFFSET,
    isSideways: BOOL,
    bidiLevel: UINT32,
};

pub const DWRITE_FONT_METRICS = extern struct {
    designUnitsPerEm: UINT16,
    ascent: UINT16,
    descent: UINT16,
    lineGap: INT16,
    capHeight: UINT16,
    xHeight: UINT16,
    underlinePosition: INT16,
    underlineThickness: UINT16,
    strikethroughPosition: INT16,
    strikethroughThickness: UINT16,
};

pub const DWRITE_GLYPH_METRICS = extern struct {
    leftSideBearing: INT32,
    advanceWidth: UINT32,
    rightSideBearing: INT32,
    topSideBearing: INT32,
    advanceHeight: UINT32,
    bottomSideBearing: INT32,
    verticalOriginY: INT32,
};

pub fn nearestWeight(weight: anytype) error{InvalidWeight}!DWRITE_FONT_WEIGHT {
    @setRuntimeSafety(false);

    // has to be in range of all valid FcWeight values
    if (weight < 1 or weight > 999) {
        return error.InvalidWeight;
    }

    const values = comptime std.enums.values(DWRITE_FONT_WEIGHT);
    const weight_val: u8 = @intCast(weight);

    var best_weight: DWRITE_FONT_WEIGHT = undefined;
    var best_diff: c_uint = undefined;

    inline for (values, 0..) |curr_weight, i| {
        const curr_weight_val = @intFromEnum(curr_weight);
        const diff = @abs(curr_weight_val - weight_val);

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

pub const IUnknown = extern struct {
    vtable: *const IUnknownVTable,

    pub const UUID = &GUID.parse("{00000000-0000-0000-C000-000000000046}");

    pub const QueryInterfaceError = error{
        InterfaceNotFound,
        OutOfMemory,
        Unexpected,
    };

    pub fn QueryInterface(self: *IUnknown, riid: REFIID, ppvObject: **anyopaque) QueryInterfaceError!void {
        const hr = self.vtable.QueryInterface(self, riid, ppvObject);
        return switch (hr) {
            windows.S_OK => {},
            windows.E_OUTOFMEMORY => error.OutOfMemory,
            windows.E_NOINTERFACE => error.InterfaceNotFound,
            windows.E_POINTER => unreachable,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }

    pub inline fn AddRef(self: *IUnknown) ULONG {
        return self.vtable.AddRef(self);
    }

    pub inline fn Release(self: *IUnknown) void {
        _ = self.vtable.Release(self);
    }
};

const IUnknownVTable = extern struct {
    QueryInterface: *const fn (self: *IUnknown, riid: REFIID, ppvObject: **anyopaque) callconv(.winapi) HRESULT,
    AddRef: *const fn (self: *IUnknown) callconv(.winapi) ULONG,
    Release: *const fn (self: *IUnknown) callconv(.winapi) ULONG,
};

pub const IDWriteFactory = extern struct {
    vtable: [*]const *const anyopaque,

    pub const UUID = &GUID.parse("{b859ee5a-d838-4b5b-a2e8-1adc7d93db48}");

    pub inline fn Release(self: *IDWriteFactory) void {
        IUnknown.Release(@ptrCast(self));
    }

    pub const GetSystemFontCollectionError = error{
        OutOfMemory,
        Unexpected,
    };

    pub fn GetSystemFontCollection(self: *IDWriteFactory, checkForUpdates: bool) GetSystemFontCollectionError!*IDWriteFontCollection {
        const FnType = fn (*IDWriteFactory, **IDWriteFontCollection, BOOL) callconv(.winapi) HRESULT;
        const get_system_font_collection: *const FnType = @ptrCast(self.vtable[3]);

        var fontCollection: *IDWriteFontCollection = undefined;

        const hr = get_system_font_collection(self, &fontCollection, @intFromBool(checkForUpdates));
        return switch (hr) {
            windows.S_OK => fontCollection,
            windows.E_OUTOFMEMORY => error.OutOfMemory,
            windows.E_POINTER => unreachable,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }

    pub const CreateFontFileReferenceError = error{
        FontNotFound,
        AccessDenied,
        OutOfMemory,
        Unexpected,
    };

    pub fn CreateFontFileReference(
        self: *IDWriteFactory,
        filePath: [:0]const u16,
        lastWriteTime: ?*const FILETIME,
    ) CreateFontFileReferenceError!*IDWriteFontFile {
        const FnType = fn (*IDWriteFactory, [*:0]const u16, ?*const FILETIME, **IDWriteFontFile) callconv(.winapi) HRESULT;
        const create_font_file_refrence: *const FnType = @ptrCast(self.vtable[7]);

        var fontFile: *IDWriteFontFile = undefined;

        const hr = create_font_file_refrence(self, filePath.ptr, lastWriteTime, &fontFile);
        return switch (hr) {
            windows.S_OK => fontFile,
            -2003283965 => error.FontNotFound,
            windows.E_ACCESSDENIED => error.AccessDenied,
            windows.E_OUTOFMEMORY => error.OutOfMemory,
            windows.E_POINTER => unreachable,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }

    pub const CreateFontFaceError = error{
        OutOfMemory,
        Unexpected,
    };

    pub fn CreateFontFace(
        self: *IDWriteFactory,
        fontFaceType: DWRITE_FONT_FACE_TYPE,
        fontFiles: []const *IDWriteFontFile,
        faceIndex: UINT32,
        fontFaceSimulationFlags: DWRITE_FONT_SIMULATIONS,
    ) CreateFontFaceError!*IDWriteFontFace {
        const FnType = fn (*IDWriteFactory, DWRITE_FONT_FACE_TYPE, UINT32, [*]const *IDWriteFontFile, UINT32, DWRITE_FONT_SIMULATIONS, **IDWriteFontFace) callconv(.winapi) HRESULT;
        const create_font_face: *const FnType = @ptrCast(self.vtable[9]);

        var fontFace: *IDWriteFontFace = undefined;

        const hr = create_font_face(self, fontFaceType, @intCast(fontFiles.len), fontFiles.ptr, faceIndex, fontFaceSimulationFlags, &fontFace);
        return switch (hr) {
            windows.S_OK => fontFace,
            windows.E_OUTOFMEMORY => return error.OutOfMemory,
            windows.E_POINTER => unreachable,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }

    pub const CreateGlyphRunAnalysisError = error{
        OutOfMemory,
        Unexpected,
    };

    pub fn CreateGlyphRunAnalysis(
        self: *IDWriteFactory,
        glyphRun: *const DWRITE_GLYPH_RUN,
        pixelsPerDip: FLOAT,
        transform: ?*const DWRITE_MATRIX,
        renderingMode: DWRITE_RENDERING_MODE,
        measuringMode: DWRITE_MEASURING_MODE,
        baselineOriginX: FLOAT,
        baselineOriginY: FLOAT,
    ) CreateGlyphRunAnalysisError!*IDWriteGlyphRunAnalysis {
        const FnType = fn (*IDWriteFactory, *const DWRITE_GLYPH_RUN, FLOAT, ?*const DWRITE_MATRIX, DWRITE_RENDERING_MODE, DWRITE_MEASURING_MODE, FLOAT, FLOAT, **IDWriteGlyphRunAnalysis) callconv(.winapi) HRESULT;

        const create_glyph_run_analysis: *const FnType = @ptrCast(self.vtable[23]);
        var glyphRunAnalysis: *IDWriteGlyphRunAnalysis = undefined;

        const hr = create_glyph_run_analysis(self, glyphRun, pixelsPerDip, transform, renderingMode, measuringMode, baselineOriginX, baselineOriginY, &glyphRunAnalysis);
        return switch (hr) {
            windows.S_OK => glyphRunAnalysis,
            windows.E_OUTOFMEMORY => error.OutOfMemory,
            windows.E_POINTER => unreachable,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }
};

pub const IDWriteFontFile = extern struct {
    vtable: [*]const *const anyopaque,

    pub inline fn Release(self: *IDWriteFontFile) void {
        IUnknown.Release(@ptrCast(self));
    }

    pub const AnalyzeError = error{
        NotSupported,
        Unexpected,
    };

    pub fn Analyze(
        self: *IDWriteFontFile,
        fontFileType: *DWRITE_FONT_FILE_TYPE,
        fontFaceType: ?*DWRITE_FONT_FACE_TYPE,
        numberOfFaces: *UINT32,
    ) AnalyzeError!void {
        const FnType = fn (*IDWriteFontFile, *BOOL, *DWRITE_FONT_FILE_TYPE, ?*DWRITE_FONT_FACE_TYPE, *UINT32) callconv(.winapi) HRESULT;
        const analyze: *const FnType = @ptrCast(self.vtable[5]);

        var isSupportedFontType: BOOL = undefined;

        const hr = analyze(self, &isSupportedFontType, fontFileType, fontFaceType, numberOfFaces);
        return switch (hr) {
            windows.S_OK => if (isSupportedFontType == windows.TRUE) {} else error.NotSupported,
            windows.E_POINTER => unreachable,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }
};

pub const IDWriteFontFace = extern struct {
    vtable: [*]const *const anyopaque,

    pub inline fn Release(self: *IDWriteFontFace) void {
        IUnknown.Release(@ptrCast(self));
    }

    pub fn GetMetrics(self: *IDWriteFontFace) DWRITE_FONT_METRICS {
        const FnType = fn (*IDWriteFontFace, *DWRITE_FONT_METRICS) callconv(.winapi) void;
        const get_metrics: *const FnType = @ptrCast(self.vtable[8]);

        var fontFaceMetrics: DWRITE_FONT_METRICS = undefined;

        get_metrics(self, &fontFaceMetrics);
        return fontFaceMetrics;
    }

    pub const GetDesignGlyphMetricsError = error{
        Unexpected,
    };

    pub fn GetDesignGlyphMetrics(
        self: *IDWriteFontFace,
        glyphIndices: []const UINT16,
        glyphMetrics: []DWRITE_GLYPH_METRICS,
        isSideways: BOOL,
    ) GetDesignGlyphMetricsError!void {
        assert(glyphIndices.len == glyphMetrics.len);

        const FnType = fn (*IDWriteFontFace, [*]const UINT16, UINT32, [*]DWRITE_GLYPH_METRICS, BOOL) callconv(.winapi) HRESULT;
        const get_design_glyph_metrics: *const FnType = @ptrCast(self.vtable[10]);

        const hr = get_design_glyph_metrics(self, glyphIndices.ptr, @intCast(glyphIndices.len), glyphMetrics.ptr, isSideways);
        return switch (hr) {
            windows.S_OK => {},
            windows.E_POINTER => unreachable,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }

    pub fn GetGlyphIndices(
        self: *IDWriteFontFace,
        codePoints: []const UINT32,
        glyphIndices: []UINT16,
    ) void {
        assert(codePoints.len == glyphIndices.len);

        const FnType = fn (*IDWriteFontFace, [*]const UINT32, UINT32, [*]UINT16) callconv(.winapi) HRESULT;
        const get_glyph_indicies: *const FnType = @ptrCast(self.vtable[11]);

        assert(get_glyph_indicies(self, codePoints.ptr, @intCast(codePoints.len), glyphIndices.ptr) == windows.S_OK);
    }
};

pub const IDWriteGlyphRunAnalysis = extern struct {
    vtable: [*]const *const anyopaque,

    pub inline fn Release(self: *IDWriteGlyphRunAnalysis) void {
        IUnknown.Release(@ptrCast(self));
    }

    pub const GetAlphaTextureBoundsError = error{
        Unexpected,
    };

    pub fn GetAlphaTextureBounds(self: *IDWriteGlyphRunAnalysis, textureType: DWRITE_TEXTURE_TYPE) GetAlphaTextureBoundsError!RECT {
        const FnType = fn (*IDWriteGlyphRunAnalysis, DWRITE_TEXTURE_TYPE, *RECT) callconv(.winapi) HRESULT;
        const get_alpha_texture_bounds: *const FnType = @ptrCast(self.vtable[3]);

        var textureBounds: RECT = undefined;

        const hr = get_alpha_texture_bounds(self, textureType, &textureBounds);
        return switch (hr) {
            windows.S_OK => textureBounds,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }

    pub const CreateAlphaTextureError = error{
        Unexpected,
    };

    pub fn CreateAlphaTexture(self: *IDWriteGlyphRunAnalysis, textureType: DWRITE_TEXTURE_TYPE, textureBounds: *const RECT, alphaValues: []u8) CreateAlphaTextureError!void {
        const FnType = fn (*IDWriteGlyphRunAnalysis, DWRITE_TEXTURE_TYPE, *const RECT, [*]BYTE, UINT32) callconv(.winapi) HRESULT;
        const create_alpha_texture: *const FnType = @ptrCast(self.vtable[4]);

        const hr = create_alpha_texture(self, textureType, textureBounds, alphaValues.ptr, @intCast(alphaValues.len));
        return switch (hr) {
            windows.S_OK => {},
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }
};

pub const IDWriteFontCollection = extern struct {
    vtable: [*]const *const anyopaque,

    pub inline fn Release(self: *IDWriteFontCollection) void {
        IUnknown.Release(@ptrCast(self));
    }

    pub inline fn GetFontFamilyCount(self: *IDWriteFontCollection) UINT32 {
        const FnType = fn (*IDWriteFontCollection) callconv(.winapi) UINT32;
        const get_font_family_count: *const FnType = @ptrCast(self.vtable[3]);

        return get_font_family_count(self);
    }

    pub const GetFontFamilyError = error{
        Unexpected,
    };

    pub fn GetFontFamily(self: *IDWriteFontCollection, index: UINT32) GetFontFamilyError!*IDWriteFontFamily {
        const FnType = fn (*IDWriteFontCollection, UINT32, **IDWriteFontFamily) callconv(.winapi) HRESULT;
        const get_font_family: *const FnType = @ptrCast(self.vtable[4]);

        var fontFamily: *IDWriteFontFamily = undefined;

        const hr = get_font_family(self, index, &fontFamily);
        return switch (hr) {
            windows.S_OK => fontFamily,
            windows.E_OUTOFMEMORY => unreachable, // it said that this func just does simple array access
            windows.E_POINTER => unreachable,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }
};

pub const IDWriteFontFamily = extern struct {
    vtable: [*]const *const anyopaque,

    pub inline fn QueryInterface(self: *IDWriteFontFamily, riid: REFIID, ppvObject: **anyopaque) IUnknown.QueryInterfaceError!void {
        return IUnknown.QueryInterface(@ptrCast(self), riid, ppvObject);
    }

    pub inline fn Release(self: *IDWriteFontFamily) void {
        IUnknown.Release(@ptrCast(self));
    }

    pub inline fn GetFontCount(self: *IDWriteFontFamily) UINT32 {
        return IDWriteFontList.GetFontCount(@ptrCast(self));
    }

    pub inline fn GetFont(self: *IDWriteFontFamily, index: UINT32) IDWriteFontList.GetFontError!*IDWriteFont {
        return IDWriteFontList.GetFont(@ptrCast(self), index);
    }

    pub const GetFamilyNamesError = error{
        OutOfMemory,
        Unexpected,
    };

    pub fn GetFamilyNames(self: *IDWriteFontFamily) GetFamilyNamesError!*IDWriteLocalizedStrings {
        const FnType = fn (*IDWriteFontFamily, **IDWriteLocalizedStrings) callconv(.winapi) HRESULT;
        const get_family_names: *const FnType = @ptrCast(self.vtable[6]);

        var names: *IDWriteLocalizedStrings = undefined;

        const hr = get_family_names(self, &names);
        return switch (hr) {
            windows.S_OK => names,
            windows.E_OUTOFMEMORY => error.OutOfMemory,
            windows.E_POINTER => unreachable,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }
};

pub const IDWriteFontList = extern struct {
    vtable: *const IDWriteFontListVTable,

    pub const UUID = &GUID.parse("{1a0d8438-1d97-4ec1-aef9-a2fb86ed6acb}");

    pub inline fn Release(self: *IDWriteFontList) void {
        return IUnknown.Release(@ptrCast(self));
    }

    pub inline fn GetFontCount(self: *IDWriteFontList) UINT32 {
        return self.vtable.GetFontCount(self);
    }

    pub const GetFontError = error{
        OutOfMemory,
        Unexpected,
    };

    pub fn GetFont(self: *IDWriteFontList, index: UINT32) GetFontError!*IDWriteFont {
        var font: *IDWriteFont = undefined;

        const hr = self.vtable.GetFont(self, index, &font);
        return switch (hr) {
            windows.S_OK => font,
            windows.E_OUTOFMEMORY => error.OutOfMemory,
            windows.E_POINTER => unreachable,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }
};

const IDWriteFontListVTable = extern struct {
    QueryInterface: *const fn (self: *IDWriteFontList, riid: REFIID, ppvObject: **anyopaque) callconv(.winapi) HRESULT,
    AddRef: *const fn (*IDWriteFontList) callconv(.winapi) ULONG,
    Release: *const fn (*IDWriteFontList) callconv(.winapi) ULONG,
    GetFontCollection: *const fn (*IDWriteFontList, fontCollection: **IDWriteFontCollection) callconv(.winapi) HRESULT,
    GetFontCount: *const fn (*IDWriteFontList) callconv(.winapi) UINT32,
    GetFont: *const fn (*IDWriteFontList, index: UINT32, font: **IDWriteFont) callconv(.winapi) HRESULT,
};

pub const IDWriteLocalizedStrings = extern struct {
    vtable: *const IDWriteLocalizedStringsVTable,

    pub inline fn Release(self: *IDWriteLocalizedStrings) void {
        return IUnknown.Release(@ptrCast(self));
    }

    pub inline fn GetCount(self: *IDWriteLocalizedStrings) UINT32 {
        return self.vtable.GetCount(self);
    }

    pub const FindLocaleNameError = error{
        LocaleNameNotFound,
        Unexpected,
    };

    pub fn FindLocaleName(self: *IDWriteLocalizedStrings, localeName: [:0]const u16) FindLocaleNameError!UINT32 {
        var index: UINT32 = undefined;
        var exists: BOOL = undefined;

        const hr = self.vtable.FindLocaleName(self, localeName, &index, &exists);
        return switch (hr) {
            windows.S_OK => if (exists == windows.TRUE) index else error.LocaleNameNotFound,
            windows.E_POINTER => unreachable,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }

    pub fn GetLocaleNameLength(self: *IDWriteLocalizedStrings, index: UINT32) UINT32 {
        var length: UINT32 = undefined;
        // if an idiot passes out of bounds index this could err
        assert(self.vtable.GetLocaleNameLength(self, index, &length) == windows.S_OK);
        return length;
    }

    pub const GetLocaleNameError = error{
        BufferTooSmall,
        Unexpected,
    };

    pub fn GetLocaleName(self: *IDWriteLocalizedStrings, index: UINT32, localeName: []u16) GetLocaleNameError![:0]u16 {
        const length = self.GetLocaleNameLength(index);
        if (length + 1 > localeName.len) {
            @branchHint(.cold);
            return error.BufferTooSmall;
        }

        // if an idiot passes out of bounds index this could err
        const hr = self.vtable.GetLocaleName(self, index, localeName.ptr, length + 1);
        return switch (hr) {
            windows.S_OK => localeName[0..length :0],
            windows.E_POINTER => unreachable,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }

    pub fn GetStringLength(self: *IDWriteLocalizedStrings, index: UINT32) UINT32 {
        var length: UINT32 = undefined;
        // if an idiot passes out of bounds index this could err
        assert(self.vtable.GetStringLength(self, index, &length) == windows.S_OK);
        return length;
    }

    pub const GetStringError = error{
        BufferTooSmall,
        Unexpected,
    };

    pub fn GetString(self: *IDWriteLocalizedStrings, index: UINT32, stringBuffer: []u16) GetStringError![:0]u16 {
        const length = self.GetStringLength(index);
        if (length + 1 > stringBuffer.len) {
            @branchHint(.cold);
            return error.BufferTooSmall;
        }

        const hr = self.vtable.GetString(self, index, stringBuffer.ptr, length + 1);
        return switch (hr) {
            windows.S_OK => stringBuffer[0..length :0],
            windows.E_POINTER => unreachable,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }
};

// this is a bit cursed
const IDWriteLocalizedStringsVTable = extern struct {
    QueryInterface: *const fn (self: *IDWriteFontList, riid: REFIID, ppvObject: **anyopaque) callconv(.winapi) HRESULT,
    AddRef: *const fn (*IDWriteLocalizedStrings) callconv(.winapi) ULONG,
    Release: *const fn (*IDWriteLocalizedStrings) callconv(.winapi) ULONG,
    GetCount: *const fn (*IDWriteLocalizedStrings) callconv(.winapi) UINT32,
    FindLocaleName: *const fn (*IDWriteLocalizedStrings, localeName: [*:0]const WCHAR, index: *UINT32, exists: *BOOL) callconv(.winapi) HRESULT,
    GetLocaleNameLength: *const fn (*IDWriteLocalizedStrings, index: UINT32, length: *UINT32) callconv(.winapi) HRESULT,
    GetLocaleName: *const fn (*IDWriteLocalizedStrings, index: UINT32, localeName: [*]WCHAR, size: UINT32) callconv(.winapi) HRESULT,
    GetStringLength: *const fn (*IDWriteLocalizedStrings, index: UINT32, length: *UINT32) callconv(.winapi) HRESULT,
    GetString: *const fn (*IDWriteLocalizedStrings, index: UINT32, stringBuffer: [*]WCHAR, size: UINT32) callconv(.winapi) HRESULT,
};

pub const IDWriteFont = extern struct {
    vtable: [*]const *const anyopaque,

    pub inline fn Release(self: *IDWriteFont) void {
        IUnknown.Release(@ptrCast(self));
    }

    pub inline fn AddRef(self: *IDWriteFont) ULONG {
        return IUnknown.AddRef(@ptrCast(self));
    }

    pub const GetFontFamilyError = error{
        // tood: figure if this can returned OOM
        Unexpected,
    };

    pub fn GetFontFamily(self: *IDWriteFont) GetFontFamilyError!*IDWriteFontFamily {
        const FnType = fn (*IDWriteFont, **IDWriteFontFamily) callconv(.winapi) HRESULT;
        const get_font_family: *const FnType = @ptrCast(self.vtable[3]);

        var fontFamily: *IDWriteFontFamily = undefined;

        const hr = get_font_family(self, &fontFamily);
        return switch (hr) {
            windows.S_OK => fontFamily,
            windows.E_POINTER => unreachable,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }

    // todo: idk maybe return enum with _ as idk why not
    pub inline fn GetWeight(self: *IDWriteFont) INT {
        const FnType = fn (*IDWriteFont) callconv(.winapi) INT;
        const get_weight: *const FnType = @ptrCast(self.vtable[4]);

        return get_weight(self);
    }

    pub inline fn GetStyle(self: *IDWriteFont) DWRITE_FONT_STYLE {
        const FnType = fn (*IDWriteFont) callconv(.winapi) DWRITE_FONT_STYLE;
        const get_style: *const FnType = @ptrCast(self.vtable[6]);

        return get_style(self);
    }

    pub fn HasCharacter(self: *IDWriteFont, unicodeValue: UINT32) bool {
        const FnType = fn (*IDWriteFont, UINT32, *BOOL) callconv(.winapi) HRESULT;
        const has_character: *const FnType = @ptrCast(self.vtable[12]);

        var exists: BOOL = undefined;
        assert(has_character(self, unicodeValue, &exists) == windows.S_OK);

        return exists == windows.TRUE;
    }

    pub const CreateFontFaceError = error{
        OutOfMemory,
        Unexpected,
    };

    pub fn CreateFontFace(self: *IDWriteFont) CreateFontFaceError!*IDWriteFontFace {
        const FnType = fn (*IDWriteFont, **IDWriteFontFace) callconv(.winapi) HRESULT;
        const create_font_face: *const FnType = @ptrCast(self.vtable[13]);

        var fontFace: *IDWriteFontFace = undefined;

        const hr = create_font_face(self, &fontFace);
        return switch (hr) {
            windows.S_OK => fontFace,
            windows.E_POINTER => unreachable,
            windows.E_OUTOFMEMORY => error.OutOfMemory,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }
};

pub const DWriteCreateFactoryError = error{
    OutOfMemory,
    Unexpected,
};

pub fn DWriteCreateFactory(
    factoryType: DWRITE_FACTORY_TYPE,
    iid: REFIID,
    factory: **IUnknown,
) DWriteCreateFactoryError!void {
    const hr = dwrite.DWriteCreateFactory(factoryType, iid, factory);
    return switch (hr) {
        windows.S_OK => {},
        windows.E_POINTER => unreachable,
        windows.E_OUTOFMEMORY => error.OutOfMemory,
        else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
    };
}
