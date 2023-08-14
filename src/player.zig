const w4 = @import("wasm4.zig");
const math = @import("math.zig");
const Vec2 = @import("vec.zig").Vec2;
const level = @import("level.zig");
const Level = level.Level;
const World = @import("world.zig").World;
const Billboard = @import("billboard.zig").Billboard;
const std = @import("std");
const assets = @import("assets.zig");

pub const Player = struct {
    pos: Vec2,
    vel: Vec2 = Vec2.zero(),
    heading: f32 = 0,
    walking: bool = false,

    const linear_acceleration = 0.8;
    const half_collision_size: f32 = 0.15;
    const linear_damping = 0.85;
    const fov = math.pi / 3 * 2;

    fn forwardDir(self: *const @This()) Vec2 {
        return (Vec2{ .x = 0, .y = 1 }).rotate(self.heading);
    }

    pub fn update(self: *@This(), lvl: *const Level) void {
        const gamepad = w4.GAMEPAD1.*;

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
                if (lvl.tileAt(@intFromFloat(p.x), @intFromFloat(p.y))) |t| {
                    if (t.isSolid()) break true;
                }
            } else false;

            if (!will_collide) {
                self.pos = new_pos;
            } else {}
        }

        self.vel = self.vel.scaled(linear_damping);
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

        const weapon_sprite = assets.wand.subSprite(0, 0, assets.wand.width / 2, assets.wand.height);
        var weapon_x: i32 = @intCast((World.view_width - weapon_sprite.width) / 2);
        var weapon_y: i32 = @intCast(World.view_height - weapon_sprite.height + 3);

        const speed = self.vel.squareLength();
        const t = @as(f32, @floatFromInt(world.tick)) / 10;
        weapon_x += @intFromFloat(0.3 * math.cos(t) * speed);
        weapon_y -= @intFromFloat(0.1 * math.cos(2 * t) * speed);

        w4.DRAW_COLORS.* = 0x0321;
        weapon_sprite.draw(weapon_x, weapon_y);
    }

    pub fn drawBillboard(self: *const @This(), world: *World, billboard: *const Billboard) void {
        const offset = billboard.pos.sub(self.pos);
        const pos = offset.rotate(-self.heading);

        const depth = pos.y;

        if (depth < 0) return; // object is behind camera

        const forward = Vec2{ .x = 0, .y = 1 };
        const left_edge = forward.rotate(-fov / 2);
        const right_edge = forward.rotate(fov / 2);
        const left_x = left_edge.x / left_edge.y;
        const right_x = right_edge.x / right_edge.y;

        const x = pos.x / pos.y;

        const screen_x = math.lerp(0, @floatFromInt(World.view_width - 1), ((x - left_x) / (right_x - left_x)));
        const bottom_screen_y = @as(f32, @floatFromInt(World.view_height)) / 2 + (@as(f32, @floatFromInt(World.view_height)) * (0.5 - billboard.bottom_z)) / depth;
        const screen_w = @as(f32, @floatFromInt(billboard.width)) / depth;
        const screen_h = @as(f32, @floatFromInt(billboard.height)) / depth;

        w4.DRAW_COLORS.* = 0x2;
        const left_pixel_x = @as(i32, @intFromFloat(screen_x - screen_w / 2));
        const right_pixel_x = @as(i32, @intFromFloat(screen_x + screen_w / 2));
        var px = left_pixel_x;
        if (px < 0) px = 0;
        while (px <= right_pixel_x and px < World.view_width) : (px += 1) {
            if (depth > world.depth_buffer[@intCast(px)]) continue;
            w4.vline(World.view_offset_x + px, World.view_offset_y + @as(i32, @intFromFloat(bottom_screen_y - screen_h)), @intFromFloat(screen_h));
            world.depth_buffer[@intCast(px)] = depth;
        }
    }
};