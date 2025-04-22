const std = @import("std");

const Buffer = @import("../data_types/buffer.zig").Buffer;
const err = @import("../errors/error.zig").MonoBufError;
const log = @import("../logging/log.zig");
const mem = @import("../memory/mem.zig");
const units = @import("../data_types/units.zig");

const monobufLog = log.genLog(.info, .monobuf, log.logFn);

// 2KB size for serializer buffer
const bufferLength: usize = units.kb(2);

/// Serialize and Deserialize data
pub const MonoBuf = struct {
    buffer: Buffer,

    pub fn init() err!MonoBuf {
        const buffer: Buffer = Buffer.init(bufferLength) catch {
            monobufLog.err("buffer initializtion failed", .{});
            return err.InitError;
        };

        return .{ .buffer = buffer };
    }

    pub fn initWithSize(sz: usize) err!MonoBuf {
        const buffer: Buffer = Buffer.init(sz) catch {
            monobufLog.err("buffer initialization failed", .{});
            return err.InitError;
        };

        return .{ .buffer = buffer };
    }

    pub fn initWithData(data: *Buffer) err!MonoBuf {
        var buffer: Buffer = data.initCopy(.Reference) catch {
            monobufLog.err("buffer copy initialization failed", .{});
            return err.InitError;
        };
        buffer.position = buffer.size;

        return .{ .buffer = buffer };
    }

    pub fn serialize(self: *MonoBuf, comptime T: type, data: T) err!void {
        const size: usize = @sizeOf(T);

        if (self.buffer.position + size > self.buffer.size) {
            monobufLog.err("MonoBuf serializer full!", .{});
            return err.SerializerFull;
        }

        monobufLog.debug("serializing type: {} (size {d})", .{ T, size });

        mem.copy(self.buffer.current().?, @ptrCast(@constCast(&data)), size);
        self.buffer.position += size;
    }

    pub fn deserialize(self: *MonoBuf, comptime T: type) err!T {
        const size: usize = @sizeOf(T);
        var buffer: Buffer = undefined;

        if (self.buffer.position <= 0) {
            monobufLog.err("MonoBuf deserializer empty", .{});
            return err.DeserializerEmpty;
        }

        if (self.buffer.position - size < 0) {
            monobufLog.err("MonoBuf deserializer not enough room for type {T}", .{type});
            return err.DeserializerNotEnough;
        }

        monobufLog.debug("deserializing type: {} (size {})", .{ T, size });

        buffer = self.buffer.initCopyRange(self.buffer.position - size, size, .Copy) catch {
            monobufLog.err("failed to copy from buffer", .{});
            return err.DeserializerBufferCopyFailed;
        };

        var data: T = std.mem.zeroes(T);
        mem.copy(@ptrCast(&data), buffer.data.?, size);

        return data;
    }

    pub fn fini(self: *MonoBuf) void {
        self.buffer.fini();
    }
};

const testing = std.testing;
test "MonoBuf serialization" {
    var monobuf: MonoBuf = try MonoBuf.init();
    defer monobuf.fini();

    try testing.expect(monobuf.buffer.size == bufferLength);

    try monobuf.serialize(u32, 0xd3adc0de);
    try testing.expectEqualStrings(monobuf.buffer.data.?[0..4], "\xde\xc0\xad\xd3");
}

test "MonoBuf serialization with size" {
    var monobuf: MonoBuf = try MonoBuf.initWithSize(4);
    defer monobuf.fini();

    try testing.expect(monobuf.buffer.size == 4);

    try monobuf.serialize(u32, 0xd3adc0de);
    try testing.expectEqualStrings(monobuf.buffer.data.?[0..4], "\xde\xc0\xad\xd3");
}

test "MonoBuf deserialization" {
    const bufData: []const u8 = "\xde\xc0\xad\xd3";
    const buf: Buffer = try Buffer.initWithData(@constCast(bufData));
    var monobuf: MonoBuf = try MonoBuf.initWithData(@constCast(&buf));
    defer monobuf.fini();

    try testing.expectEqual(monobuf.buffer.size, buf.size);

    const data: u32 = try monobuf.deserialize(u32);
    try testing.expect(data == 0xd3adc0de);
}
