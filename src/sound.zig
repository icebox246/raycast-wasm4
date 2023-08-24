const w4 = @import("wasm4.zig");

pub fn playFireballThrow() void {
    w4.tone(
        450 | (210 << 16),
        0 | (12 << 8) | (12 << 16) | (6 << 24),
        20 | (20 << 8),
        w4.TONE_NOISE,
    );
}

pub fn playFireballHit() void {
    w4.tone(
        170 | (230 << 16),
        0 | (4 << 8) | (2 << 16) | (0 << 24),
        20 | (25 << 8),
        w4.TONE_NOISE,
    );
}
