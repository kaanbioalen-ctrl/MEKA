shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 0.2) = 0.0;
uniform float pulse : hint_range(0.0, 4.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(0.38, 0.8, 1.0, 0.024);

void fragment() {
	vec2 uv = SCREEN_UV;
	float wave_a = sin((uv.y * 26.0) + (TIME * 1.9)) * 0.003;
	float wave_b = cos((uv.x * 19.0) - (TIME * 1.5)) * 0.0025;
	vec2 distorted_uv = uv + vec2(wave_a, wave_b) * strength * (1.0 + pulse * 0.35);
	vec4 screen = texture(screen_texture, distorted_uv);
	vec4 tint = tint_color;
	tint.a *= strength * 1.8;
	COLOR = mix(screen, screen + tint, clamp(strength * 1.5, 0.0, 1.0));
}
