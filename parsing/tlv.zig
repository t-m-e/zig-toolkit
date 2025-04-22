const std = @import("std");
const mem = @import("../memory/mem.zig");

// === [ TLV Serialization Types ] ===

pub const TlvTag = enum(u8) {
    // Default error type
    None,
    // Integer Types
    I8,
    I16,
    I32,
    I64,
    I128,
    Isize,
    U8,
    U16,
    U32,
    U64,
    U128,
    Usize,

    // Floating Point Types
    F32,
    F64,

    // String Types
    String,

    // Struct Types
};

// === [ TLV Helper Functions ] ===

fn is_integer(comptime T: type) bool {
    return switch (T) {
        i8, i16, i32, i64, i128, isize, u8, u16, u32, u64, u128, usize => true,
        else => false,
    };
}

fn is_float(comptime T: type) bool {
    return switch (T) {
        f32, f64 => true,
        else => false,
    };
}

fn is_string(comptime T: type) bool {
    return switch (T) {
        []const u8 => true,
        else => false,
    };
}

// === [ TLV Serialization ] ===

pub fn Serializer(comptime T: type, data: T, allocator: std.mem.Allocator) ![]u8 {
    var ser_type: SerializerType = if (is_integer(T)) try IntegerSerializer(T, data, allocator) else if (is_float(T)) try FloatSerializer(T, data, allocator) else if (is_string(T)) try StringSerializer(T, data, allocator) else .{ .type = 0, .length = 0, .value = undefined };
    defer ser_type.fini(allocator);

    return try ser_type.encode(allocator);
}

pub fn Deserializer(comptime T: type, data: []u8, allocator: std.mem.Allocator) !T {
    const tag: u8 = data[0];
    var length: u16 = undefined;
    mem.copy(@ptrCast(&length), @ptrFromInt(@intFromPtr(data.ptr) + 1), 2);
    const value: []u8 = try allocator.alloc(u8, @as(usize, length));
    mem.copy(value.ptr, @ptrFromInt(@intFromPtr(data.ptr) + 3), length);

    var deser_type: DeserializerType = .{
        .type = tag,
        .length = length,
        .value = value,
    };
    defer allocator.free(deser_type.value);

    return deser_type.decode(T, allocator);
}

pub const SerializerType = struct {
    const typeSize: usize = 1;
    const lengthSize: usize = 2;

    type: u8, // type from TlvTag
    length: u16, // length of value field
    value: []u8, // serialized value data

    pub fn encode(self: *SerializerType, allocator: std.mem.Allocator) ![]u8 {
        const encoding: []u8 = try allocator.alloc(u8, typeSize + lengthSize + self.value.len);
        const offset: usize = @intFromPtr(encoding.ptr);

        mem.copy(@ptrFromInt(offset), @ptrCast(&self.type), typeSize);
        mem.copy(@ptrFromInt(offset + typeSize), @ptrCast(&self.length), lengthSize);
        mem.copy(@ptrFromInt(offset + typeSize + lengthSize), self.value.ptr, self.value.len);

        return encoding;
    }

    pub fn decode(self: *SerializerType, data: []u8, allocator: std.mem.Allocator) void {
        self.type = data[0];
        mem.copy(@ptrCast(&self.length), @ptrFromInt(@intFromPtr(data.ptr) + typeSize), lengthSize);
        self.value = try allocator.alloc(u8, self.length);
        mem.copy(@ptrCast(self.value.ptr), @ptrFromInt(@intFromPtr(data.ptr) + typeSize + lengthSize), data.len - typeSize - lengthSize);
    }

    pub fn fini(self: *SerializerType, allocator: std.mem.Allocator) void {
        allocator.free(self.value);
    }
};

pub const DeserializerType = struct {
    const typeSize: usize = 1;
    const lengthSize: usize = 2;

    type: u8,
    length: u16,
    value: []u8,

    pub fn decode(self: *DeserializerType, comptime T: type, allocator: std.mem.Allocator) !T {
        var value: T = undefined;
        switch (@typeInfo(T)) {
            .pointer => {
                value = try allocator.alloc(u8, self.length);
            },
            else => {
                if (@sizeOf(T) != self.length) {
                    return error{oops}.oops;
                }
            },
        }

        mem.copy(@ptrCast(&value), self.value.ptr, self.length);
        return value;
    }
};

