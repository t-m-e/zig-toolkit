const std = @import("std");

const mem = @import("../memory/mem.zig");

const pad: u8 = '=';
const table: []const u8 =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
const decodeTable = [_]u8{ 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 62, 0xff, 0xff, 0xff, 63, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 0xff, 0xff, 0xff, 0xff, 0xff };

pub fn encode(buffer: []u8, allocator: std.mem.Allocator) ![]u8 {
    const encodeBufferSize: usize = 4 * ((buffer.len + 2) / 3);
    var encodeBuffer: []u8 = try allocator.alloc(u8, encodeBufferSize);
    mem.set(@ptrCast(encodeBuffer), 0, encodeBufferSize);

    var j: usize = 0;
    var i: usize = 0;
    while (i < buffer.len) : (i += 3) {
        const x: u8 = if (i < buffer.len)
            buffer[i]
        else
            0;
        const y: u8 = if (i + 1 < buffer.len)
            buffer[i + 1]
        else
            0;
        const z: u8 = if (i + 2 < buffer.len)
            buffer[i + 2]
        else
            0;

        switch (buffer.len - i) {
            1 => {
                encodeBuffer[j] = table[(0xfc & x) >> 2];
                encodeBuffer[j + 1] = table[(0x03 & x) << 4];
                encodeBuffer[j + 2] = pad;
                encodeBuffer[j + 3] = pad;
            },
            2 => {
                encodeBuffer[j] = table[(0xfc & x) >> 2];
                encodeBuffer[j + 1] = table[((0x03 & x) << 4) + ((0xf0 & y) >> 4)];
                encodeBuffer[j + 2] = table[((0x0f & y) << 2)];
                encodeBuffer[j + 3] = pad;
            },
            else => {
                encodeBuffer[j] = table[(0xfc & x) >> 2];
                encodeBuffer[j + 1] = table[((0x03 & x) << 4) + ((0xf0 & y) >> 4)];
                encodeBuffer[j + 2] = table[((0x0f & y) << 2) + ((0xc0 & z) >> 6)];
                encodeBuffer[j + 3] = table[(0x3f & z)];
            },
        }

        j += 4;
    }

    return encodeBuffer;
}

pub fn decode(buffer: []u8, allocator: std.mem.Allocator) ![]u8 {
    if (buffer.len % 4 != 0) {
        return error{oops}.oops;
    }

    var decodeBufferSize: usize = (buffer.len / 4) * 3;
    if (buffer[decodeBufferSize - 1] == pad) {
        decodeBufferSize -= 1;
    }
    if (buffer[decodeBufferSize - 2] == pad) {
        decodeBufferSize -= 1;
    }

    var decodeBuffer: []u8 = try allocator.alloc(u8, decodeBufferSize);
    mem.set(@ptrCast(decodeBuffer), 0, decodeBufferSize);

    var decodePos: usize = 0;
    var encodePos: usize = 0;
    while (encodePos < buffer.len) {
        const pos = encodePos;
        const a: u8 = if (buffer[pos] == '=')
            0
        else
            decodeTable[buffer[pos]];
        const b: u8 = if (buffer[pos + 1] == '=')
            0
        else
            decodeTable[buffer[pos + 1]];
        const c: u8 = if (buffer[pos + 2] == '=')
            0
        else
            decodeTable[buffer[pos + 2]];
        const d: u8 = if (buffer[pos + 3] == '=')
            0
        else
            decodeTable[buffer[pos + 3]];
        encodePos = pos + 4;

        const x: u8 = (a << 2) | ((0x30 & b) >> 4);
        const y: u8 = ((0x0f & b) << 4) | ((0x3c & c) >> 2);
        const z: u8 = ((0x03 & c) << 6) | d;

        decodeBuffer[decodePos] = x;
        decodeBuffer[decodePos + 1] = y;
        decodeBuffer[decodePos + 2] = z;
        decodePos += 3;
    }

    return decodeBuffer;
}

const testing = @import("std").testing;
test "base64 encode" {
    const str: []const u8 = "Hello, world";
    const expected: []const u8 = "SGVsbG8sIHdvcmxk";
    const encodedBuffer: []u8 = try encode(@constCast(str), testing.allocator);
    defer testing.allocator.free(encodedBuffer);

    try testing.expectEqualStrings(expected, encodedBuffer);
}

test "base64 decode" {
    const encodedStr: []const u8 = "SGVsbG8sIHdvcmxk";
    const expected: []const u8 = "Hello, world";
    const decodedBuffer: []u8 = try decode(@constCast(encodedStr), testing.allocator);
    defer testing.allocator.free(decodedBuffer);

    try testing.expectEqualStrings(expected, decodedBuffer);
}
