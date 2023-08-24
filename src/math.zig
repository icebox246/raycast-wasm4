pub const pi: f32 = @import("std").math.atan(@as(f32, 1)) * 4;

const sine_lookup_size = 256;

fn computeSineLookup() [sine_lookup_size]f32 {
    var out: [sine_lookup_size]f32 = undefined;

    for (0..out.len) |i| {
        out[i] = @sin(2 * pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(out.len - 1)));
    }

    return out;
}

pub fn sin(angle: f32) f32 {
    const lookup = comptime computeSineLookup();
    var a = mod(angle, 2 * pi);
    if (a < 0) a = 2 * pi + a;
    var arg: u16 = @intFromFloat(@round((a / (2 * pi)) * sine_lookup_size));
    if (arg >= lookup.len) arg = lookup.len - 1;
    return lookup[arg];
}

pub fn cos(angle: f32) f32 {
    return sin(angle + pi / 2);
}

pub fn lerp(from: f32, to: f32, t: f32) f32 {
    return from + (to - from) * t;
}

pub fn abs(x: f32) f32 {
    return if (x >= 0) x else -x;
}

pub fn mod(x: f32, m: f32) f32 {
    const reps = @floor(x / m);
    return x - reps * m;
}

var rand_int_state: u32 = 0xf00dbabe;

pub fn shuffleRandom() void {
    rand_int_state =
        (rand_int_state >> 1) | ((((rand_int_state >> 0) ^ (rand_int_state >> 2) ^
        (rand_int_state >> 3) ^ (rand_int_state >> 5)) &
        1) << 15);
}

pub fn random() u32 {
    shuffleRandom();
    return rand_int_state;
}
