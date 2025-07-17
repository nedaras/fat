const std = @import("std");
const build_options = @import("build_options.zig");
const libharfbuzz = @import("build/libharfbuzz.zig");

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

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/lib_c.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_mod.addImport("build_options", options_mod);

    const lib = b.addStaticLibrary(.{
        .name = "fat",
        .root_module = lib_mod,
    });

    lib.linkLibC();
    lib.installHeader(b.path("include/fat.h"), "fat.h");

    if (b.systemIntegrationOption("harfbuzz", .{})) {
        lib.linkSystemLibrary("harfbuzz");
    } else {
        const harfbuzz = libharfbuzz.buildLib(b, .{
            .target = target,
            .optimize = optimize,
            .directwrite_enabled = font_backend == .Directwrite,
            .freetype_enabled = font_backend.hasFreetype(),
        });
        lib.linkLibrary(harfbuzz);
    }

    if (font_backend == .Directwrite) {
        lib.linkSystemLibrary("dwrite");
    }

    if (font_backend.hasFreetype()) {
        lib.linkSystemLibrary("freetype2");
    }

    if (font_backend == .FontconfigFreetype) {
        lib.linkSystemLibrary("fontconfig");
    }

    b.installArtifact(lib);

    const exe_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "fat",
        .root_module = exe_mod,
    });

    exe.linkLibC();
    exe.linkLibrary(lib);

    exe.addCSourceFile(.{ .file = b.path("main.c") });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
