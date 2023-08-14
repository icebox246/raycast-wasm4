const w4 = @import("wasm4.zig");
const World = @import("world.zig").World;

const screen_width = 160;
const screen_height = 160;

var world: World = undefined;

export fn start() void {
    w4.PALETTE[0] = 0xC3EAFD; // columbia blue
    w4.PALETTE[1] = 0xD4AFC7; // pink lavender
    w4.PALETTE[2] = 0x424651; // charcoal
    w4.PALETTE[3] = 0xaba35f; // ecru

    world = World.init();
}

export fn update() void {
    world.update();
}
