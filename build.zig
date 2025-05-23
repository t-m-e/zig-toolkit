const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("zig_toolkit", .{
        .root_source_file = b.path("toolkit.zig"),
        .target = target,
        .optimize = optimize,
    });
}
