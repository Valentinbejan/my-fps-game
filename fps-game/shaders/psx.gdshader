shader_type spatial;
render_mode diffuse_lambert, vertex_lighting, shadows_disabled, specular_disabled;
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool textured = true;
uniform bool world_uv = true;
uniform float tile_size = 2.0;
uniform float snap_strength = 0.28;
varying vec3 world_pos;
varying vec3 world_n;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = vec2(427.0, 240.0);
	if (clip.w > 0.05) {
		vec2 snapped = floor(clip.xy / clip.w * grid + 0.5) / grid * clip.w;
		clip.xy = mix(clip.xy, snapped, snap_strength);
	}
	POSITION = clip;
}
void fragment() {
	vec2 coords = UV;
	if (world_uv) {
		vec3 n = abs(world_n);
		coords = n.y > max(n.x,n.z) ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
		coords /= tile_size;
	}
	ALBEDO = tint.rgb * (textured ? texture(albedo_tex, coords).rgb : vec3(1.0));
	ROUGHNESS = 1.0;
}

