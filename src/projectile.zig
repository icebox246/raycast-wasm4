const World = @import("world.zig").World;
const Vec2 = @import("vec.zig").Vec2;
const Billboard = @import("billboard.zig").Billboard;
const Player = @import("player.zig").Player;
const assets = @import("assets.zig");

pub const Projectile = struct {
    pos: Vec2,
    vel: Vec2,
    billboard: Billboard = .{
        .width = 20,
        .height = 20,
        .bottom_z = 0.2,
        .pos = undefined,
        .colors = 0x4021,
        .sprite = &assets.projectile.subSprite(0, 0, assets.projectile.width / 2, assets.projectile.height),
    },
    life: u8 = 0x83,
    owner: *const Player,

    fn startDying(self: *@This()) void {
        self.life ^= 0x80;
        self.billboard.sprite = comptime &assets.projectile.subSprite(assets.projectile.width / 2, 0, assets.projectile.width / 2, assets.projectile.height);
        self.pos = self.pos.sub(self.vel.normalized().scaled(0.2));
    }

    pub fn update(self: *@This(), world: *World) void {
        updating: {
            if (self.life & 0x80 != 0) {
                self.pos = self.pos.add(self.vel.scaled(1.0 / 60.0));

                if (world.level.tileAt(@intFromFloat(self.pos.x), @intFromFloat(self.pos.y))) |t| {
                    if (t.isSolid()) {
                        self.startDying();
                        break :updating;
                    }

                    const sqrThreshold = (Player.half_collision_size + 0.1) * (Player.half_collision_size + 0.1);
                    for (&world.players) |*player| {
                        if (player == self.owner or !player.active) continue;

                        if (self.pos.sub(player.pos).squareLength() <= sqrThreshold) {
                            self.startDying();

                            if (player.damage() == .died) {
                                // reward owner
                            }

                            break :updating;
                        }
                    }
                } else {
                    self.startDying();
                    break :updating;
                }
            } else {
                self.life -= 1;
            }
        }

        self.billboard.pos = self.pos;
        world.postBillboard(&self.billboard);
    }
};
