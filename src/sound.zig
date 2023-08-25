const w4 = @import("wasm4.zig");

pub fn playFireballThrow() void {
    w4.tone(
        450 | (210 << 16),
        0 | (12 << 8) | (12 << 16) | (6 << 24),
        10 | (10 << 8),
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

pub fn playFireballHitOther() void {
    w4.tone(
        600 | (300 << 16),
        2 | (4 << 8) | (0 << 16) | (0 << 24),
        25 | (25 << 8),
        w4.TONE_PULSE1,
    );
}

pub fn playScoreUp() void {
    w4.tone(
        440 | (880 << 16),
        4 | (8 << 8) | (0 << 16) | (0 << 24),
        30 | (20 << 8),
        w4.TONE_PULSE1,
    );
}
