const std = @import("std");

// function to get the max height between 2 trees
fn max(lhs: isize, rhs: isize) isize {
    return if (lhs > rhs) lhs else rhs;
}

pub fn AvlNode(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T, // data type being stored
        left: ?*Self,
        right: ?*Self,
        depth: isize,

        pub fn init(allocator: std.mem.Allocator, value: T, lhs: ?*Self, rhs: ?*Self) !*Self {
            var node: *Self = try allocator.create(Self);
            node.value = value;
            node.left = lhs;
            node.right = rhs;
            node.depth = 1;

            return node;
        }

        pub fn height(node: ?*Self) isize {
            return if (node == null) 0 else node.?.depth;
        }

        pub fn balance(self: ?*Self) isize {
            return if (self == null) 0 else (Self.height(self.?.left) - Self.height(self.?.right));
        }

        pub fn minValueNode(self: ?*Self) *Self {
            var current: ?*Self = self;

            while (current != null) {
                current = current.?.left;
            }

            return current.?;
        }

        pub fn rotate(self: ?*Self, dir: enum { left, right }) *Self {
            var base: ?*Self = undefined;
            var alt: ?*Self = undefined;

            switch (dir) {
                .left => {
                    base = if (self != null) self.?.right else null;
                    alt = if (base != null) base.?.left else null;

                    if (base) |n| {
                        n.left = self;
                    }
                    self.?.right = alt;
                },
                .right => {
                    base = if (self != null) self.?.left else null;
                    alt = if (base != null) base.?.right else null;

                    if (base) |n| {
                        n.right = self;
                    }
                    self.?.left = alt;
                },
            }

            if (self != null) {
                self.?.depth = max(Self.height(self.?.left), Self.height(self.?.right)) + 1;
            }
            if (base != null) {
                base.?.depth = max(Self.height(base.?.left), Self.height(base.?.right)) + 1;
            }

            return if (base != null) base.? else self.?;
        }

        pub fn insert(self: ?*Self, allocator: std.mem.Allocator, value: T, cmpFn: *fn (lhs: T, rhs: T) isize) !*Self {
            if (self == null) {
                return try Self.init(allocator, value, null, null);
            }

            if (cmpFn(value, self.?.value) < 0) {
                self.?.left = try Self.insert(self.?.left, allocator, value, cmpFn);
            } else if (cmpFn(value, self.?.value) > 0) {
                self.?.right = try Self.insert(self.?.right, allocator, value, cmpFn);
            } else {
                return self.?;
            }

            self.?.depth = max(Self.height(self.?.left), Self.height(self.?.right)) + 1;

            const bal: isize = self.?.balance();
            if ((bal > 1) and (self.?.left != null) and (value < self.?.left.?.value)) {
                return self.?.rotate(.right);
            }
            if ((bal < -1) and (self.?.right != null) and (value > self.?.right.?.value)) {
                return self.?.rotate(.left);
            }
            if ((bal > 1) and (self.?.left != null) and (value > self.?.left.?.value)) {
                self.?.left = self.?.left.?.rotate(.left);
                return self.?.rotate(.right);
            }
            if ((bal < -1) and (self.?.right != null) and (value < self.?.right.?.value)) {
                self.?.right = self.?.right.?.rotate(.right);
                return self.?.rotate(.left);
            }

            return self.?;
        }

        pub fn delete(self: ?*Self, allocator: std.mem.Allocator, value: T, cmpFn: *fn (lhs: T, rhs: T) isize) !?*Self {
            if (self == null) {
                return self;
            }

            if (cmpFn(value, self.?.value) < 0) {
                self.?.left = try Self.delete(self.?.left, allocator, value, cmpFn);
            } else if (cmpFn(value, self.?.value) > 0) {
                self.?.right = try Self.delete(self.?.right, allocator, value, cmpFn);
            } else {
                var tmp: ?*Self = null;
                if (self.?.left == null or self.?.right == null) {
                    tmp = if (self.?.left != null) self.?.left else self.?.right;
                    if (tmp == null) {
                        allocator.destroy(self.?);
                        return null;
                    } else {
                        self.?.* = tmp.?.*;
                    }

                    allocator.destroy(tmp.?);
                } else {
                    tmp = self.?.minValueNode();
                    self.?.value = tmp.?.value;

                    self.?.right = try Self.delete(self.?.right, allocator, value, cmpFn);
                }
            }

            if (self == null) {
                return self.?;
            }

            self.?.depth = max(Self.height(self.?.left), Self.height(self.?.right)) + 1;

            const bal: isize = self.?.balance();
            if ((bal > 1) and (self.?.left != null) and (self.?.left.?.balance() >= 0)) {
                return self.?.rotate(.right);
            }
            if ((bal > 1) and (self.?.left != null) and (self.?.left.?.balance() < 0)) {
                self.?.left = self.?.left.?.rotate(.left);
                return self.?.rotate(.right);
            }
            if ((bal < -1) and (self.?.right != null) and (self.?.right.?.balance() <= 0)) {
                return self.?.rotate(.left);
            }
            if ((bal < -1) and (self.?.right != null) and (self.?.right.?.balance() > 0)) {
                self.?.right = self.?.right.?.rotate(.right);
                return self.?.rotate(.left);
            }

            return self.?;
        }

        pub fn search(self: ?*Self, value: T, cmpFn: *fn (lhs: T, rhs: T) isize) ?*Self {
            if (self == null) {
                return self;
            }

            if (cmpFn(value, self.?.value) < 0) {
                return Self.search(self.?.left, value, cmpFn);
            } else if (cmpFn(value, self.?.value) > 0) {
                return Self.search(self.?.right, value, cmpFn);
            } else {
                return self;
            }
        }
    };
}

