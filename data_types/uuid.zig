const std = @import("std");

const Buffer = @import("buffer.zig").Buffer;
const hex = @import("../obfuscation/hex.zig");
const mem = @import("../memory/mem.zig");

pub const nil: []const u8 = "00000000-0000-0000-0000-000000000000";

/// UUID version 7
pub fn uuid7(allocator: std.mem.Allocator) ![]u8 {
    var uuidBuffer: []u8 = try allocator.alloc(u8, 36);
    var value: [16]u8 = undefined;
    const timestamp: u48 = @intCast(std.time.milliTimestamp());

    std.mem.writeInt(u48, value[0..6], timestamp, .big);
    std.crypto.random.bytes(value[6..]);

    value[6] = (value[6] & 0x0f) | 0x70;
    value[8] = (value[8] & 0x3f) | 0x80;

    const encoded: []u8 = try hex.encode(&value, allocator);
    defer allocator.free(encoded);

    mem.copy(@ptrCast(uuidBuffer.ptr), @ptrCast(encoded.ptr), 8);
    uuidBuffer[8] = '-';
    mem.copy(@ptrFromInt(@intFromPtr(uuidBuffer.ptr) + 9), @ptrFromInt(@intFromPtr(encoded.ptr) + 8), 4);
    uuidBuffer[13] = '-';
    mem.copy(@ptrFromInt(@intFromPtr(uuidBuffer.ptr) + 14), @ptrFromInt(@intFromPtr(encoded.ptr) + 12), 4);
    uuidBuffer[18] = '-';
    mem.copy(@ptrFromInt(@intFromPtr(uuidBuffer.ptr) + 19), @ptrFromInt(@intFromPtr(encoded.ptr) + 16), 4);
    uuidBuffer[23] = '-';
    mem.copy(@ptrFromInt(@intFromPtr(uuidBuffer.ptr) + 24), @ptrFromInt(@intFromPtr(encoded.ptr) + 20), 12);

    return uuidBuffer;
}

const testing = std.testing;
test "uuid7 generate" {
    const uuid = try uuid7(testing.allocator);
    defer testing.allocator.free(uuid);

    std.debug.print("uuid => {s}\n", .{uuid});
}

test "uuid nil value" {
    const nil_value = nil;
    try testing.expectEqualStrings(nil_value, nil);
}
