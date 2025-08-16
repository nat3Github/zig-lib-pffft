const std = @import("std");
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run unit tests");

    const pffft_translate_c = b.addTranslateC(.{
        .optimize = optimize,
        .target = target,
        .root_source_file = b.path("zig-source/lib.h"),
    });
    pffft_translate_c.addIncludePath(b.path(""));
    const pffft_mod = pffft_translate_c.createModule();
    // pffft_mod.addIncludePath(b.path(""));
    pffft_mod.addCSourceFile(.{
        .file = b.path("pffft.c"),
        .language = .c,
    });
    pffft_mod.addCSourceFile(.{
        .file = b.path("pffft_double.c"),
        .language = .c,
    });
    pffft_mod.addCSourceFile(.{
        .file = b.path("pffft_common.c"),
        .language = .c,
    });

    const root_mod = b.addModule("pffft", .{
        .root_source_file = b.path("zig-source/root.zig"),
        .optimize = optimize,
        .target = target,
    });
    root_mod.addImport("pffft", pffft_mod);

    const lib_test = b.addTest(.{
        .root_module = root_mod,
        .target = target,
        .optimize = optimize,
    });
    const lib_test_run = b.addRunArtifact(lib_test);
    test_step.dependOn(&lib_test_run.step);
}
