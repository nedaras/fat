const std = @import("std");
const sokol = @import("sokol");
const shader = @import("shader.glsl.zig");
const app = sokol.app;
const gfx = sokol.gfx;
const glue = sokol.glue;
const assert = std.debug.assert;

const c = @cImport({
    @cInclude("freetype/ftadvanc.h");
    @cInclude("hb.h");
    @cInclude("hb-ft.h");
});

var bind = gfx.Bindings{};
var pipe = gfx.Pipeline{};

var pass_action: gfx.PassAction = .{};

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
        .width = 256,
        .height = 256,
        .pixel_format = .R8,
        .data = comptime blk: {
            var data = gfx.ImageData{};
            data.subimage[0][0] = gfx.asRange(&@as([256 * 256]u8, @splat(0)));
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
        0.0, 100.0,  0.5, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0,
        100.0,  100.0,  0.5, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0,
        0.0, 0.0, 0.5, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0,

        100.0,  100.0,  0.5, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0,
        100.0,  0.0, 0.5, 1.0, 1.0, 0.0, 1.0, 1.0, 1.0,
        0.0, 0.0, 0.5, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0,
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

var face: c.FT_Face = undefined;
var hb_font: *c.hb_font_t = undefined;

pub fn main() !void {
    var lib: c.FT_Library = undefined;

    assert(c.FT_Init_FreeType(&lib) == 0);
    defer assert(c.FT_Done_FreeType(lib) == 0);

    assert(c.FT_New_Face(lib, "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf", 0, &face) == 0);
    defer assert(c.FT_Done_Face(face) == 0);

    assert(c.FT_Set_Char_Size(face, 0, 64, 0, 0) == 0);

    hb_font = c.hb_ft_font_create(face, null).?;
    defer c.hb_font_destroy(hb_font);

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
