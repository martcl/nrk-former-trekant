const std = @import("std");

pub const Alea = struct {
    s0: f64,
    s1: f64,
    s2: f64,
    c: i64,

    pub fn init(seed: []const u8) Alea {
        var mash = Mash{};
        var s0 = mash.mash(" ");
        var s1 = mash.mash(" ");
        var s2 = mash.mash(" ");

        s0 = s0 - mash.mash(seed);
        if (s0 < 0) {
            s0 += 1;
        }
        s1 = s1 - mash.mash(seed);
        if (s1 < 0) {
            s1 += 1;
        }
        s2 = s2 - mash.mash(seed);
        if (s2 < 0) {
            s2 += 1;
        }

        return Alea{ .s0 = s0, .s1 = s1, .s2 = s2, .c = 1 };
    }

    pub fn float(self: *Alea) f64 {
        const t: f64 = @as(f64, 2091639.0) * @as(f64, self.s0) + @as(f64, @floatFromInt(self.c)) * @as(f64, 2.3283064365386963e-10);
        self.s0 = @as(f64, self.s1);
        self.s1 = @as(f64, self.s2);
        self.s2 = @as(f64, t) - @as(f64, @floatFromInt(@as(i64, @intFromFloat(t))));
        self.c = @as(i64, @intFromFloat(t));

        return @as(f64, self.s2);
    }
};

pub const Mash = struct {
    var n: f64 = 0xefc8249d;

    pub fn mash(_: Mash, data: []const u8) f64 {
        for (data) |byte| {
            n += @as(f64, @floatFromInt(byte));
            var h = @as(f64, 0.02519603282416938) * @as(f64, n);
            n = @as(f64, @floatFromInt(@as(u32, @intFromFloat(h))));
            h = @as(f64, h) - @as(f64, n);
            h = @as(f64, h) * @as(f64, n);
            n = @as(f64, @floatFromInt(@as(u32, @intFromFloat(h))));
            h = @as(f64, h) - @as(f64, n);
            n = @as(f64, n) + @as(f64, h) * @as(f64, 4294967296.0);
        }
        return @as(f64, @floatFromInt(@as(u32, @intFromFloat(n)))) * @as(f64, 2.3283064365386963e-10);
    }
};

test "mash test" {
    const mash = Mash{};
    try std.testing.expect(mash.mash(" ") == 0.8633289230056107);
}

test "random float" {
    var alea = Alea.init("b768567efdc6f0c0a3957782f16e18c7");
    try std.testing.expect(alea.float() == 0.7580593577586114);
}
