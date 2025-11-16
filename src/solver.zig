const Board = @import("board.zig").Board;
const std = @import("std");

pub const Move = u6;
pub const MoveSeq = struct {
    data: [18]Move,
    len: u5,
};

pub const TriangleSearch = struct {
    const Queue = std.PriorityQueue(State, void, compare);

    /// Solver only cares about solutions that are 18 or lower
    const MAX_SOLVE = 18;
    const Moves = [MAX_SOLVE]u6;

    /// A snapshot of a board and how we got there
    const State = struct {
        board: Board,
        moves: MoveSeq,
        priority: f64,
    };

    const COL_MASKS: [Board.WIDTH]u64 = Board.col_bit_mask();

    var best_moves_count: u64 = 200;
    queues: [MAX_SOLVE]Queue,

    fn compare(_: void, a: State, b: State) std.math.Order {
        return std.math.order(a.priority, b.priority);
    }

    pub fn init(allocator: std.mem.Allocator) TriangleSearch {
        return TriangleSearch{ .queues = q: {
            var queues: [18]Queue = undefined;
            for (0..MAX_SOLVE) |i| {
                queues[i] = Queue.init(allocator, {});
            }
            break :q queues;
        } };
    }

    pub fn deinit(self: *TriangleSearch) void {
        for (self.queues) |queue| {
            queue.deinit();
        }
    }

    pub fn expand(self: *TriangleSearch, state: State) !void {
        const tile_groups = state.board.get_all_groups();
        for (tile_groups.slice()) |g| {
            if (state.moves.len >= MAX_SOLVE) continue;

            var new_moves = state.moves.data;
            new_moves[@intCast(state.moves.len)] = g.pos;

            const new_board = state.board.apply_move(g.pos);
            const lb = lower_bound(new_board);

            // prune branches that cannot beat current best or exceed max moves
            if (lb + state.moves.len + 1 >= best_moves_count or lb + state.moves.len >= MAX_SOLVE) {
                continue;
            }
            const child = State{
                .board = new_board,
                .moves = MoveSeq{
                    .data = new_moves,
                    .len = state.moves.len + 1,
                },
                .priority = @as(f64, @floatFromInt(new_board.get_all_groups().count)),
            };

            try self.queues[state.moves.len].add(child);
        }
    }

    pub fn solve(self: *TriangleSearch, board: Board) ?MoveSeq {
        for (0..MAX_SOLVE) |i| self.queues[i].clearRetainingCapacity();

        var timer = std.time.Timer.start() catch return null;

        const initial = State{
            .board = board,
            .moves = undefined,
            .priority = @floatFromInt(board.get_all_groups().count),
        };

        // insert root at depth 0
        var best_moves: ?MoveSeq = null;

        var iterations: u64 = 0;
        const MAX_ITER: u64 = 1_000_000_000_000; // Let allocated memory decide the limit, but have this high number here

        self.expand(initial) catch return best_moves;

        for (0..MAX_SOLVE) |maxDepth| {
            for (0..maxDepth) |depth| {
                if (self.queues[depth].items.len == 0) continue;
                const state = self.queues[depth].remove();
                iterations += 1;
                // return best moves if we run out of memory
                self.expand(state) catch return best_moves;
            }
        }

        while (iterations < MAX_ITER) {
            for (0..MAX_SOLVE) |depth| {
                if (self.queues[depth].items.len == 0) continue;
                iterations += 1;

                const state = self.queues[depth].remove();
                if (iterations > MAX_ITER) {
                    // stop if we ran too long; if we have a best solution keep it as anytime result
                    if (best_moves == null) return best_moves;
                    break;
                }
                // std.debug.print("Took {d} seconds\n", .{bit_counts_stddev(&state.moves.data)});

                if (state.moves.len < best_moves_count and state.board.is_solved()) {
                    best_moves = state.moves;
                    best_moves_count = @as(u64, state.moves.len);
                    const time_ns = timer.read();
                    const time_s = @as(f64, @floatFromInt(time_ns)) / @as(f64, 1_000_000_000.0);
                    std.debug.print("Solution with {d} clicks. Looked at {d} nodes. - click{any}\n", .{ state.moves.len, iterations, state.moves.data });
                    std.debug.print("Took {d} seconds\n", .{time_s});
                    continue;
                }

                // return best moves if we run out of memory
                self.expand(state) catch return best_moves;
            }
        }

        return best_moves;
    }

    /// number of moves you must at least have to clear the board
    fn lower_bound(board: Board) u64 {
        var total_groups: u64 = 0;

        for (0..Board.COLOR_COUNT) |color_idx| {
            const bits: u64 = board.state[color_idx];
            var groups_for_color: u64 = 0;
            var in_group: bool = false;

            for (0..Board.WIDTH) |col| {
                const present = (bits & COL_MASKS[col]) != 0;
                if (present) {
                    if (!in_group) {
                        groups_for_color += 1;
                        in_group = true;
                    }
                } else {
                    in_group = false;
                }
            }

            total_groups += groups_for_color;
        }

        return total_groups;
    }
};
