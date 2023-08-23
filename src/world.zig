const w4 = @import("wasm4.zig");
const math = @import("math.zig");
const Player = @import("player.zig").Player;
const Level = @import("level.zig").Level;
const Billboard = @import("billboard.zig").Billboard;
const Projectile = @import("projectile.zig").Projectile;
const heapsort = @import("heapsort.zig").heapsort;

pub const World = struct {
    const max_player_count = 2;
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

    pub fn init() @This() {
        var world: @This() = undefined;

        for (&world.players) |*player| {
            player.* = Player{
                .pos = .{
                    .x = 19.5,
                    .y = 8.5,
                },
                .heading = math.pi / 2,
            };
        }

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
        );

        world.billboards_count = 0;

        return world;
    }

    pub fn update(self: *@This()) void {
        // const is_netplay = w4.NETPLAY.* & 0b100 != 0;

        const gamepads = [_]u8{
            w4.GAMEPAD1.*,
            w4.GAMEPAD2.*,
            // w4.GAMEPAD2.*,
            // 0,
        };

        const local_player_index: u8 = w4.NETPLAY.* & 0b11;

        for (&self.players, gamepads) |*player, gamepad| {
            player.update(gamepad, self);
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
};
