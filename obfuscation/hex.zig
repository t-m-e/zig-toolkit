const Buffer = @import("../data_types/buffer.zig").Buffer;
const err = @import("../errors/error.zig").ObfuscationError;
const log = @import("../logging/log.zig");

const hexLog = log.genLog(.debug, .hex, log.logFn);

const table = "0123456789ABCDEF";

pub fn encode(buffer: []u8, allocator: std.mem.Allocator) ![]u8 {
    var encodeBuffer: []u8 = try allocator.alloc(u8, buffer.len * 2);
    var encodePos: usize = 0;

    for (buffer) |byte| {
        const pos1: usize = @intCast(byte >> 4);
        const pos2: usize = @intCast(0x0f & byte);
        encodeBuffer[encodePos] = table[pos1];
        encodeBuffer[encodePos + 1] = table[pos2];
        encodePos += 2;
    }

    return encodeBuffer;
}

pub fn decode(buffer: []u8, allocator: std.mem.Allocator) ![]u8 {
    if (buffer.len % 2 != 0) {
        return error{oops}.oops;
    }

    var decodeBuffer: []u8 = try allocator.alloc(u8, buffer.len / 2);
    var decodePos: usize = 0;
    var encodePos: usize = 0;

    while (encodePos < buffer.len) : (encodePos += 2) {
        var x: u8 = buffer[encodePos];
        var y: u8 = buffer[encodePos + 1];

        if (x >= 'A' and x <= 'F') {
            x = x - 'A' + 10;
        } else {
            x = x - '0';
        }

        if (y >= 'A' and y <= 'F') {
            y = y - 'A' + 10;
        } else {
            y = y - '0';
        }

        const byte: u8 = (x << 4) + y;
        decodeBuffer[decodePos] = byte;
        decodePos += 1;
    }

    return decodeBuffer;
}

const std = @import("std");
const testing = std.testing;
test "Hex encode" {
    const str: []const u8 = "Hello, world";
    const encoded: []u8 = try encode(@constCast(str), testing.allocator);
    defer testing.allocator.free(encoded);

    try testing.expectEqualStrings("48656C6C6F2C20776F726C64", encoded);
}

test "Hex decode" {
    const str: []const u8 = "48656C6C6F2C20776F726C64";
    const decoded: []u8 = try decode(@constCast(str), testing.allocator);
    defer testing.allocator.free(decoded);

    try testing.expectEqualStrings("Hello, world", decoded);
}
