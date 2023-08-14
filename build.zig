const std = @import("std");

pub fn build(b: *std.Build) !void {
    const mode = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "cart",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .optimize = mode,
        .target = .{ .cpu_arch = .wasm32, .os_tag = .freestanding },
    });

    lib.import_memory = true;
    lib.initial_memory = 65536;
    lib.max_memory = 65536;
    lib.stack_size = 14752;

    // Export WASM-4 symbols
    lib.export_symbol_names = &[_][]const u8{ "start", "update" };

    b.installArtifact(lib);

    var asset_gen_step = b.step("gen", "Generate all needed assets");

    var w4_png2src_cmd = b.addSystemCommand(&[_][]const u8{
        "w4",
        "png2src",
        "--zig",
        "--template",
        "src/assets.zig.template",
        "assets/tiles.png",
        "assets/wand.png",
        "-o",
        "src/assets.zig",
    });

    asset_gen_step.dependOn(&w4_png2src_cmd.step);
}