const std = @import("std");

pub fn buildLib(b: *std.Build, options: anytype) *std.Build.Step.Compile {
    const target = options.target;
    const optimize = options.optimize;

    const directwrite_enabled = options.directwrite_enabled;
    const freetype_enabled = options.freetype_enabled;

    const lib = b.addStaticLibrary(.{
        .name = "harfbuzz",
        .target = target,
        .optimize = optimize,
    });

    const harfbuzz = b.lazyDependency("harfbuzz", .{
        .target = target,
        .optimize = optimize,
    }) orelse return lib;

    lib.linkLibCpp();

    var flags = std.BoundedArray([]const u8, 16){};
    flags.appendAssumeCapacity("-DHAVE_STDBOOL_H=1");

    if (target.result.os.tag != .windows) {
        flags.appendAssumeCapacity("-DHAVE_UNISTD_H=1");
        flags.appendAssumeCapacity("-DHAVE_SYS_MMAN_H=1");
        flags.appendAssumeCapacity("-DHAVE_PTHREAD=1");
    }

    if (directwrite_enabled) {
        lib.linkSystemLibrary("dwrite");
        flags.appendAssumeCapacity("-DHAVE_DIRECTWRITE=1");
    }

    if (freetype_enabled) {
        // todo: build freetype if not a thing
        lib.linkSystemLibrary("freetype2");
        flags.appendAssumeCapacity("-DHAVE_FREETYPE=1");
        flags.appendAssumeCapacity("-DHAVE_FT_GET_VAR_BLEND_COORDINATES=1");
        flags.appendAssumeCapacity("-DHAVE_FT_SET_VAR_BLEND_COORDINATES=1");
        flags.appendAssumeCapacity("-DHAVE_FT_DONE_MM_VAR=1");
        flags.appendAssumeCapacity("-DHAVE_FT_GET_TRANSFORM=1");
    }

    lib.addCSourceFile(.{
        .file = harfbuzz.path("src/harfbuzz.cc"),
        .flags = flags.constSlice(),
    });

    lib.installHeadersDirectory(harfbuzz.path("src"), "", .{
        .include_extensions = &.{ ".h" },
    });

    b.installArtifact(lib);

    return lib;
}
