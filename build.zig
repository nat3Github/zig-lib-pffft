const std = @import("std");
const update = @import("update_tool");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const pffft_translate_c = b.addTranslateC(.{
        .optimize = optimize,
        .target = target,
        .root_source_file = b.path("zig-source/lib.h"),
    });
    pffft_translate_c.addIncludePath(b.path(""));
    const pffft_c_mod = pffft_translate_c.createModule();
    // pffft_mod.addIncludePath(b.path(""));
    pffft_c_mod.addCSourceFile(.{
        .file = b.path("pffft.c"),
        .language = .c,
    });
    pffft_c_mod.addCSourceFile(.{
        .file = b.path("pffft_double.c"),
        .language = .c,
    });
    pffft_c_mod.addCSourceFile(.{
        .file = b.path("pffft_common.c"),
        .language = .c,
    });

    const root_mod = b.addModule("pffft", .{
        .root_source_file = b.path("zig-source/root.zig"),
        .optimize = optimize,
        .target = target,
    });
    root_mod.addImport("pffft_c", pffft_c_mod);

    try update.addTestFolder(b, "zig-tests", optimize, target, &.{.{ .mod = root_mod, .name = "pffft" }}, "test");
}
