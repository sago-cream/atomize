shader_type canvas_item;
render_mode unshaded;
void fragment() {
	float edge = length(UV * 2.0 - 1.0);
	COLOR.a *= 1.0 - smoothstep(0.3, 1.0, edge);
}
