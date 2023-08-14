const math = @import("math.zig");

pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub fn zero() @This() {
        return Vec2{ .x = 0, .y = 0 };
    }

    pub fn add(a: @This(), b: @This()) @This() {
        return .{ .x = a.x + b.x, .y = a.y + b.y };
    }

    pub fn sub(a: @This(), b: @This()) @This() {
        return .{ .x = a.x - b.x, .y = a.y - b.y };
    }

    pub fn itemwiseProd(a: @This(), b: @This()) @This() {
        return .{ .x = a.x * b.x, .y = a.y * b.y };
    }

    pub fn dot(a: @This(), b: @This()) f32 {
        return a.x * b.x + a.y * b.y;
    }

    pub fn rotate(v: @This(), angle: f32) @This() {
        return .{ .x = v.x * math.cos(angle) - v.y * math.sin(angle), .y = v.x * math.sin(angle) + v.y * math.cos(angle) };
    }

    pub fn scaled(v: @This(), s: f32) @This() {
        return .{ .x = v.x * s, .y = v.y * s };
    }

    pub fn lerp(from: @This(), to: @This(), t: f32) @This() {
        return .{ .x = math.lerp(from.x, to.x, t), .y = math.lerp(from.y, to.y, t) };
    }

    pub fn squareLength(v: @This()) f32 {
        return v.x * v.x + v.y * v.y;
    }

    pub fn length(v: @This()) f32 {
        return @sqrt(v.squareLength());
    }

    pub fn normalized(v: @This()) @This() {
        const l = v.length();
        return if (l == 0) @This().zero() else return v.scaled(1 / l);
    }

    pub fn abs(v: @This()) @This() {
        return .{ .x = math.abs(v.x), .y = math.abs(v.y) };
    }

    pub fn getItem(v: *const @This(), i: u1) f32 {
        return switch (i) {
            0 => v.x,
            1 => v.y,
        };
    }

    pub fn setItem(v: *@This(), i: u1, val: f32) void {
        switch (i) {
            0 => v.x = val,
            1 => v.y = val,
        }
    }

    pub fn round(v: @This()) @This() {
        return .{
            .x = @round(v.x),
            .y = @round(v.y),
        };
    }
};
