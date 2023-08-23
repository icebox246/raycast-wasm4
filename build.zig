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
        "assets/projectile.png",
        "-o",
        "src/assets.zig",
    });

    asset_gen_step.dependOn(&w4_png2src_cmd.step);

    var bundle_step = b.step("bundle", "Bundle the game to publishable format");

    var w4_bundle_cmd = b.addSystemCommand(&[_][]const u8{
        "w4",
        "bundle",
        "zig-out/lib/cart.wasm",
        "--title",
        "Raycast WASM-4",
        "--html",
        "zig-out/bundled/index.html",
    });

    w4_bundle_cmd.step.dependOn(&lib.step);
    bundle_step.dependOn(&w4_bundle_cmd.step);

    var fmt_step = b.step("fmt", "Format the codebase");
    var fmt = b.addFmt(.{ .paths = &.{"src/"} });
    fmt_step.dependOn(&fmt.step);

    var fmt_check_step = b.step("fmt_check", "Check code formatting");
    var fmt_check = b.addFmt(.{ .paths = &.{"src/"}, .check = true });
    fmt_check_step.dependOn(&fmt_check.step);
}
