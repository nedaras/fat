const std = @import("std");

pub fn build(b: *std.Build) void {
    // todo: clean this shit up
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const harfbuzz_deb = b.dependency("harfbuzz", .{
        .target = target,
        .optimize = optimize,
    });

    const harfbuzz = b.addSharedLibrary(.{
        .name = "harfbuzz",
        .target = target,
        .optimize = optimize,
    });

    harfbuzz.linkLibCpp();
    
    if (target.result.os.tag == .windows) {
        harfbuzz.linkSystemLibrary("dwrite");
        harfbuzz.addCSourceFile(.{
            .file = harfbuzz_deb.path("src/harfbuzz.cc"),
            .flags = &.{
                "-DHAVE_STDBOOL_H",
                "-DHAVE_DIRECTWRITE"
            },
        });
    } else {
        harfbuzz.linkSystemLibrary("freetype2");
        harfbuzz.addCSourceFile(.{
            .file = harfbuzz_deb.path("src/harfbuzz.cc"),
            .flags = &.{
                "-DHAVE_STDBOOL_H",
                "-DHAVE_UNISTD_H",
                "-DHAVE_SYS_MMAN_H",
                 "-DHAVE_PTHREAD=1",
                "-DHAVE_FREETYPE=1",
                "-DHAVE_FT_GET_VAR_BLEND_COORDINATES=1",
                "-DHAVE_FT_SET_VAR_BLEND_COORDINATES=1",
                "-DHAVE_FT_DONE_MM_VAR=1",
                "-DHAVE_FT_GET_TRANSFORM=1",
            },
        });
    }

    harfbuzz.installHeadersDirectory(harfbuzz_deb.path("src"), "", .{
        .include_extensions = &.{ ".h" },
    });

    b.installArtifact(harfbuzz);

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

    lib.linkLibrary(harfbuzz);

    if (target.result.os.tag == .windows) {
        lib.linkSystemLibrary("dwrite");
    } else {
        lib.linkSystemLibrary("freetype2");
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
