const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/lib_c.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addStaticLibrary(.{
        .name = "fat",
        .root_module = lib_mod,
    });

    lib.linkLibC();
    lib.installHeader(b.path("include/fat.h"), "fat.h");

    if (target.result.os.tag == .windows) {
        lib.linkSystemLibrary("dwrite");
    } else {
        lib.linkSystemLibrary("freetype");
        lib.addSystemIncludePath(.{ .cwd_relative = "/usr/include/freetype2" });
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
