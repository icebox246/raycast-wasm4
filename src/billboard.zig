const Vec2 = @import("vec.zig").Vec2;
const Sprite = @import("sprite.zig").Sprite;

pub const Billboard = struct {
    pos: Vec2,
    bottom_z: f32,
    width: u16,
    height: u16,
    colors: u16 = 0x4321,
    sprite: *const Sprite,
};
