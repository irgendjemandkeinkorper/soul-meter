shader_type canvas_item;
// #412: the subtle tell on a wild spawn's variation tier. Pixels the tell mask marks (eyes,
// claws) shift toward `tell_color`; everything else is untouched. The mask is a greyscale
// render pass beside the unit's sprite; without one, `Hostile` never attaches this shader.

uniform sampler2D tell_mask : filter_linear;
uniform vec4 tell_color : source_color = vec4(1.0, 0.45, 0.15, 1.0);
uniform float tell_strength : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec4 mask = texture(tell_mask, UV);
	COLOR.rgb = mix(COLOR.rgb, tell_color.rgb, mask.r * mask.a * tell_strength);
}
