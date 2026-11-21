shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() {
 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
 vec2 wall = vec2(abs(world_normal.x) > 0.6 ? world_pos.z : world_pos.x, world_pos.y);
 vec2 cell = floor(wall / vec2(1.35, 3.0));
 vec2 uv = fract(wall / vec2(1.35, 3.0));
 float pane = step(0.14, uv.x) * step(uv.x, 0.86) * step(0.18, uv.y) * step(uv.y, 0.79);
 pane *= 1.0 - step(0.7, abs(world_normal.y));
 float random = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
 float occupied = step(0.61, random);
 vec3 warm = mix(vec3(0.68, 0.56, 0.38), vec3(0.56, 0.73, 0.78), step(0.91, random));
 ALBEDO = mix(vec3(0.025, 0.035, 0.045), vec3(0.10, 0.19, 0.24), pane);
 METALLIC = 0.6;
 ROUGHNESS = mix(0.42, 0.2, pane);
 // Mullions and narrow blinds add scale without extra geometry.
 float blind = 0.78 + 0.22 * step(0.18, fract(uv.y * 9.0));
 EMISSION = vec3(0.008, 0.015, 0.02) + warm * occupied * pane * blind * 0.42;
}
