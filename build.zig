const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("handover-zig", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    const main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const docs = main_tests;
    docs.emit_docs = .emit;

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&docs.step);
}