fn IntegerSerializer(comptime T: type, data: T, allocator: std.mem.Allocator) !SerializerType {
    const length: u16 = @as(u16, @sizeOf(T));
    const tag: u8 = @intFromEnum(switch (T) {
        i8 => TlvTag.I8,
        i16 => TlvTag.I16,
        i32 => TlvTag.I32,
        i64 => TlvTag.I64,
        i128 => TlvTag.I128,
        isize => TlvTag.Isize,
        u8 => TlvTag.U8,
        u16 => TlvTag.U16,
        u32 => TlvTag.U32,
        u64 => TlvTag.U64,
        u128 => TlvTag.U128,
        usize => TlvTag.Usize,
        else => {
            return error{oops}.oops;
        },
    });

    const value: []u8 = try allocator.alloc(u8, length);
    mem.copy(@ptrCast(value.ptr), @ptrCast(@constCast(&data)), length);

    return .{ .type = tag, .length = length, .value = value };
}

fn FloatSerializer(comptime T: type, data: T, allocator: std.mem.Allocator) !SerializerType {
    const length: u16 = @as(u16, @sizeOf(T));
    const tag: u8 = @intFromEnum(switch (T) {
        f32 => TlvTag.F32,
        f64 => TlvTag.F64,
        else => {
            return error{oops}.oops;
        },
    });

    const value: []u8 = try allocator.alloc(u8, length);
    mem.copy(@ptrCast(value.ptr), @ptrCast(&data), length);

    return .{ .type = tag, .length = length, .value = value };
}

fn StringSerializer(comptime T: type, data: T, allocator: std.mem.Allocator) !SerializerType {
    const info = @typeInfo(T);
    if (info != .pointer) {
        return error{oops}.oops;
    }

    const length: u16 = @truncate(data.len);
    const tag: u8 = @intFromEnum(switch (T) {
        []const u8 => TlvTag.String,
        else => {
            return error{oops}.oops;
        },
    });

    const value: []u8 = try allocator.alloc(u8, length);
    mem.copy(@ptrCast(value.ptr), @constCast(@ptrCast(data.ptr)), data.len);

    return .{ .type = tag, .length = length, .value = value };
}

// === [ TLV Iterative Serialization ] ===

// Create a serializer that adds serialized data to an iterative buffer.

// === [ TESTING ] ===

const testing = std.testing;
const hex = @import("../obfuscation/hex.zig");

test "Serialize U8" {
    const value: u8 = 125;
    const pack: []u8 = try Serializer(u8, value, testing.allocator);
    defer testing.allocator.free(pack);

    const encoded: []u8 = try hex.encode(pack, testing.allocator);
    defer testing.allocator.free(encoded);

    std.debug.print("serializer encoded: {s}\n", .{encoded});
}

test "Serialize String" {
    const value: []const u8 = "Hello, world!";
    const pack: []u8 = try Serializer([]const u8, value, testing.allocator);
    defer testing.allocator.free(pack);

    const encoded: []u8 = try hex.encode(pack, testing.allocator);
    defer testing.allocator.free(encoded);

    std.debug.print("serializer encoded: {s}\n", .{encoded});
}

test "Deserialize U8" {
    const encoded: []const u8 = "0701007D";
    const decoded: []u8 = try hex.decode(@constCast(encoded), testing.allocator);
    defer testing.allocator.free(decoded);

    const value: u8 = try Deserializer(u8, decoded, testing.allocator);

    std.debug.print("deserializer decoded: {d}\n", .{value});
}

test "Deserialize String" {
    const encoded: []const u8 = "0F0D0048656C6C6F2C20776F726C6421";
    const decoded: []u8 = try hex.decode(@constCast(encoded), testing.allocator);
    defer testing.allocator.free(decoded);

    const value: []const u8 = try Deserializer([]const u8, decoded, testing.allocator);

    std.debug.print("deserializer decoded: {s}\n", .{value});
}
