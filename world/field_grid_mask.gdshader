shader_type canvas_item;
// Hex slice H3: the floor grid shows only under the fighters (or around the lead while exploring)
// and fades out toward a soft edge, so the rest of the map stays clear. Distances are measured on
// the ground: screen y is doubled to undo the 2:1 iso squash, so the area is a circle on the floor.

uniform vec2 focus = vec2(0.0);
uniform float radius = 300.0;
uniform float feather = 0.35;

varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float ground_distance = length((world_position - focus) * vec2(1.0, 2.0));
	COLOR.a *= 1.0 - smoothstep(radius * (1.0 - feather), radius, ground_distance);
}
