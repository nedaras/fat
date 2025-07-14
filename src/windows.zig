const std = @import("std");
const dwrite = @import("windows/dwrite.zig");
const windows = std.os.windows;

const INT = windows.INT;
const GUID = windows.GUID;
const ULONG = windows.ULONG;
const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;

pub const REFIID = *const GUID;

pub const DWRITE_FACTORY_TYPE = enum(INT) {
    DWRITE_FACTORY_TYPE_SHARED,
    DWRITE_FACTORY_TYPE_ISOLATED,
};

pub usingnamespace windows;

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
