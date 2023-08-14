const w4 = @import("wasm4.zig");
const math = @import("math.zig");

pub const Sprite = struct {
    width: u32,
    height: u32,
    stride: u32,
    flags: u32,
    data: []const u8,

    pub fn draw(sprite: *const Sprite, x: i32, y: i32) void {
        w4.blitSub(@ptrCast(sprite.data), x, y, sprite.width, sprite.height, 0, 0, sprite.stride, sprite.flags);
    }

    pub fn subSprite(sprite: *const Sprite, ox: u32, oy: u32, w: u32, h: u32) Sprite {
        return Sprite{
            .width = w,
            .height = h,
            .stride = sprite.stride,
            .flags = sprite.flags,
            .data = sprite.data[(ox + oy * sprite.stride) / 4 ..],
        };
    }

    pub fn drawSampledPixel(sprite: *const Sprite, x: i32, y: i32, uv_x: f32, uv_y: f32) void {
        w4.blitSub(@ptrCast(sprite.data), x, y, 1, 1, @intFromFloat(@as(f32, @floatFromInt(sprite.width)) * uv_x), @intFromFloat(@as(f32, @floatFromInt(sprite.height)) * uv_y), sprite.stride, sprite.flags);
    }
    pub fn drawScaledVline(sprite: *const Sprite, x: i32, y: i32, len: u32, uv_x: f32, uv_y_top: f32, uv_y_bottom: f32) void {
        for (0..len) |oy| {
            sprite.drawSampledPixel(x, @intCast(y + @as(i32, @intCast(oy))), uv_x, math.lerp(uv_y_top, uv_y_bottom, @as(f32, @floatFromInt(@as(i32, @intCast(oy)))) / @as(f32, @floatFromInt(len))));
        }
    }
};
