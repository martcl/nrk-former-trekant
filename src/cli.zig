const std = @import("std");
const Board = @import("board.zig").Board;
const TriangleSearch = @import("solver.zig").TriangleSearch;
const Alea = @import("random.zig").Alea;
const c_time = @cImport(@cInclude("time.h"));
const crypto = @import("std").crypto;

const Date = struct {
    day: u8,
    month: u8,
    year: u16,
};

const CliArguments = struct {
    /// bytes of memory
    memory: u64,
    date: ?Date,
    help: bool,
};

const ParseError = error{ InvalidDate, MissingValue, InvalidNumber, UnknownArg };

fn parse_u64(s: []const u8) ?u64 {
    var v: u64 = 0;
    if (s.len == 0) return null;
    for (s) |c| {
        if (c < '0' or c > '9') return null;
        v = v * 10 + @as(u64, @intCast(c - '0'));
    }
    return v;
}

fn parse_date(s: []const u8) !Date {
    if (s.len != 10) return ParseError.InvalidDate;
    if (s[2] != '-' or s[5] != '-') return ParseError.InvalidDate;

    const day_slice = s[0..2];
    const month_slice = s[3..5];
    const year_slice = s[6..10];

    const day_opt = parse_u64(day_slice) orelse return ParseError.InvalidNumber;
    const month_opt = parse_u64(month_slice) orelse return ParseError.InvalidNumber;
    const year_opt = parse_u64(year_slice) orelse return ParseError.InvalidNumber;

    if (day_opt < 1 or day_opt > 31) return ParseError.InvalidDate;
    if (month_opt < 1 or month_opt > 12) return ParseError.InvalidDate;
    if (year_opt == 0) return ParseError.InvalidDate;

    return Date{
        .day = @intCast(day_opt),
        .month = @intCast(month_opt - 1),
        .year = @intCast(year_opt),
    };
}

/// Parse command line arguments from the given Args iterator.
/// Recognized:
///   --help              -> sets help = true
///   --memory <bytes>   -> sets memory (u64 bytes)
///   <DD-MM-YYYY>        -> parsed as date
pub fn parse_args(args: *std.process.ArgIterator) !CliArguments {
    var out = CliArguments{ .memory = 0, .date = null, .help = false };

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help")) {
            out.help = true;
            continue;
        } else if (std.mem.eql(u8, arg, "--memory")) {
            const val = args.next() orelse return ParseError.MissingValue;
            const num = parse_u64(val) orelse return ParseError.InvalidNumber;
            out.memory = num;
            continue;
        } else {
            // Try parse as date DD-MM-YYYY
            // Accept only one date; ignore other positional args
            if (out.date == null) {
                const d = try parse_date(arg);
                out.date = d;
                continue;
            }
            return error.UnknownArg;
        }
    }

    return out;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const argAllocator = gpa.allocator();
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(argAllocator);
    defer args.deinit();
    _ = args.next(); // skip program name

    var parsed = parse_args(&args) catch |err| {
        std.debug.print("{any}", .{err});
        return;
    };

    if (parsed.help) {
        std.debug.print("Usage: nrkformer [--help] [--memory <bytes>] [DD-MM-YYYY]\n", .{});
        return;
    }

    // if nothing is specified, we allocate 1 GB
    const mem_bytes: usize = if (parsed.memory != 0) @intCast(parsed.memory) else 1024 * 1024 * 1024;

    if (parsed.date == null) {
        const now: c_time.time_t = c_time.time(null);
        const gmt_info = c_time.gmtime(&now);

        parsed.date = Date{
            .day = @intCast(gmt_info.*.tm_mday),
            .month = @intCast(gmt_info.*.tm_mon),
            .year = @intCast(gmt_info.*.tm_year + 1900),
        };
    }

    var seed_owned: []const u8 = undefined;
    defer argAllocator.free(seed_owned);

    if (parsed.date) |d| {
        const buf = std.fmt.allocPrint(std.heap.page_allocator, "{d}{d}{d}", .{ d.day, d.month, d.year }) catch "00";

        var tmp_seed: [16]u8 = undefined;
        crypto.hash.Md5.hash(buf[0..], &tmp_seed, .{});
        const hex = std.fmt.allocPrint(argAllocator, "{x}", .{tmp_seed}) catch "hex-fail";

        seed_owned = hex;
    }

    var alea = Alea.init(seed_owned);
    var board = Board.init().with_alea(&alea);

    std.debug.print("# current board\n", .{});
    board.print();

    const buffer = try std.heap.page_allocator.alloc(u8, mem_bytes);
    defer std.heap.page_allocator.free(buffer);

    var fixed_buffer_alloc = std.heap.FixedBufferAllocator.init(buffer);
    const allocator = fixed_buffer_alloc.allocator();

    var solver = TriangleSearch.init(allocator);
    defer solver.deinit();

    const solution = solver.solve(board);

    if (solution) |moves| {
        std.debug.print("Solution found with length {d}\n", .{moves.len});

        for (moves.data[0..moves.len]) |pos| {
            board = board.apply_move(pos);
            if (board.is_solved()) {
                break;
            }
            const p = Board.pos_to_human_pos(pos);
            std.debug.print("# click ({d}, {d}) \n", .{ p.x, p.y });
            board.print();
        }
    } else {
        std.debug.print("No solution found\n", .{});
    }
}
