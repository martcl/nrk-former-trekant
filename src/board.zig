const std = @import("std");
const Alea = @import("random.zig").Alea;

pub const Board = struct {
    pub const Color = enum {
        ORANGE,
        PINK,
        GREEN,
        BLUE,
    };

    pub const WIDTH = 7;
    pub const HEIGHT = 9;
    pub const TOTAL_POSITIONS = WIDTH * HEIGHT;
    pub const COLOR_COUNT = 4;

    const COL_MASKS: [Board.WIDTH]u64 = Board.col_bit_mask();

    state: [COLOR_COUNT]u64,

    /// Creates an empty board
    pub fn init() Board {
        return Board{ .state = .{ 0, 0, 0, 0 } };
    }

    /// Fills the board with random colors
    pub fn with_random_colors(self: Board, rand: std.Random) Board {
        var board = self;
        for (0..TOTAL_POSITIONS) |pos| {
            const color: Color = @enumFromInt(@as(u64, @intFromFloat(std.math.floor(std.Random.float(rand, f64) * 4))));
            board.set_tile_color(@intCast(pos), color);
        }
        return board;
    }

    pub fn with_alea(self: Board, alea: *Alea) Board {
        var board = self;
        for (0..TOTAL_POSITIONS) |pos| {
            // std.debug.print("{d}\n", .{@as(u64, @intFromFloat(std.math.floor(rand.next() * 4)))});
            const color: Color = @enumFromInt(@as(u64, @intFromFloat(std.math.floor(alea.float() * 4))));
            board.set_tile_color(@intCast(pos), color);
        }
        return board;
    }

    /// Fills the board with a predefined colors
    pub fn with_defined(self: Board, map: [HEIGHT][WIDTH]Color) Board {
        var board = self;
        board.state = .{ 0, 0, 0, 0 };

        // map is [HEIGHT][WIDTH] with row-major order: map[row][col]
        for (0..Board.HEIGHT) |row| {
            for (0..Board.WIDTH) |col| {
                const color = map[row][col];
                const pos: u6 = @intCast(row * Board.WIDTH + col);
                board.set_tile_color(pos, color);
            }
        }

        return board;
    }

    /// Uses X, Y cordinates and converts them to cordinates on the board
    inline fn human_pos_to_int(x: u6, y: u6) u6 {
        std.debug.assert(x < WIDTH);
        std.debug.assert(y < HEIGHT);
        return y * WIDTH + x;
    }

    /// Returns valid neighboring positions to a pos
    fn get_valid_neighbors(pos: u6) [4]?u6 {
        const row = pos / WIDTH;
        const col = pos % WIDTH;

        var neighbors: [4]?u6 = .{ null, null, null, null };

        if (row > 0) {
            neighbors[0] = pos - WIDTH;
        }
        if (row < HEIGHT - 1) {
            neighbors[1] = pos + WIDTH;
        }
        if (col > 0) {
            neighbors[2] = pos - 1;
        }
        if (col < WIDTH - 1) {
            neighbors[3] = pos + 1;
        }

        return neighbors;
    }

    fn remove_tile_with_color(self: *Board, pos: u6, color: Color) void {
        const bit: u64 = @as(u64, 1) << @as(u6, @intCast(pos));
        self.state[@intFromEnum(color)] &= ~bit;
    }

    fn set_tile_color(self: *Board, pos: u6, color: Color) void {
        const bit: u64 = @as(u64, 1) << @as(u6, @intCast(pos));
        self.state[@intFromEnum(color)] |= bit;
    }

    /// Removes tiles with matching colors adjesent to the tile on position.
    /// Returns how many tiles was removed.
    fn remove_group_at(self: *Board, pos: u6) u6 {
        const target_color = self.pos_to_color(pos) orelse return 0;

        var buffer: [24]u6 = undefined;
        var stack = std.ArrayList(u6).initBuffer(&buffer);
        var count: u6 = 0;

        stack.appendAssumeCapacity(pos);

        while (stack.pop()) |p| {
            count += 1;
            self.remove_tile_with_color(p, target_color);

            const neighbors = Board.get_valid_neighbors(p);

            for (neighbors) |n| {
                if (n) |neighbor_pos| {
                    const found_color = self.pos_to_color(neighbor_pos);
                    if (found_color == target_color) {
                        stack.appendAssumeCapacity(neighbor_pos);
                    }
                }
            }
        }

        return count;
    }

    /// A collection of tiles adjecent to each other with the same color
    const Group = struct {
        /// number of tiles inside the group
        size: u6,
        /// position of one tile in the group
        pos: u6,
    };

    const GroupResult = struct {
        groups: [63]Group,
        count: u6,

        pub fn slice(self: *const GroupResult) []const Group {
            return self.groups[0..self.count];
        }
    };

    pub fn get_all_groups(self: Board) GroupResult {
        var result = GroupResult{ .groups = undefined, .count = 0 };
        var board_copy = self;
        for (0..TOTAL_POSITIONS) |pos| {
            const group_size = board_copy.remove_group_at(@intCast(pos));
            if (group_size > 0) {
                result.groups[result.count] = Group{ .size = group_size, .pos = @intCast(pos) };
                result.count += 1;
            }
        }

        return result;
    }

    fn apply_gravity(self: *Board) void {
        for (0..WIDTH) |col| {
            var buffer: [HEIGHT]Color = undefined;
            var count: u6 = 0;

            var row: u6 = HEIGHT - 1;
            while (true) {
                const color = self.pos_to_color(Board.human_pos_to_int(@intCast(col), @intCast(row)));
                if (color) |found_color| {
                    buffer[@intCast(count)] = found_color;
                    count += 1;
                }
                if (row == 0) break;
                row -= 1;
            }

            // Reset the column in each color
            for (0..self.state.len) |i| {
                self.state[i] &= ~COL_MASKS[col];
            }

            var i: u6 = 0;
            while (i < count) {
                const dest_row: u6 = HEIGHT - 1 - i;
                self.set_tile_color(Board.human_pos_to_int(@intCast(col), @intCast(dest_row)), buffer[@intCast(i)]);
                i += 1;
            }
        }
    }

    /// returns the color on the given position, null otherwise.
    fn pos_to_color(self: Board, pos: u6) ?Color {
        for (0..Board.COLOR_COUNT) |color_idx| {
            const bit: u64 = @as(u64, 1) << @as(u6, @intCast(pos));
            if ((self.state[color_idx] & bit) != 0) {
                return @as(Color, @enumFromInt(color_idx));
            }
        }
        return null;
    }

    /// Print the board
    pub fn print(self: Board) void {
        for (0..HEIGHT) |row| {
            for (0..WIDTH) |col| {
                const fcolor: ?Color = self.pos_to_color(@intCast(row * WIDTH + col));
                if (fcolor) |color| {
                    switch (color) {
                        .ORANGE => {
                            std.debug.print("O ", .{});
                        },
                        .BLUE => {
                            std.debug.print("B ", .{});
                        },
                        .PINK => {
                            std.debug.print("P ", .{});
                        },
                        .GREEN => {
                            std.debug.print("G ", .{});
                        },
                    }
                } else {
                    std.debug.print("- ", .{});
                }
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn is_solved(self: Board) bool {
        return (self.state[0] | self.state[1] | self.state[2] | self.state[3]) == 0;
    }

    pub fn apply_move(self: Board, pos: u6) Board {
        var new_board = self;
        _ = new_board.remove_group_at(pos);
        new_board.apply_gravity();
        return new_board;
    }

    const HumanPos = struct { x: u6, y: u6 };

    pub fn pos_to_human_pos(pos: u6) HumanPos {
        const row = pos / WIDTH;
        const col = pos % WIDTH;

        return HumanPos{ .x = col, .y = row };
    }

    pub fn col_bit_mask() [Board.WIDTH]u64 {
        var m: [Board.WIDTH]u64 = undefined;
        for (0..Board.WIDTH) |col| {
            var mask: u64 = 0;
            for (0..Board.HEIGHT) |row| {
                const pos: u64 = @as(u64, row * Board.WIDTH + col);
                mask |= (@as(u64, 1) << pos);
            }
            m[col] = mask;
        }

        return m;
    }
};

test "position to color lookup" {
    var prng = std.Random.DefaultPrng.init(1);
    const rand = prng.random();

    var board = Board.init().with_random_colors(rand);
    try std.testing.expectEqual(Board.Color.ORANGE, board.pos_to_color(Board.human_pos_to_int(1, 1)));
    try std.testing.expectEqual(Board.Color.GREEN, board.pos_to_color(Board.human_pos_to_int(3, 1)));
    try std.testing.expectEqual(Board.Color.PINK, board.pos_to_color(Board.human_pos_to_int(4, 5)));
    try std.testing.expectEqual(Board.Color.GREEN, board.pos_to_color(Board.human_pos_to_int(0, 0)));
    try std.testing.expectEqual(null, board.pos_to_color(63));
    try std.testing.expectEqual(Board.Color.GREEN, board.pos_to_color(62));
}

test "remove adjesent tiles with the same color" {
    var prng = std.Random.DefaultPrng.init(5);
    const rand = prng.random();

    var board = Board.init().with_random_colors(rand);

    try std.testing.expectEqual(6, board.remove_group_at(9));
    try std.testing.expectEqual(1, board.remove_group_at(0));
    try std.testing.expectEqual(2, board.remove_group_at(2));
}

test "gravity test" {
    var prng = std.Random.DefaultPrng.init(5);
    const rand = prng.random();

    var board = Board.init().with_random_colors(rand);
    board.print();

    try std.testing.expectEqual(6, board.remove_group_at(9));
    board.print();
    board.apply_gravity();
    board.print();
}

test "groups" {
    var prng = std.Random.DefaultPrng.init(1);
    const rand = prng.random();

    var board = Board.init().with_random_colors(rand);
    board.print();

    const group_result = board.get_all_groups();
    const groups = group_result.slice();

    std.debug.print("groups: {d}\n", .{groups.len});

    for (groups) |group| {
        std.debug.print("s: {d}, p:{d}\n", .{ group.size, group.pos });
    }
}

test "board size" {
    std.debug.print("{d}b\n", .{@sizeOf(Board)});
}
