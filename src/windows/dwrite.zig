const windows = @import("../windows.zig");

const REFIID = windows.REFIID;
const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;
const IUnknown = windows.IUnknown;
const DWRITE_FACTORY_TYPE = windows.DWRITE_FACTORY_TYPE;

pub extern "dwrite" fn DWriteCreateFactory(
    factoryType: DWRITE_FACTORY_TYPE,
    iid: REFIID,
    factory: **IUnknown,
) callconv(WINAPI) HRESULT;
