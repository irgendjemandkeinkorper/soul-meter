shader_type canvas_item;
// Soft blend for a map's flat ground art (owner ruling 2026-11-03, item 35): see
// world/ground_blend.gd, which sets every uniform. All tuning is PROVISIONAL.

// A slab shows only its top face (corners in the file's pixels: left, front, right, back), and
// the face's edge fades out raggedly over `feather_px`.
uniform bool mask_face = false;
uniform vec2 face_left;
uniform vec2 face_front;
uniform vec2 face_right;
uniform vec2 face_back;
uniform float feather_px = 34.0;
uniform float ragged_px = 20.0;
uniform float ragged_scale = 0.011;

// The colour moves toward the painted backdrop's under it, more so where the edge fades.
uniform bool has_backdrop = false;
uniform sampler2D backdrop : filter_linear, repeat_disable;
uniform vec3 backdrop_row0;
uniform vec3 backdrop_row1;
uniform float reach_px = 56.0;
uniform vec3 face_mean = vec3(0.5);
uniform float tone = 0.4;

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(cell), hash(cell + vec2(1.0, 0.0)), u.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

// Distance from `p` to the edge a -> b, positive on the face's side (the corners run left,
// front, right, back: counter-clockwise on screen, where y points down).
float inside(vec2 p, vec2 a, vec2 b) {
	vec2 edge = b - a;
	return ((p.x - a.x) * edge.y - (p.y - a.y) * edge.x) / max(length(edge), 0.001);
}

vec2 backdrop_uv(vec2 world) {
	vec3 w = vec3(world, 1.0);
	return vec2(dot(backdrop_row0, w), dot(backdrop_row1, w));
}

void fragment() {
	vec4 colour = COLOR;
	float keep = 1.0;
	if (mask_face) {
		vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
		float depth = min(
			min(inside(pixel, face_left, face_front), inside(pixel, face_front, face_right)),
			min(inside(pixel, face_right, face_back), inside(pixel, face_back, face_left))
		);
		float noise = value_noise(world_position * ragged_scale) * 0.65
			+ value_noise(world_position * ragged_scale * 3.3 + 17.0) * 0.35;
		keep = smoothstep(0.0, feather_px, depth - noise * ragged_px);
	}
	if (has_backdrop && tone > 0.0) {
		// Nine taps on a flattened ring: the ground's colour around this point, not one pixel.
		vec3 ground = texture(backdrop, backdrop_uv(world_position)).rgb;
		for (int i = 0; i < 8; i++) {
			float angle = float(i) * 0.785398;
			vec2 offset = vec2(cos(angle), sin(angle) * 0.5) * reach_px;
			ground += texture(backdrop, backdrop_uv(world_position + offset)).rgb;
		}
		ground /= 9.0;
		vec3 matched = clamp(colour.rgb * ground / max(face_mean, vec3(0.04)), 0.0, 1.0);
		colour.rgb = mix(colour.rgb, matched, mix(tone, 1.0, (1.0 - keep) * 0.6));
	}
	colour.a *= keep;
	COLOR = colour;
}
