const std = @import("std");
const sokol = @import("sokol");
const shader = @import("shader.glsl.zig");
const c = @import("c.zig");
const Atlas = @import("Atlas.zig");
const app = sokol.app;
const gfx = sokol.gfx;
const glue = sokol.glue;
const assert = std.debug.assert;

var bind = gfx.Bindings{};
var pipe = gfx.Pipeline{};

var pass_action: gfx.PassAction = .{};

var face: c.FT_Face = undefined;
var hb_font: *c.hb_font_t = undefined;

var atlas: Atlas = undefined;

export fn init() void {
    gfx.setup(.{
        .environment = glue.environment(),
        .logger = .{ .func = sokol.log.func },
    });

    pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.0, .g = 0.5, .b = 1.0, .a = 1.0 },
    };

    bind.vertex_buffers[0] = gfx.makeBuffer(.{
        .size = 420 * 36,
        .usage = .{ .dynamic_update = true },
    });

    pipe = gfx.makePipeline(.{
        .shader = gfx.makeShader(shader.fatShaderDesc(gfx.queryBackend())),
        .layout = blk: {
            var layout = gfx.VertexLayoutState{};
            layout.attrs[shader.ATTR_fat_position].format = .FLOAT3;
            layout.attrs[shader.ATTR_fat_color0].format = .FLOAT4;
            layout.attrs[shader.ATTR_fat_texcoord0].format = .FLOAT2;
            break :blk layout;
        },
    });

    bind.images[shader.IMG_tex] = gfx.makeImage(.{
        .width = @intCast(atlas.size),
        .height = @intCast(atlas.size),
        .pixel_format = .R8,
        .data = blk: {
            var data = gfx.ImageData{};
            data.subimage[0][0] = gfx.asRange(atlas.data);
            break :blk data;
        },
    });

    bind.samplers[shader.SMP_smp] = gfx.makeSampler(.{});
}

export fn cleanup() void {
    gfx.shutdown();
}

export fn frame() void {
    defer gfx.commit();

    gfx.beginPass(.{ .swapchain = glue.swapchain(), .action = pass_action });
    defer gfx.endPass();

    const L = 0.0;
    const R = app.widthf();
    const T = 0.0;
    const B = app.heightf();

    gfx.updateBuffer(bind.vertex_buffers[0], gfx.asRange(&[_]f32{
        0.0, 256.0,  0.5, 1.0, 0.0, 0.0, 1.0, 0.0, 1.0,
        256.0,  256.0,  0.5, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0,
        0.0, 0.0, 0.5, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0,

        256.0,  256.0,  0.5, 0.0, 1.0, 0.0, 1.0, 1.0, 1.0,
        256.0,  0.0, 0.5, 1.0, 1.0, 0.0, 1.0, 1.0, 0.0,
        0.0, 0.0, 0.5, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0,
    }));

    gfx.applyPipeline(pipe);
    gfx.applyBindings(bind);
    gfx.applyUniforms(shader.UB_vs_params, gfx.asRange(&shader.VsParams{
        .mvp = .{
            2.0 / (R - L),     0.0,               0.0,  0.0,
            0.0,               2.0 / (T - B),     0.0,  0.0,
            0.0,               0.0,               -1.0, 0.0,
            (R + L) / (L - R), (T + B) / (B - T), 0.0,  1.0,
        },
    }));

    gfx.draw(0, 6, 1);
}

export fn event(e: ?*const app.Event) void {
    _ = e;
}

pub fn main() !void {
    var lib: c.FT_Library = undefined;

    assert(c.FT_Init_FreeType(&lib) == 0);
    defer assert(c.FT_Done_FreeType(lib) == 0);

    assert(c.FT_New_Face(lib, "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf", 0, &face) == 0);
    defer assert(c.FT_Done_Face(face) == 0);

    assert(c.FT_Set_Char_Size(face, 0, 16 * 64, 0, 0) == 0);

    //hb_font = c.hb_ft_font_create(face, null).?;
    //defer c.hb_font_destroy(hb_font);

    atlas = try Atlas.init(std.heap.page_allocator, 512);
    defer atlas.deinit();

    //var char_idx: c_uint = undefined;
    //var char = c.FT_Get_First_Char(face, &char_idx);

    //while (char_idx != 0) : (char = c.FT_Get_Next_Char(face, char, &char_idx)) {
        //const idx = c.FT_Get_Char_Index(face, char);
        //if (idx == 0) continue;

        //assert(c.FT_Load_Glyph(face, char_idx, c.FT_LOAD_RENDER) == 0);

        //const width = face.*.glyph.*.bitmap.width;
        //const height = face.*.glyph.*.bitmap.rows;

        //const region = try atlas.reserve(width + 2, height + 2);

        //for (0..height) |y| {
            //const src = face.*.glyph.*.bitmap.buffer[y * width .. y * width + width];
            //const dst = atlas.data[(region.y + y + 1) * atlas.size + region.x + 1 .. (region.y + y + 1) * atlas.size + region.x + 1 + width];

            //@memcpy(dst, src);
        //}
    //}

    //const buffer = c.hb_buffer_create();
    //defer c.hb_buffer_destroy(buffer);

    //c.hb_buffer_add_utf8(buffer, "Hello World", -1, 0, -1);
    //c.hb_buffer_guess_segment_properties(buffer);
    //c.hb_shape(hb_font, buffer, null, 0);

    //var count: c_uint = undefined;
    //const info = c.hb_buffer_get_glyph_infos(buffer, &count);
    //const pos = c.hb_buffer_get_glyph_positions(buffer, &count);

    //for (0..count) |i| {
    //std.debug.print("gid {d}, advance {d}\n", .{info[i].codepoint, pos[i].x_advance});
    //}


    //cconst out = try std.fs.cwd().createFile("out.ppm", .{});
    //defer out.close();

    //try atlas.dump(out.writer());

    //_ = try atlas.reserve(80, 64);
    //_ = try atlas.reserve(356, 100);
    //_ = try atlas.reserve(100, 32);
    //_ = try atlas.reserve(76, 100);
    //_ = try atlas.reserve(100, 32);

    //_ = try atlas.reserve(64, 64);
    //_ = try atlas.reserve(448, 128);
    //_ = try atlas.reserve(64, 64);

    //var curr = atlas.nodes.first;
    //while (curr) |node| {
        //defer curr = node.next;

        //std.debug.print("node: {} {} {}\n", .{node.data.x, node.data.y, node.data.width});
    //}

    //_ = try atlas.reserve(64, 64);
    //_ = try atlas.reserve(64, 64);
    app.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = event,
        .width = 640,
        .height = 480,
        .icon = .{ .sokol_default = true },
        .window_title = "fat",
        .logger = .{ .func = sokol.log.func },
        .win32_console_attach = true,
    });
}
