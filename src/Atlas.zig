const std = @import("std");
const heap = std.heap;
const math = std.math;

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

allocator: Allocator,

data: []u8,

size: u32,

nodes: std.DoublyLinkedList(Node),
nodes_pool: heap.MemoryPoolExtra(std.DoublyLinkedList(Node).Node, .{ .growable = true }),

const Atlas = @This();

const Node = struct {
    x: u32,
    y: u32,

    width: u32,
};

const Region = struct {
    x: u32,
    y: u32,

    width: u32,
    height: u32,
};

pub fn init(allocator: Allocator, size: u32) Allocator.Error!Atlas {
    var self: Atlas = .{
        .allocator = allocator,
        .data = try allocator.alloc(u8, size * size),
        .size = size,
        .nodes = .{},
        .nodes_pool = .init(allocator),
    };
    errdefer self.deinit();

    try self.nodes_pool.preheat(64);
    self.clear();

    return self;
}

pub fn deinit(self: *Atlas) void {
    self.allocator.free(self.data);
    self.nodes_pool.deinit();

    self.* = undefined;
}

pub fn clear(self: *Atlas) void {
    @memset(self.data, 0);

    _ = self.nodes_pool.reset(.retain_capacity);

    const node = self.nodes_pool.create() catch unreachable;
    node.* = .{ .data = .{
        .x = 0,
        .y = 0,

        .width = self.size,
    } };

    self.nodes.prepend(node);
}

pub fn reserve(
    self: *Atlas,
    width: u32,
    height: u32,
) !Region {
    var region: Region = .{ .x = 0, .y = 0, .width = width, .height = height };

    const best_node = blk: {
        var best_width: u32 = math.maxInt(u32);
        var best_height: u32 = math.maxInt(u32);

        var selected: ?*std.DoublyLinkedList(Node).Node = null;

        var curr = self.nodes.first;
        while (curr) |node| {
            defer curr = node.next;
            const y = self.baseline(node, width, height) orelse continue;

            if (y + height < best_height or (y + height == best_height and node.data.width < best_width)) {
                selected = node;
                best_width = node.data.width;
                best_height = y + height;

                region.x = node.data.x;
                region.y = y;
            }
        }

        break :blk selected orelse return error.NoSpaceLeft;
    };

    const new_node = try self.nodes_pool.create();
    new_node.* = .{ .data = .{
        .x = region.x,
        .y = region.y + region.height,
        .width = region.width,
    } };

    self.nodes.insertBefore(best_node, new_node);

    var prev = new_node;
    var curr: ?*std.DoublyLinkedList(Node).Node = best_node;

    // loop till we're inside
    while (curr) |node| {
        // inside
        if (prev.data.x + prev.data.width > node.data.x) {
            const move = prev.data.x + prev.data.width - node.data.x;

            node.data.x += move;
            node.data.width -|= move;

            if (node.data.width == 0) {
                curr = node.next;

                self.nodes.remove(node);
                self.nodes_pool.destroy(node);

                continue;
            }

            prev = node;
            curr = node.next;

            continue;
        }
        break;  
    }

    if (new_node.next) |nn| {
        self.merge(new_node, nn);
    }

    if (new_node.prev) |pp| {
        self.merge(pp, new_node);
    }

    return region;
}

fn merge(
    self: *Atlas,
    left: *std.DoublyLinkedList(Node).Node,
    right: *std.DoublyLinkedList(Node).Node
) void {
    if (left.data.y == right.data.y) {
        @branchHint(.cold);

        left.data.width += right.data.width;

        self.nodes.remove(right);
        self.nodes_pool.destroy(right);
    }
}

fn baseline(
    self: Atlas,
    node: *std.DoublyLinkedList(Node).Node,
    width: u32,
    height: u32,
) ?u32 {
    if (node.data.x + width > self.size) {
        return null;
    }

    var y = node.data.y;
    var width_left = width;

    var curr: ?*std.DoublyLinkedList(Node).Node = node;
    while (width_left > 0) {
        defer curr = curr.?.next;
        if (curr.?.data.y + height > self.size) {
            return null;
        }

        y = @max(y, curr.?.data.y);
        width_left -|= curr.?.data.width;
    }

    return y;
}


pub fn dump(self: Atlas, writer: anytype) !void {
    try writer.print(
        \\P{c}
        \\{d} {d}
        \\255
        \\
    , .{
        '5',
        self.size,
        self.size,
    });
    try writer.writeAll(self.data);
}
