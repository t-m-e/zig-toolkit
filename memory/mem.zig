/// copy memory from the src to the dst
pub fn copy(dst: [*]u8, src: [*]u8, size: usize) void {
    var i: usize = 0;
    while (i < size) : (i += 1) {
        dst[i] = src[i];
    }
}

/// set memory
pub fn set(dst: [*]u8, val: u8, size: usize) void {
    var i: usize = 0;
    while (i < size) : (i += 1) {
        dst[i] = val;
    }
}

/// compare memory
pub fn compare(a: [*]u8, b: [*]u8, size: usize) bool {
    // just a basic check to see if the memory in a is the same as b
    var i: usize = 0;
    while (i < size) : (i += 1) {
        if (a[i] != b[i]) {
            return false;
        }
    }
    return true;
}

const testing = @import("std").testing;
test "memory copy" {
    var dst: [9]u8 = .{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    var src: [9]u8 = .{0} ** 9;
    copy(&dst, &src, 9);

    try testing.expectEqual(dst, src);

    const Vec2 = struct { x: u32, y: u32 };
    var dst_vec2: Vec2 = .{ .x = 1, .y = 2 };
    var src_vec2: Vec2 = .{ .x = 0, .y = 0 };
    copy(@ptrCast(&dst_vec2), @ptrCast(&src_vec2), @sizeOf(Vec2));

    try testing.expectEqual(dst_vec2, src_vec2);
}

test "memory set" {
    var dst: [9]u8 = .{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    set(&dst, 0, dst.len);

    try testing.expectEqual(dst, [9]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0 });

    const Vec2 = struct { x: u32, y: u32 };
    var dst_vec2: Vec2 = .{ .x = 31, .y = 1001 };
    set(@ptrCast(&dst_vec2), 0, @sizeOf(Vec2));

    try testing.expectEqual(dst_vec2, Vec2{ .x = 0, .y = 0 });
}

test "memory compare" {
    var a: [4]u8 = .{ 1, 2, 3, 4 };
    var b: [4]u8 = .{ 1, 2, 3, 4 };
    var c: [4]u8 = .{ 1, 3, 2, 4 };

    var result: bool = compare(@ptrCast(&a), @ptrCast(&b), 4);
    try testing.expectEqual(result, true);

    result = compare(@ptrCast(&a), @ptrCast(&c), 4);
    try testing.expectEqual(result, false);
}
