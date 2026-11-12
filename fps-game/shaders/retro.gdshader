shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool crt_enabled = true;
uniform vec2 resolution = vec2(854.0,480.0);
void fragment() {
	vec2 pixel = floor(SCREEN_UV * resolution);
	vec2 uv = (pixel + 0.5) / resolution;
	vec3 col = texture(screen_texture, uv).rgb;
	float bayer = mod(pixel.x,2.0)*2.0 + mod(pixel.y,2.0)*3.0;
	col = floor(col*31.0 + bayer/5.0)/31.0;
	if (crt_enabled) {
		col *= 0.965 + 0.035 * sin(pixel.y*3.14159265);
		vec2 edge = SCREEN_UV*(1.0-SCREEN_UV);
		col *= clamp(pow(edge.x*edge.y*20.0,0.10),0.72,1.0);
	}
	COLOR = vec4(col,1.0);
}

