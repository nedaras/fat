const std = @import("std");
const build_options = @import("build_options.zig");

const FontBackend = build_options.FontBackend;

pub fn build(b: *std.Build) void {
    // todo: clean this shit up
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const font_backend = b.option(
        FontBackend,
        "font-backend",
        "The font backend to use for discovery and rasterization.",
    ) orelse FontBackend.default(target.result);

    const options_mod = b.createModule(.{
        .root_source_file = b.path("build_options.zig"),
        .target = target,
        .optimize = optimize,
    });

    const options = b.addOptions();
    options.addOption(FontBackend, "font_backend", font_backend);

    options_mod.addOptions("build_options", options);

    // bad but will work it out we need like c options
    const lib_mod = b.addModule("fat", .{
        .root_source_file = b.path("src/library.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_mod.addImport("build_options", options_mod);

    const lib = b.addLibrary(.{
        .name = "fat",
        .root_module = lib_mod,
    });

    //lib.installHeader(b.path("include/fat.h"), "fat.h");

    if (font_backend == .Directwrite) {
        lib.linkSystemLibrary("dwrite");
    }

    if (font_backend.hasFreetype()) {
        lib.linkLibC();
        lib.linkSystemLibrary("freetype2");
    }

    if (font_backend == .FontconfigFreetype) {
        lib.linkSystemLibrary("fontconfig");
    }

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
