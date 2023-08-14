const math = @import("math.zig");
const Player = @import("player.zig").Player;
const Level = @import("level.zig").Level;
const Billboard = @import("billboard.zig").Billboard;

pub const World = struct {
    const max_player_count = 4;
    const max_billboard_count = 4;

    pub const view_offset_x = 0;
    pub const view_offset_y = 0;

    pub const view_width: u32 = 160;
    pub const view_height: u32 = 120;

    level: Level,

    players: [max_player_count]Player,
    player_count: u8,

    billboards: []Billboard,
    billboards_count: u8,

    depth_buffer: [view_width]f32,

    tick: u32,

    pub fn init() @This() {
        var world: @This() = undefined;

        world.players[0] = Player{
            .pos = .{
                .x = 19.5,
                .y = 8.5,
            },
            .heading = math.pi / 2,
        };
        world.player_count = 1;

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

        return world;
    }

    pub fn update(self: *@This()) void {
        for (0..self.player_count) |i| {
            self.players[i].update(&self.level);
        }

        self.players[0].drawPerspective(self);
        for (0..self.billboards_count) |i| {
            self.players[0].drawBillboard(self, &self.billboards[i]);
        }

        self.level.drawMap(0, view_height, 2);
        self.players[0].drawMapPin(0, view_height, 2);

        self.tick += 1;
    }
};
