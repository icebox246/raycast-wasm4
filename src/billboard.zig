const Vec2 = @import("vec.zig").Vec2;

pub const Billboard = struct {
    pos: Vec2,
    bottom_z: f32,
    width: u32,
    height: u32,
};
