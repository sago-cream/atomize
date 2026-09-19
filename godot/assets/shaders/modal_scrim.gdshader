shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float tint_opacity = 0.2;
uniform float blur_lod = 3.5;

void fragment() {
	vec3 backdrop = textureLod(screen_texture, SCREEN_UV, blur_lod).rgb;
	COLOR = vec4(mix(backdrop, vec3(0.063, 0.106, 0.180), tint_opacity), 1.0);
}
