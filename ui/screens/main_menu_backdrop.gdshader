shader_type canvas_item;
render_mode unshaded;

uniform vec4 void_color : source_color = vec4(0.027, 0.031, 0.043, 1.0);
uniform vec4 stone_color : source_color = vec4(0.106, 0.122, 0.153, 1.0);
uniform vec4 iron_color : source_color = vec4(0.227, 0.255, 0.302, 1.0);
uniform vec4 bronze_color : source_color = vec4(0.851, 0.671, 0.271, 1.0);
uniform vec4 mote_color : source_color = vec4(0.133, 0.827, 0.933, 1.0);
uniform float motion_scale : hint_range(0.0, 1.0) = 1.0;


float mirrored_noise(vec2 position) {
	vec2 cell = floor(position * vec2(960.0, 540.0));
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}


void fragment() {
	vec2 uv = UV;
	float mirror_x = abs(uv.x - 0.5) * 2.0;
	float time = TIME * 0.16 * motion_scale;

	float edge_falloff = smoothstep(0.18, 1.0, mirror_x);
	vec3 glass = mix(stone_color.rgb, void_color.rgb, edge_falloff * 0.82);
	glass *= 0.72 + 0.28 * (1.0 - smoothstep(0.14, 1.05, distance(uv, vec2(0.5, 0.44))));

	float ripple = sin(uv.y * 34.0 + mirror_x * 11.0 + time);
	ripple += sin(uv.y * 73.0 - mirror_x * 7.0 - time * 0.63) * 0.45;
	glass += iron_color.rgb * ripple * 0.014;

	float seam = 1.0 - smoothstep(0.0015, 0.012, abs(uv.x - 0.5));
	float inner_seam = 1.0 - smoothstep(0.0, 0.003, abs(uv.x - 0.5));
	glass += iron_color.rgb * seam * 0.13;
	glass += bronze_color.rgb * inner_seam * 0.08;

	vec2 arch_position = vec2(mirror_x, (uv.y - 0.43) * 1.32);
	float arch_distance = abs(length(arch_position) - 0.56);
	float arch = 1.0 - smoothstep(0.003, 0.014, arch_distance);
	glass += bronze_color.rgb * arch * 0.075;

	float side_bevel = 1.0 - smoothstep(0.004, 0.015, abs(mirror_x - 0.72));
	glass += iron_color.rgb * side_bevel * 0.09;

	float shimmer_path = abs(mirror_x - fract(uv.y * 0.31 + time * 0.035));
	float shimmer = 1.0 - smoothstep(0.0, 0.022, shimmer_path);
	glass += mix(bronze_color.rgb, mote_color.rgb, 0.22) * shimmer * 0.035 * motion_scale;

	float grain = mirrored_noise(vec2(mirror_x, uv.y)) - 0.5;
	glass += grain * 0.012;

	float vignette = 1.0 - smoothstep(0.35, 0.96, distance(uv, vec2(0.5, 0.5)));
	glass *= mix(0.58, 1.0, vignette);
	COLOR = vec4(glass, 1.0);
}
