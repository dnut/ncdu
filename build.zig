// SPDX-FileCopyrightText: Yorhel <projects@yorhel.nl>
// SPDX-License-Identifier: MIT

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const pie = b.option(bool, "pie", "Build with PIE support (by default: target-dependant)");
    const strip = b.option(bool, "strip", "Strip debugging info (by default false)") orelse false;

    // --- ncdu main --------------------------------------

    const main_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
        .link_libc = true,
    });
    main_mod.linkSystemLibrary("ncursesw", .{});
    main_mod.linkSystemLibrary("zstd", .{});

    const exe = b.addExecutable(.{
        .name = "ncdu",
        .root_module = main_mod,
        .use_llvm = true,
    });
    exe.pie = pie;
    // https://github.com/ziglang/zig/blob/faccd79ca5debbe22fe168193b8de54393257604/build.zig#L745-L748
    if (target.result.os.tag.isDarwin()) {
        // useful for package maintainers
        exe.headerpad_max_install_names = true;
    }
    const install_exe = b.addInstallArtifact(exe, .{});
    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);

    // --- tests ------------------------------------------

    const unit_tests = b.addTest(.{
        .root_module = main_mod,
        .use_llvm = true,
    });
    unit_tests.pie = pie;
    const install_unit_tests = b.addInstallArtifact(unit_tests, .{});
    const run_unit_tests = b.addRunArtifact(unit_tests);

    // --- top level steps --------------------------------

    // the default step: `zig build`
    b.install_tls.description = "Build ncdu and copy to prefix path.";
    b.getInstallStep().dependOn(&install_exe.step);

    const run_step = b.step("run", "Run ncdu.");
    run_step.dependOn(&install_exe.step);
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run unit tests.");
    test_step.dependOn(&install_unit_tests.step);
    test_step.dependOn(&run_unit_tests.step);

    const all_step = b.step("all", "Build everything and copy artifacts to prefix path.");
    all_step.dependOn(&install_exe.step);
    all_step.dependOn(&install_unit_tests.step);
}
