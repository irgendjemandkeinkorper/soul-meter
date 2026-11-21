shader_type canvas_item;
// Calms a painted ground so the dressing reads on it (lived-in maps; owner 2026-11-02:
// "calm the ground first"). Same palette and light logic as the art bible asks: no hue
// shift and the darks stay deep. It compresses the bright wet streaks and quiets fine detail.

// Share of fine detail kept over a small low-pass (1 keeps the painting as it was).
uniform float detail : hint_range(0.0, 1.0) = 0.72;
// Low-pass radius in source texels.
uniform float blur_texels : hint_range(0.0, 8.0) = 2.0;
// Luminance above the knee is compressed by `highlight_strength`. The painting's median
// luminance is about 0.09 and its wet streaks run 0.26-0.58.
uniform float highlight_knee : hint_range(0.0, 1.0) = 0.2;
uniform float highlight_strength : hint_range(0.0, 1.0) = 0.55;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 r = TEXTURE_PIXEL_SIZE * blur_texels;
	vec3 low = base.rgb * 0.2;
	low += texture(TEXTURE, UV + vec2(r.x, 0.0)).rgb * 0.1;
	low += texture(TEXTURE, UV - vec2(r.x, 0.0)).rgb * 0.1;
	low += texture(TEXTURE, UV + vec2(0.0, r.y)).rgb * 0.1;
	low += texture(TEXTURE, UV - vec2(0.0, r.y)).rgb * 0.1;
	low += texture(TEXTURE, UV + r).rgb * 0.1;
	low += texture(TEXTURE, UV - r).rgb * 0.1;
	low += texture(TEXTURE, UV + vec2(r.x, -r.y)).rgb * 0.1;
	low += texture(TEXTURE, UV + vec2(-r.x, r.y)).rgb * 0.1;
	vec3 c = mix(low, base.rgb, detail);
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	if (l > highlight_knee) {
		float calmed = highlight_knee + (l - highlight_knee) * (1.0 - highlight_strength);
		c *= calmed / l;
	}
	COLOR = vec4(c, base.a) * tint;
}
