const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const sdk = b.option([]const u8, "sdk", "Path to the macOS SDK");
    const exe = b.addExecutable(.{
        .name = "tpb",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    const tests = b.addTest(.{
        .name = "tpb",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    if (target.result.os.tag == .macos) {
        exe.root_module.link_libc = true;
        tests.root_module.link_libc = true;

        exe.root_module.addCSourceFiles(.{
            .files = &.{"src/Clip/NSPBBridge.m"},
            .language = .objective_c,
            .flags = &.{"-fobjc-arc"},
        });
        tests.root_module.addCSourceFiles(.{
            .files = &.{"src/Clip/NSPBBridge.m"},
            .language = .objective_c,
            .flags = &.{"-fobjc-arc"},
        });

        if (sdk) |root| {
            for ([_]*std.Build.Module{ exe.root_module, tests.root_module }) |module| {
                module.addSystemFrameworkPath(.{ .cwd_relative = b.pathJoin(&.{ root, "System/Library/Frameworks" }) });
                module.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ root, "usr/include" }) });
                module.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ root, "usr/lib" }) });
            }
        }

        exe.root_module.linkFramework("Cocoa", .{});
        tests.root_module.linkFramework("Cocoa", .{});
    }

    const test_step = b.step("test", "Run tests");
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);

    const interface_step = b.step("interface", "Check interface (compile tests only)");
    const check_interface = b.addInstallArtifact(tests, .{});
    interface_step.dependOn(&check_interface.step);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    run_cmd.addPassthruArgs();
}