pub fn AvlTree(comptime T: type) type {
    return struct {
        const Self = @This();

        root: ?*AvlNode(T),
        cmpFn: *fn (lhs: T, rhs: T) isize,

        pub fn insert(self: *Self, allocator: std.mem.Allocator, value: T) !void {
            if (self.root == null) {
                self.root = try AvlNode(T).init(allocator, value, null, null);
            } else {
                self.root = try self.root.?.insert(allocator, value, self.cmpFn);
            }
        }

        pub fn delete(self: *Self, allocator: std.mem.Allocator, value: T) !void {
            if (self.root == null) {
                return;
            } else {
                self.root = try self.root.?.delete(allocator, value, self.cmpFn);
            }
        }

        pub fn search(self: *Self, value: T) ?*AvlNode(T) {
            if (self.root == null) {
                return null;
            } else {
                return AvlNode(T).search(self.root, value, self.cmpFn);
            }
        }

        fn cleanNodes(allocator: std.mem.Allocator, node: ?*AvlNode(T)) void {
            if (node == null) return;

            cleanNodes(allocator, node.?.left);
            cleanNodes(allocator, node.?.right);
            allocator.destroy(node.?);
        }

        pub fn cleanAll(self: *Self, allocator: std.mem.Allocator) void {
            cleanNodes(allocator, self.root);
        }

        pub fn inOrderTraversal(node: ?*AvlNode(T)) void {
            if (node == null) return;

            inOrderTraversal(node.?.left);
            std.debug.print("{any} -> ", .{node.?.value});
            inOrderTraversal(node.?.right);
        }
    };
}

const testing = std.testing;
test "AVL Tree Insertion" {
    const cmp = struct {
        fn func(lhs: i32, rhs: i32) isize {
            if (lhs > rhs) {
                return 1;
            } else if (lhs < rhs) {
                return -1;
            } else {
                return 0;
            }
        }
    };

    var tree: AvlTree(i32) = .{ .root = null, .cmpFn = @constCast(&cmp.func) };

    try tree.insert(testing.allocator, 5);
    try tree.insert(testing.allocator, 6);
    try tree.insert(testing.allocator, 7);
    try tree.insert(testing.allocator, 8);
    try tree.insert(testing.allocator, 1);
    try tree.insert(testing.allocator, 2);
    try tree.insert(testing.allocator, 3);
    try tree.insert(testing.allocator, 4);
    try tree.insert(testing.allocator, 9);

    AvlTree(i32).inOrderTraversal(tree.root);
    std.debug.print("\n", .{});

    try tree.delete(testing.allocator, 7);
    try tree.delete(testing.allocator, 1);

    AvlTree(i32).inOrderTraversal(tree.root);
    std.debug.print("\n", .{});

    const node = tree.search(9);
    try testing.expect(node != null);

    tree.cleanAll(testing.allocator);
}
