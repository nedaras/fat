const std = @import("std");
const collection = @import("../collection.zig");
const Allocator = std.mem.Allocator;

pub const DefferedFace = struct {
    pub fn family(_: DefferedFace) [:0]const u8 {
        return "";
    }

    pub fn deinit(_: DefferedFace) void {}
};

pub const FontIterator = struct {
    pub fn init(_: void, _: Allocator, _: collection.Descriptor) !FontIterator {
        return .{};
    }

    pub fn deinit(_: FontIterator) void {}

    pub fn next(_: *FontIterator) !?DefferedFace {
        return null;
    }
};
