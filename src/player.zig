const w4 = @import("wasm4.zig");
const math = @import("math.zig");
const Vec2 = @import("vec.zig").Vec2;
const level = @import("level.zig");
const Level = level.Level;
const World = @import("world.zig").World;
const Billboard = @import("billboard.zig").Billboard;
const Projectile = @import("projectile.zig").Projectile;
const std = @import("std");
const assets = @import("assets.zig");
const sound = @import("sound.zig");

pub const Player = struct {
    pos: Vec2 = Vec2.zero(),
    vel: Vec2 = Vec2.zero(),
    heading: f32 = 0,
    active: bool = false,
    walking: bool = false,
    billboard: Billboard = .{
        .width = 32,
        .height = 80,
        .bottom_z = 0,
        .pos = undefined,
        .colors = 0x0321,
        .sprite = &assets.wand.subSprite(0, 0, assets.wand.width / 2, assets.wand.height),
    },
    fire_cooldown: u8 = 0,
    health: u8 = 0,
    displayed_health_percentage: f32 = 1,
    local: bool = false,
    respawn_cooldown: u8 = total_respawn_cooldown,

    const linear_acceleration = 0.8;
    pub const half_collision_size: f32 = 0.15;
    const linear_damping = 0.85;
    const total_wand_cooldown = 30;
    const fov = math.pi / 3 * 2;
    const max_health = 3;
    const total_respawn_cooldown = 180;

    fn forwardDir(self: *const @This()) Vec2 {
        return (Vec2{ .x = 0, .y = 1 }).rotate(self.heading);
    }

    pub fn update(self: *@This(), gamepad: u8, world: *World) void {
        if (gamepad & w4.BUTTON_UP != 0) {
            math.shuffleRandom();
        }
        if (gamepad & w4.BUTTON_DOWN != 0) {
            math.shuffleRandom();
        }
        if (gamepad & w4.BUTTON_LEFT != 0) {
            math.shuffleRandom();
        }
        if (gamepad & w4.BUTTON_RIGHT != 0) {
            math.shuffleRandom();
        }

        world.postBillboard(&self.billboard);

        if (self.health == 0) {
            self.billboard.pos = Vec2.zero();
            if (self.respawn_cooldown > 0) {
                self.respawn_cooldown -= 1;
            } else {
                self.health = max_health;
                const loc = world.pickUnoccupiedSpawnLocation();
                self.pos = loc.pos;
                self.heading = loc.heading;
            }
            return;
        }

        var acceleration = Vec2.zero();

        self.walking = false;

        if (gamepad & w4.BUTTON_UP != 0) {
            acceleration.y += 1;
        }
        if (gamepad & w4.BUTTON_DOWN != 0) {
            acceleration.y -= 1;
        }
        if (gamepad & w4.BUTTON_2 == 0) {
            if (gamepad & w4.BUTTON_LEFT != 0) {
                self.heading -= 0.1;
            }
            if (gamepad & w4.BUTTON_RIGHT != 0) {
                self.heading += 0.1;
            }
            self.heading = math.mod(self.heading, 2 * math.pi);
        } else {
            if (gamepad & w4.BUTTON_LEFT != 0) {
                acceleration.x += 1;
            }
            if (gamepad & w4.BUTTON_RIGHT != 0) {
                acceleration.x -= 1;
            }
        }

        if (acceleration.x != 0 or acceleration.y != 0) self.walking = true;

        acceleration = acceleration.rotate(self.heading).scaled(linear_acceleration);

        self.vel = self.vel.add(acceleration);

        for ([_]u1{ 0, 1 }) |axis| {
            var v = Vec2.zero();
            v.setItem(axis, self.vel.getItem(axis));
            const new_pos = self.pos.add(v.scaled(1.0 / 60.0));
            const will_collide = inline for (0..4) |i| {
                const offset = Vec2{
                    .x = half_collision_size * if (i & 1 == 0) -1 else 1,
                    .y = half_collision_size * if (i & 2 == 0) -1 else 1,
                };
                const p = new_pos.add(offset);
                if (world.level.tileAt(@intFromFloat(p.x), @intFromFloat(p.y))) |t| {
                    if (t.isSolid()) break true;
                }
            } else false;

            if (!will_collide) {
                self.pos = new_pos;
            } else {}
        }

        if (self.fire_cooldown == 0 and self.health > 0) {
            if (gamepad & w4.BUTTON_1 != 0) {
                if (self.local) {
                    sound.playFireballThrow();
                }
                const forward = self.forwardDir();
                const proj = Projectile{
                    .pos = self.pos.add(forward.scaled(0.5)),
                    .vel = forward.scaled(10),
                    .owner = self,
                };
                world.postProjectile(proj);

                self.fire_cooldown = total_wand_cooldown;
            }
        } else {
            self.fire_cooldown -= 1;
        }

        self.vel = self.vel.scaled(linear_damping);

        self.billboard.pos = self.pos;
    }

    pub fn drawMapPin(self: @This(), ox: i32, oy: i32, ts: u32) void {
        w4.DRAW_COLORS.* = 0x24;
        const p = self.pos.scaled(@floatFromInt(ts)).add(.{ .x = @floatFromInt(ox), .y = @floatFromInt(oy) });

        w4.oval(@intFromFloat(p.x - 1), @intFromFloat(p.y - 1), 3, 3);

        const a = p;
        const b = a.add(self.forwardDir().scaled(4));

        w4.line(@intFromFloat(a.x), @intFromFloat(a.y), @intFromFloat(b.x), @intFromFloat(b.y));
    }

    pub fn drawPerspective(self: *const @This(), world: *World) void {
        const forward = self.forwardDir();
        const left_edge = forward.rotate(-fov / 2);
        const right_edge = forward.rotate(fov / 2);
        const t_step: f32 = 1 / @as(f32, @floatFromInt(World.view_width - 1));

        w4.DRAW_COLORS.* = 0x2;
        w4.rect(World.view_offset_x, World.view_offset_y + @as(i32, @intCast(World.view_height / 2)), World.view_width, World.view_height / 2);

        for (0..World.view_width) |column| {
            const ray_dir = Vec2.lerp(left_edge, right_edge, t_step * @as(f32, @floatFromInt(column + 1))).normalized();
            const maybe_hit = world.level.castRay(self.pos, ray_dir);
            if (maybe_hit) |hit| {
                const depth = hit.point.sub(self.pos).dot(forward);
                var h: u32 = @intFromFloat(@as(f32, @floatFromInt(World.view_height)) / depth);
                var uv_top: f32 = 0;
                var uv_bottom: f32 = 1;
                if (h > World.view_height) {
                    const delta = 1 - @as(f32, @floatFromInt(World.view_height)) / @as(f32, @floatFromInt(h));
                    uv_top += delta / 2;
                    uv_bottom -= delta / 2;
                    h = World.view_height;
                }

                w4.DRAW_COLORS.* = 0x4320;
                const maybe_sprite = hit.tile.spriteForTile();
                if (maybe_sprite) |sprite| {
                    sprite.drawScaledVline(World.view_offset_x + @as(i32, @intCast(column)), World.view_offset_y + @as(i32, @intCast((World.view_height - h) / 2)), h, hit.uv, uv_top, uv_bottom);
                    world.depth_buffer[column] = depth;
                }
            }
        }
    }

    pub fn drawHUD(self: *@This(), world: *World) void {
        const weapon_sprite = if (self.fire_cooldown >= 3 * total_wand_cooldown / 4)
            assets.wand.subSprite(assets.wand.width / 2, 0, assets.wand.width / 2, assets.wand.height)
        else
            assets.wand.subSprite(0, 0, assets.wand.width / 2, assets.wand.height);

        var weapon_x: i32 = @intCast((World.view_width - weapon_sprite.width) / 2);
        var weapon_y: i32 = @intCast(World.view_height - weapon_sprite.height + 3);

        const speed = self.vel.squareLength();
        const t = @as(f32, @floatFromInt(world.tick)) / 10;
        weapon_x += @intFromFloat(0.3 * math.cos(t) * speed);
        weapon_y -= @intFromFloat(0.1 * math.cos(2 * t) * speed);
        weapon_y += 10 * @as(u16, (@intCast(self.fire_cooldown))) * @as(u16, (@intCast(self.fire_cooldown))) / total_wand_cooldown / total_wand_cooldown;

        if (self.health > 0) {
            w4.DRAW_COLORS.* = 0x0321;
            weapon_sprite.draw(weapon_x, weapon_y);
        }

        w4.DRAW_COLORS.* = 0x31;
        w4.rect(0, World.view_height, 160, 160 - World.view_height);

        world.level.drawMap(1, World.view_height + 1, 2);
        self.drawMapPin(1, World.view_height + 1, 2);

        if (self.health > 0) {
            self.displayed_health_percentage = math.lerp(self.displayed_health_percentage, @as(f32, @floatFromInt(self.health)) / @as(f32, @floatFromInt(max_health)), 0.15);
            w4.DRAW_COLORS.* = 0x31;
            w4.rect(84, World.view_height + 3, 72, 6);
            w4.DRAW_COLORS.* = 0x2;
            w4.rect(85, World.view_height + 4, @intFromFloat(70 * self.displayed_health_percentage), 4);
        } else {
            var buf: [15]u8 = undefined;
            @memcpy(&buf, "Respawn\n   in %");
            buf[14] = '0' + (self.respawn_cooldown + 59) / 60;
            w4.DRAW_COLORS.* = 0x13;
            w4.text(&buf, 84, World.view_height + 3);
        }
    }

    pub fn updateBillboardDepth(self: *const @This(), bb: *World.BufferedBillboard) void {
        const offset = bb.billboard.pos.sub(self.pos);
        const pos = offset.rotate(-self.heading);

        bb.depth = pos.y;
    }

    pub fn drawBillboard(self: *const @This(), world: *World, bb: *const World.BufferedBillboard) void {
        if (bb.depth < 0.05) return; // object is behind camera

        const offset = bb.billboard.pos.sub(self.pos);
        const pos = offset.rotate(-self.heading);

        const forward = Vec2{ .x = 0, .y = 1 };
        const left_edge = forward.rotate(-fov / 2);
        const right_edge = forward.rotate(fov / 2);
        const left_x = left_edge.x / left_edge.y;
        const right_x = right_edge.x / right_edge.y;

        const x = pos.x / pos.y;

        const screen_x = math.lerp(0, @floatFromInt(World.view_width - 1), ((x - left_x) / (right_x - left_x)));
        const bottom_screen_y = @as(f32, @floatFromInt(World.view_height)) / 2 + (@as(f32, @floatFromInt(World.view_height)) * (0.5 - bb.billboard.bottom_z)) / bb.depth;
        const screen_w = @as(f32, @floatFromInt(bb.billboard.width)) / bb.depth;
        const screen_h = @as(f32, @floatFromInt(bb.billboard.height)) / bb.depth;

        w4.DRAW_COLORS.* = bb.billboard.colors;
        const left_pixel_x = @as(i32, @intFromFloat(screen_x - screen_w / 2));
        const right_pixel_x = @as(i32, @intFromFloat(screen_x + screen_w / 2));
        var px = left_pixel_x;
        if (px < 0) px = 0;
        while (px <= right_pixel_x and px < World.view_width) : (px += 1) {
            const uv_x = @as(f32, @floatFromInt(px - left_pixel_x)) / @as(f32, @floatFromInt((right_pixel_x - left_pixel_x + 1)));
            if (bb.depth > world.depth_buffer[@intCast(px)]) continue;
            bb.billboard.sprite.drawScaledVline(World.view_offset_x + px, World.view_offset_y + @as(i32, @intFromFloat(bottom_screen_y - screen_h)), @intFromFloat(screen_h), uv_x, 0, 1);
        }
    }

    pub fn damage(self: *@This()) enum { alive, died, dead } {
        if (self.health == 0) return .dead;

        self.health -= 1;
        if (self.local) {
            sound.playFireballHit();
        }

        if (self.health == 0) {
            self.respawn_cooldown = total_respawn_cooldown;
            return .died;
        }
        return .alive;
    }
};
