const std = @import("std");

const CopyAttribute = @import("./attributes.zig").CopyAttribute;
const err = @import("../errors/error.zig").BufferError;
const mem = @import("../memory/mem.zig");

var allocator: std.mem.Allocator = std.heap.page_allocator;

/// structure for owned and referenced buffers
pub const Buffer = struct {
    data: ?[*]u8, // container for the data to be stored/manipulated/used.
    owned: ?[*]u8, // used to see if this struct owns this data or not.
    size: usize, // size of the pointer stored in .data
    position: usize, // current index into .data

    /// initialize a buffer with a specified size
    pub fn init(sz: usize) err!Buffer {
        const buf_slice: []u8 = allocator.alloc(u8, sz) catch {
            return err.InitError;
        };
        const buffer: [*]u8 = buf_slice.ptr;
        return .{ .data = buffer, .owned = buffer, .size = sz, .position = 0 };
    }

    pub fn initEmpty() Buffer {
        return .{ .data = null, .owned = null, .size = 0, .position = 0 };
    }

    /// initialize a copy of another buffer
    pub fn initCopy(self: *Buffer, attr: CopyAttribute) err!Buffer {
        var newBuffer: Buffer = undefined;

        switch (attr) {
            .Copy => {
                // copy the contents of data into a new ownership
                newBuffer = try Buffer.init(self.size);
                mem.copy(newBuffer.data.?, self.*.data.?, self.*.size);
                newBuffer.owned = newBuffer.data;
            },
            .Reference => {
                // reference the contents of data with no ownership
                newBuffer = Buffer.initEmpty();
                newBuffer.data = self.*.data;
                newBuffer.size = self.*.size;
            },
        }

        return newBuffer;
    }

    pub fn initCopyRange(self: *Buffer, pos: usize, size: usize, attr: CopyAttribute) err!Buffer {
        var newBuffer: Buffer = undefined;

        switch (attr) {
            .Copy => {
                newBuffer = try Buffer.init(size);
                const offset: [*]u8 = @ptrFromInt(@intFromPtr(self.*.data) + pos);
                mem.copy(newBuffer.data.?, offset, size);
                newBuffer.owned = newBuffer.data;
            },
            .Reference => {
                newBuffer = Buffer.initEmpty();
                newBuffer.data = self.*.current() orelse return err.InitError;
                newBuffer.size = size;
            },
        }

        return newBuffer;
    }

    pub fn initWithData(data: []u8) err!Buffer {
        const buffer: Buffer = try Buffer.init(data.len);
        mem.copy(buffer.data.?, @constCast(data.ptr), data.len);
        return buffer;
    }

    pub fn get(self: *Buffer, comptime T: type) err!type {
        if (self.*.size == 0 or self.*.data == null) {
            return err.NoData;
        }

        var data: T = std.mem.zeroes(T);
        const size: usize = @sizeOf(T);
        mem.copy(@ptrCast(&data), self.*.data.?, size);

        return data;
    }

    pub fn getCurrent(self: *Buffer, comptime T: type) err!type {
        if (self.*.size == 0 or self.*.data == null) {
            return err.NoData;
        }

        var data: T = std.mem.zeroes(T);
        const size: usize = @sizeOf(T);
        mem.copy(@ptrCast(&data), self.*.current().?, size);

        return data;
    }

    pub fn getSlice(self: *Buffer) ?[]u8 {
        if (self.*.data == null) {
            return null;
        }
        return self.*.data.?[self.position..self.size];
    }

    pub fn current(self: *Buffer) ?[*]u8 {
        if (self.*.data == null) {
            return null;
        }

        var addr = @intFromPtr(self.*.data);
        addr += self.*.position;
        return @ptrFromInt(addr);
    }

    /// zero out memory in .data
    pub fn zero(self: *Buffer) void {
        if ((self.data == null) or (self.size == 0)) {
            return;
        }

        mem.set(self.data.?, 0, self.size);
    }

    /// clear buffer and deallocate memory
    pub fn fini(self: *Buffer) void {
        if (self.data == null) {
            return;
        }

        if (self.owned != null) {
            self.zero();
            if (self.data != null) {
                allocator.destroy(@as(*u8, @alignCast(&self.data.?[0])));
            }
            self.owned = null;
        }

        self.data = null;
        self.size = 0;
        self.position = 0;
    }

    /// reset the memory region allocated
    pub fn reset(self: *Buffer, sz: usize) void {
        self.fini();
        self.* = self.init(sz) orelse unreachable;
    }
};

const testing = std.testing;
test "Buffer.init(sz) test" {
    var buffer: Buffer = try Buffer.init(32);
    try testing.expect(buffer.size == 32);
    try testing.expect(buffer.position == 0);
    try testing.expect(buffer.data != null);
    try testing.expect(buffer.owned != null);

    buffer.fini();
    try testing.expect(buffer.size == 0);
    try testing.expect(buffer.position == 0);
    try testing.expect(buffer.data == null);
    try testing.expect(buffer.owned == null);
}

test "Buffer.initEmpty test" {
    const buffer: Buffer = Buffer.initEmpty();
    try testing.expect(buffer.data == null);
    try testing.expect(buffer.owned == null);
    try testing.expect(buffer.size == 0);
    try testing.expect(buffer.position == 0);
}

test "Buffer.initCopy test" {
    const string: []const u8 = "Hello, world!";
    var buffer: Buffer = try Buffer.init(string.len);
    mem.copy(buffer.data.?, @constCast(string.ptr), string.len);

    var bufferCopy: Buffer = try buffer.initCopy(.Copy);

    try testing.expectEqualStrings(buffer.getSlice().?, bufferCopy.getSlice().?);

    var bufferReference: Buffer = try buffer.initCopy(.Reference);

    try testing.expectEqualStrings(buffer.getSlice().?, bufferReference.getSlice().?);
    try testing.expect(bufferReference.owned == null);
}

test "Buffer.initWithData test" {
    const string: []const u8 = "Hello, world!";
    var buffer: Buffer = try Buffer.initWithData(@constCast(string));
    try testing.expectEqualStrings(buffer.getSlice().?, string);
}

test "Buffer.initCopyRange test" {
    const string: []const u8 = "Hello, world!";
    var buffer: Buffer = try Buffer.initWithData(@constCast(string));
    defer buffer.fini();

    var bufferCopy: Buffer = try buffer.initCopyRange(7, 6, .Copy);
    defer bufferCopy.fini();

    try testing.expectEqualStrings(bufferCopy.getSlice().?, string[7..string.len]);

    var bufferReference: Buffer = try buffer.initCopyRange(0, 5, .Reference);
    defer bufferReference.fini();

    try testing.expectEqualStrings(bufferReference.getSlice().?, string[0..5]);
}
