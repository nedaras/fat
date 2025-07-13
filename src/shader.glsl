#pragma sokol @ctype mat4 [16]f32

@vs vs
layout(binding=0) uniform vs_params {
    mat4 mvp;
};

in vec4 position;
in vec4 color0;
in vec2 texcoord0;

out vec4 color;
out vec2 uv;

void main() {
  gl_Position = mvp * position;
  color = color0;
  uv = texcoord0;
}
@end

@fs fs
layout(binding=0) uniform texture2D tex;
layout(binding=0) uniform sampler smp;

in vec4 color;
in vec2 uv;

out vec4 frag_color;

void main() {
  float r = texture(sampler2D(tex, smp), uv).r;
  frag_color = color * vec4(r, r, r, 1.0);
}
@end

@program fat vs fs
