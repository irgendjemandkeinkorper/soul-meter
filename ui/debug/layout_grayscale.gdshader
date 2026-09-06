shader_type canvas_item;

varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float luminance = dot(texel.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(vec3(luminance), texel.a) * vertex_tint;
}
