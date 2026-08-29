shader_type canvas_item;
render_mode unshaded;

uniform vec4 reflection_tint : source_color = vec4(0.941, 0.816, 0.537, 0.22);
uniform float reflection_height = 58.0;
uniform float motion_scale : hint_range(0.0, 1.0) = 1.0;

varying float reflection_depth;


void vertex() {
	reflection_depth = clamp(VERTEX.y / reflection_height, 0.0, 1.0);
	float time = TIME * 0.42 * motion_scale;
	float distance_from_surface = 1.0 - reflection_depth;
	float ripple = sin(VERTEX.y * 0.19 + time) + sin(VERTEX.y * 0.43 - time * 0.71) * 0.34;
	VERTEX.x += ripple * (0.28 + distance_from_surface * 1.2) * motion_scale;
}


void fragment() {
	vec4 glyph = texture(TEXTURE, UV) * COLOR;
	float fade = pow(clamp(reflection_depth, 0.0, 1.0), 1.65);
	float ripple_shadow = 0.86 + sin(reflection_depth * 38.0 + TIME * 0.35 * motion_scale) * 0.08;
	glyph.rgb = mix(glyph.rgb, reflection_tint.rgb, 0.72);
	glyph.a *= reflection_tint.a * fade * ripple_shadow;
	COLOR = glyph;
}
