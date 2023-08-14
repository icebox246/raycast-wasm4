const std = @import("std");
const w4 = @import("wasm4.zig");
const Vec2 = @import("vec.zig").Vec2;
const Sprite = @import("sprite.zig").Sprite;
const assets = @import("assets.zig");

pub const Tile = enum(u3) {
    empty,
    wall,
    pillar,
    fence,
    ruined,

    pub fn fromChar(c: u8) Tile {
        return switch (c) {
            '.' => .empty,
            '#' => .wall,
            'P' => .pillar,
            'f' => .fence,
            'R' => .ruined,
            else => @compileError("Unknown tile character"),
        };
    }

    pub fn isSolid(t: Tile) bool {
        return switch (t) {
            .empty => false,
            .pillar, .wall, .fence, .ruined => true,
        };
    }

    pub fn spriteForTile(t: Tile) ?Sprite {
        return switch (t) {
            .empty => null,
            .wall => comptime assets.tiles.subSprite(0, 0, 16, 32),
            .pillar => comptime assets.tiles.subSprite(16, 0, 16, 32),
            .fence => comptime assets.tiles.subSprite(32, 0, 16, 32),
            .ruined => comptime assets.tiles.subSprite(48, 0, 16, 32),
        };
    }
};

pub const RaycastHit = struct {
    point: Vec2,
    tile: Tile,
    orient: enum {
        x,
        y,
    },
    uv: f32,
};

pub const Level = struct {
    width: u16,
    tiles: []Tile,

    pub fn fromASCII(comptime str: []const u8) @This() {
        @setEvalBranchQuota(100000);
        var line_iter = std.mem.tokenizeScalar(u8, str, '\n');

        const lvl_width = (line_iter.peek() orelse @compileError("Level string must have at least one line")).len;
        const lvl_height = compute_height: {
            var h = 0;
            while (line_iter.next()) |line| {
                if (line.len != lvl_width) @compileError("Level string lines must be of uniform length");
                h += 1;
            }
            break :compute_height h;
        };

        line_iter.reset();

        var tiles: [lvl_width * lvl_height]Tile = undefined;

        var y = 0;
        while (line_iter.next()) |line| : (y += 1) {
            for (line, 0..) |c, x| {
                tiles[y * lvl_width + x] = Tile.fromChar(c);
            }
        }

        return .{
            .width = lvl_width,
            .tiles = &tiles,
        };
    }

    pub fn drawMap(self: *const @This(), ox: i32, oy: i32, ts: u32) void {
        w4.DRAW_COLORS.* = 0x3;
        var row_iter = std.mem.window(Tile, self.tiles, self.width, self.width);

        var y: i32 = 0;
        while (row_iter.next()) |row| : (y += 1) {
            for (row, 0..) |t, x| {
                if (t.isSolid())
                    w4.rect(ox + @as(i32, @intCast(x * ts)), oy + y * @as(i32, @intCast(ts)), ts, ts);
            }
        }
    }

    pub fn height(self: *const @This()) u16 {
        return @intCast(self.tiles.len / self.width);
    }

    pub fn tileAt(self: *const @This(), x: u32, y: u32) ?Tile {
        if (x > self.width) return null;
        if (y > self.height()) return null;

        return self.tiles[y * self.width + x];
    }

    pub fn castRay(lvl: *const Level, origin: Vec2, dir: Vec2) ?RaycastHit {
        const step = dir.scaled(0.01);

        var current = origin;

        while (lvl.tileAt(@intFromFloat(current.x), @intFromFloat(current.y))) |t| : (current = current.add(step)) {
            if (t.isSolid()) {
                var hit = RaycastHit{
                    .point = current,
                    .tile = t,
                    .orient = undefined,
                    .uv = undefined,
                };

                const tx = @floor(current.x);
                const ty = @floor(current.y);

                const dx = if (dir.x > 0) current.x - tx else tx - current.x + 1;
                const dy = if (dir.y > 0) current.y - ty else ty - current.y + 1;

                if (dx < dy) {
                    hit.orient = .x;
                    hit.uv = current.y - ty;
                } else {
                    hit.orient = .y;
                    hit.uv = current.x - tx;
                }

                return hit;
            }
        } else {
            return null;
        }
    }
};
