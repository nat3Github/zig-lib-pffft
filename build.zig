const std = @import("std");

const Mod = struct {
    name: []const u8,
    mod: *std.Build.Module,
};

fn addTestFolder(
    b: *std.Build,
    test_folder_sub_path: []const u8,
    optimize: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
    modules: []const Mod,
    step_name: []const u8,
) !void {
    const io = b.graph.io;
    const all_tests_step = b.step(
        b.fmt("{s}-all", .{step_name}),
        b.fmt("run all tests of {s}", .{step_name}),
    );

    const test_dir = b.path(test_folder_sub_path);
    var dir = try b.build_root.handle.openDir(io, test_folder_sub_path, .{
        .iterate = true,
    });
    defer dir.close(io);
    var it = dir.iterate();
    while (try it.next(io)) |e| {
        if (e.kind == .file and std.mem.endsWith(u8, e.name, ".zig")) {
            const mod = b.createModule(.{
                .root_source_file = test_dir.path(b, e.name),
                .optimize = optimize,
                .target = target,
            });
            for (modules) |m| {
                mod.addImport(m.name, m.mod);
            }
            const exe = b.addExecutable(.{
                .root_module = mod,
                .name = b.fmt("{s}", .{e.name}),
            });
            b.installArtifact(exe);
            const exe_run = b.addRunArtifact(exe);
            const test_ = b.addTest(.{
                .root_module = mod,
            });
            const run_ = b.addRunArtifact(test_);
            const step = b.step(
                b.fmt("{s}-{s}", .{ step_name, e.name }),
                b.fmt("run test for {s}", .{e.name}),
            );
            step.dependOn(&run_.step);
            step.dependOn(&exe_run.step);
            all_tests_step.dependOn(step);
        }
    }
}

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

    const c_flags: []const []const u8 = &.{ "-DPFFFT_ENABLE_NEON", "-O3" };

    pffft_c_mod.addCSourceFile(.{
        .file = b.path("pffft.c"),
        .language = .c,
        .flags = c_flags,
    });
    pffft_c_mod.addCSourceFile(.{
        .file = b.path("pffft_double.c"),
        .language = .c,
        .flags = c_flags,
    });
    pffft_c_mod.addCSourceFile(.{
        .file = b.path("pffft_common.c"),
        .language = .c,
        .flags = c_flags,
    });

    const root_mod = b.addModule("pffft", .{
        .root_source_file = b.path("zig-source/root.zig"),
        .optimize = optimize,
        .target = target,
    });
    root_mod.addImport("pffft_c", pffft_c_mod);

    try addTestFolder(b, "zig-tests", optimize, target, &.{.{ .mod = root_mod, .name = "pffft" }}, "test");
}
