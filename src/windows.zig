const std = @import("std");
const dwrite = @import("windows/dwrite.zig");
const windows = std.os.windows;
const assert = std.debug.assert;

pub usingnamespace windows;

const INT = windows.INT;
const BOOL = windows.BOOL;
const GUID = windows.GUID;
const RECT = windows.RECT;
const FLOAT = windows.FLOAT;
const ULONG = windows.ULONG;
const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;
const FILETIME = windows.FILETIME;

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
    DWRITE_FONT_SIMULATIONS_NONE    = 0x0000,
    DWRITE_FONT_SIMULATIONS_BOLD    = 0x0001,
    DWRITE_FONT_SIMULATIONS_OBLIQUE = 0x0002
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
    DWRITE_MEASURING_MODE_GDI_NATURAL
};

pub const DWRITE_TEXTURE_TYPE = enum(INT) {
    DWRITE_TEXTURE_ALIASED_1x1,
    DWRITE_TEXTURE_CLEARTYPE_3x1
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

pub const IUnknown = extern struct {
    vtable: *const IUnknownVTable,

    pub const UUID = &GUID.parse("00000000-0000-0000-C000-000000000046{}");

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
    QueryInterface: *const fn (self: *IUnknown, riid: REFIID, ppvObject: **anyopaque) callconv(WINAPI) HRESULT,
    AddRef: *const fn (self: *IUnknown) callconv(WINAPI) ULONG,
    Release: *const fn (self: *IUnknown) callconv(WINAPI) ULONG,
};

pub const IDWriteFactory = extern struct {
    vtable: [*]const *const anyopaque,

    pub const UUID = &GUID.parse("{b859ee5a-d838-4b5b-a2e8-1adc7d93db48}");

    pub inline fn Release(self: *IDWriteFactory) void {
        IUnknown.Release(@ptrCast(self));
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
        const FnType = fn (*IDWriteFactory, [*:0]const u16, ?*const FILETIME, **IDWriteFontFile) callconv(WINAPI) HRESULT;
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
        const FnType = fn (*IDWriteFactory, DWRITE_FONT_FACE_TYPE, UINT32, [*]const *IDWriteFontFile, UINT32, DWRITE_FONT_SIMULATIONS, **IDWriteFontFace) callconv(WINAPI) HRESULT;
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
        const FnType = fn (
            *IDWriteFactory,
            *const DWRITE_GLYPH_RUN,
            FLOAT,
            ?*const DWRITE_MATRIX,
            DWRITE_RENDERING_MODE,
            DWRITE_MEASURING_MODE,
            FLOAT,
            FLOAT,
            **IDWriteGlyphRunAnalysis
        ) callconv(WINAPI) HRESULT;

        const create_glyph_run_analysis: *const FnType = @ptrCast(self.vtable[23]);
        var glyphRunAnalysis: *IDWriteGlyphRunAnalysis = undefined;

        const hr = create_glyph_run_analysis(self, glyphRun, pixelsPerDip, transform, renderingMode, measuringMode, baselineOriginX, baselineOriginY, &glyphRunAnalysis);
        return switch (hr) {
            windows.S_OK => glyphRunAnalysis,
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
        const FnType = fn (*IDWriteFontFile, *BOOL, *DWRITE_FONT_FILE_TYPE, ?*DWRITE_FONT_FACE_TYPE, *UINT32) callconv(WINAPI) HRESULT;
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

    pub fn GetGlyphIndices(
        self: *IDWriteFontFace,
        codePoints: []const UINT32,
        glyphIndices: []UINT16,
    ) void {
        assert(codePoints.len == glyphIndices.len);

        const FnType = fn (*IDWriteFontFace, [*]const UINT32, UINT32, [*]UINT16) callconv(WINAPI) HRESULT;
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
        const FnType = fn (*IDWriteGlyphRunAnalysis, DWRITE_TEXTURE_TYPE, *RECT) callconv(WINAPI) HRESULT;
        const get_alpha_texture_bounds: *const FnType = @ptrCast(self.vtable[4]);

        var textureBounds: RECT = undefined;

        const hr = get_alpha_texture_bounds(self, textureType, &textureBounds);
        return switch (hr) {
            windows.S_OK => textureBounds,
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
