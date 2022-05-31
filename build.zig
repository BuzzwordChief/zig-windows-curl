const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("zig-updater", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    switch (target.getOsTag()) {
        .windows => {
            exe.addIncludeDir("deps\\curl\\win\\include");
            exe.addLibraryPath("deps\\curl\\win\\lib");

            exe.linkLibC(); //exe.linkSystemLibrary("MSVCRT");
            exe.addObjectFile("deps\\curl\\win\\lib\\libcurl.dll.a");
            b.installFile("deps\\curl\\win\\bin\\libcurl-x64.dll", "bin\\libcurl-x64.dll");
        },
        else => @panic("Not implemented"),
    }

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
