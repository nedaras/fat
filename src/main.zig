const std = @import("std");
const freetype = @import("freetype");
const sokol = @import("sokol");
const app = sokol.app;
const gfx = sokol.gfx;
const glue = sokol.glue;

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
}

export fn cleanup() void {
    gfx.shutdown();
}

export fn frame() void {
    defer gfx.commit();

    gfx.beginPass(.{ .swapchain = glue.swapchain(), .action = pass_action });
    defer gfx.endPass();

    //gfx.applyPipeline(pipe);
    //gfx.applyBindings(bind);
}

export fn event(e: ?*const app.Event) void {
    _ = e;
}

pub fn main() void {
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
