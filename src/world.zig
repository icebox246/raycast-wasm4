const w4 = @import("wasm4.zig");
const math = @import("math.zig");
const Player = @import("player.zig").Player;
const Level = @import("level.zig").Level;
const Location = @import("level.zig").Location;
const Billboard = @import("billboard.zig").Billboard;
const Projectile = @import("projectile.zig").Projectile;
const Vec2 = @import("vec.zig").Vec2;
const heapsort = @import("heapsort.zig").heapsort;
const assets = @import("assets.zig");

pub const World = struct {
    const max_player_count = 4;
    const max_billboard_count = 64;
    const max_projectiles_count = 64;

    pub const view_offset_x = 0;
    pub const view_offset_y = 0;

    pub const view_width: u32 = 160;
    pub const view_height: u32 = 120;

    pub const BufferedBillboard = struct {
        billboard: *const Billboard,
        depth: f32,

        fn compareDepth(a: *const @This(), b: *const @This()) bool {
            return a.depth > b.depth;
        }
    };

    level: Level,

    players: [max_player_count]Player,

    billboards_to_draw: [max_billboard_count]BufferedBillboard,
    billboards_count: u8,

    projectiles: [max_projectiles_count]Projectile,
    projectiles_count: u8,

    depth_buffer: [view_width]f32,

    tick: u32,

    waiting: bool,

    pub fn init() @This() {
        var world: @This() = undefined;

        world.level =
            comptime Level.fromASCII(
            \\ffffffffffffffffffffffffffffffffffffffff
            \\f..................P...................f
            \\f.######........P....P........#...P....f
            \\f.#....#......................R........f
            \\f.#....R......................R...P....f
            \\f.#.......P.......###..................f
            \\f.###R.........P.##.##.P.......R##.....f
            \\f............P..##...##..P.............f
            \\f......................................f
            \\f............P..R#...##..P.............f
            \\f..............P.##.##.P.....R##RR.....f
            \\f......P.P........###............R.....f
            \\f....P......................R..........f
            \\f..........P................R###RR.....f
            \\f....P.................................f
            \\f......P.P...............#####.........f
            \\f........................#.............f
            \\f......................................f
            \\ffffffffffffffffffffffffffffffffffffffff
        , &[_]Location{
            .{
                .pos = .{ .x = 19.5, .y = 8.5 },
                .heading = math.pi / 2,
            },
            .{
                .pos = .{ .x = 4.5, .y = 4.5 },
                .heading = -math.pi / 4,
            },
            .{
                .pos = .{ .x = 7.5, .y = 14.5 },
                .heading = -0.75 * math.pi,
            },
            .{
                .pos = .{ .x = 32, .y = 12.5 },
                .heading = 0.75 * math.pi,
            },
            .{
                .pos = .{ .x = 32.5, .y = 4.5 },
                .heading = -math.pi / 4,
            },
        });

        for (&world.players) |*player| {
            player.* = .{};
        }

        world.billboards_count = 0;

        world.waiting = true;

        return world;
    }

    pub fn update(self: *@This()) void {
        // const is_netplay = w4.NETPLAY.* & 0b100 != 0;

        const billie = Billboard{
            .pos = Vec2.zero(),
            .bottom_z = 0,
            .width = 0,
            .height = 0,
            .colors = 0,
            .sprite = &assets.wand,
        };

        self.postBillboard(&billie);

        const gamepads = [_]u8{
            w4.GAMEPAD1.*,
            w4.GAMEPAD2.*,
            w4.GAMEPAD3.*,
            w4.GAMEPAD4.*,
        };

        if (self.waiting) {
            self.drawWaitingScreen(&gamepads);
            return;
        }

        const local_player_index: u8 = w4.NETPLAY.* & 0b11;

        for (&self.players, gamepads, 0..) |*player, gamepad, i| {
            if (player.active) {
                player.local = i == local_player_index;
                player.update(gamepad, self);
            }
        }

        for (0..self.projectiles_count) |i| {
            var projectile = &self.projectiles[i];
            projectile.update(self);
            if (projectile.life == 0) {
                projectile.* = self.projectiles[self.projectiles_count - 1];
                self.projectiles_count -= 1;
            }
        }

        self.players[local_player_index].drawPerspective(self);

        for (0..self.billboards_count) |i| {
            self.players[local_player_index].updateBillboardDepth(&self.billboards_to_draw[i]);
        }

        heapsort(BufferedBillboard, BufferedBillboard.compareDepth, self.billboards_to_draw[0..self.billboards_count]);

        for (0..self.billboards_count) |i| {
            self.players[local_player_index].drawBillboard(self, &self.billboards_to_draw[i]);
        }
        self.billboards_count = 0;

        self.players[local_player_index].drawHUD(self);

        self.tick += 1;
    }

    pub fn postBillboard(self: *@This(), bb: *const Billboard) void {
        if (self.billboards_count == self.billboards_to_draw.len) return;

        self.billboards_to_draw[self.billboards_count] = .{
            .billboard = bb,
            .depth = 0,
        };

        self.billboards_count += 1;
    }

    pub fn postProjectile(self: *@This(), proj: Projectile) void {
        if (self.projectiles_count == self.projectiles.len) return;

        self.projectiles[self.projectiles_count] = proj;

        self.projectiles_count += 1;
    }

    pub fn pickUnoccupiedSpawnLocation(self: *const @This()) Location {
        var loc_buff: [16]*const Location = undefined;
        var locs = loc_buff[0..self.level.locations.len];
        for (0..locs.len) |i| {
            locs[i] = &self.level.locations[i];
        }

        while (locs.len > 0) {
            const idx = math.random() % locs.len;
            const loc = locs[idx];
            if (self.isLocationUnoccupied(loc)) {
                return loc.*;
            }
            locs[idx] = locs[locs.len - 1];
            locs.len -= 1;
        }

        unreachable;
    }

    fn isLocationUnoccupied(self: *const @This(), loc: *const Location) bool {
        for (&self.players) |*player| {
            if (player.active and player.pos.sub(loc.pos).squareLength() < 3 * 3) return false;
        }
        return true;
    }

    fn drawWaitingScreen(self: *@This(), gamepads: []const u8) void {
        const padding = 20;
        w4.DRAW_COLORS.* = 0x43;
        w4.rect(padding, padding, 160 - padding * 2, 160 - padding * 2);

        for (&self.players, gamepads, 0..) |*player, gamepad, i| {
            if (gamepad & (w4.BUTTON_1 | w4.BUTTON_2) != 0) {
                player.active = true;
            }

            var buf: [12]u8 = undefined;
            if (player.active) {
                @memcpy(&buf, "P%: ready   ");
                w4.DRAW_COLORS.* = 0x34;
            } else {
                @memcpy(&buf, "P%: inactive");
                w4.DRAW_COLORS.* = 0x31;
            }

            buf[1] = '1' + @as(u8, @intCast(i));

            w4.text(&buf, padding + 4, @intCast(padding + 4 + 12 * i));
        }

        if (gamepads[0] & w4.BUTTON_2 != 0) {
            self.waiting = false;
            return;
        }

        w4.DRAW_COLORS.* = 0x31;
        w4.text("   \x80: ready" ++ "\n" ++
            "P1 \x81: start", padding + 2, 160 - padding - 8 * 2 - 1);
    }
};
